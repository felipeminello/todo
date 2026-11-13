"""Task attachments API of ToDo Bomber.

The app never talks to S3 with AWS credentials. It calls this API with the
user's Firebase ID token (already verified by the API Gateway JWT authorizer)
and gets short-lived presigned URLs to upload or download one file.

Objects live at `<taskId>/<uuid>.<ext>`. The name the user sees and the owner
are kept as object metadata, signed into the upload URL so the client cannot
change them.
"""

import base64
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

BUCKET = os.environ["BUCKET"]
FIREBASE_PROJECT_ID = os.environ["FIREBASE_PROJECT_ID"]
MAX_BYTES = int(os.environ.get("MAX_BYTES", 25 * 1024 * 1024))
MAX_PER_TASK = int(os.environ.get("MAX_PER_TASK", 20))
URL_TTL_SECONDS = int(os.environ.get("URL_TTL_SECONDS", 300))

# S3 limits user metadata to 2 KB; the percent-encoded name stays well below.
MAX_ENCODED_NAME = 1024

TASK_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
ATTACHMENT_ID = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
    r"(\.[a-z0-9]{1,16})?$"
)
EXTENSION = re.compile(r"^[a-z0-9]{1,16}$")
CONTENT_TYPE = re.compile(r"^[\w.+-]+/[\w.+-]+$")

s3 = boto3.client(
    "s3",
    config=Config(signature_version="s3v4", s3={"addressing_style": "virtual"}),
)


class ApiError(Exception):
    def __init__(self, status, code):
        super().__init__(code)
        self.status = status
        self.code = code


def handler(event, _context):
    try:
        return _route(event)
    except ApiError as error:
        return _json(error.status, {"error": error.code})
    except ClientError as error:
        print("s3 error:", error.response.get("Error", {}).get("Code"))
        return _json(502, {"error": "storage_unavailable"})


def _route(event):
    claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
    uid = claims.get("sub")
    if not uid:
        raise ApiError(401, "unauthenticated")

    params = event.get("pathParameters") or {}
    task_id = params.get("taskId", "")
    if not TASK_ID.match(task_id):
        raise ApiError(400, "invalid_task_id")
    attachment_id = params.get("attachmentId")
    if attachment_id is not None and not ATTACHMENT_ID.match(attachment_id):
        raise ApiError(400, "invalid_attachment_id")

    match event["routeKey"]:
        case "GET /tasks/{taskId}/attachments":
            return _json(200, {"attachments": _owned(uid, task_id)})
        case "POST /tasks/{taskId}/attachments":
            return _create_upload(event, uid, task_id)
        case "GET /tasks/{taskId}/attachments/{attachmentId}":
            return _download_url(uid, task_id, attachment_id)
        case "DELETE /tasks/{taskId}/attachments/{attachmentId}":
            _owned_head(uid, task_id, attachment_id)
            s3.delete_object(Bucket=BUCKET, Key=f"{task_id}/{attachment_id}")
            return _empty()
        case "DELETE /tasks/{taskId}/attachments":
            return _delete_all(uid, task_id)
    raise ApiError(404, "not_found")


def _create_upload(event, uid, task_id):
    body = _body(event)
    name = _clean_name(body.get("name"))
    size = body.get("size")
    if not isinstance(size, int) or isinstance(size, bool) or size <= 0:
        raise ApiError(400, "invalid_size")
    if size > MAX_BYTES:
        raise ApiError(413, "too_large")
    content_type = body.get("contentType")
    if not isinstance(content_type, str) or not CONTENT_TYPE.match(content_type):
        content_type = "application/octet-stream"

    _require_task(event, uid, task_id)
    if len(_keys(task_id)) >= MAX_PER_TASK:
        raise ApiError(409, "limit_reached")

    attachment_id = str(uuid.uuid4()) + _extension(name)
    metadata = {"owner": uid, "name": urllib.parse.quote(name, safe="")}
    # Every header below is part of the signature: S3 refuses an upload with
    # another size, type, name or owner.
    url = s3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": BUCKET,
            "Key": f"{task_id}/{attachment_id}",
            "ContentType": content_type,
            "ContentLength": size,
            "Metadata": metadata,
        },
        ExpiresIn=URL_TTL_SECONDS,
    )
    return _json(
        201,
        {
            "attachment": {
                "id": attachment_id,
                "name": name,
                "size": size,
                "contentType": content_type,
                "createdAt": _iso(datetime.now(timezone.utc)),
            },
            "upload": {
                "url": url,
                "headers": {
                    "Content-Type": content_type,
                    **{f"x-amz-meta-{k}": v for k, v in metadata.items()},
                },
            },
        },
    )


def _download_url(uid, task_id, attachment_id):
    head = _owned_head(uid, task_id, attachment_id)
    name = urllib.parse.unquote(head["Metadata"].get("name", attachment_id))
    fallback = re.sub(r'[^\x20-\x7e]|["\\]', "_", name)
    url = s3.generate_presigned_url(
        "get_object",
        Params={
            "Bucket": BUCKET,
            "Key": f"{task_id}/{attachment_id}",
            "ResponseContentDisposition": (
                f'attachment; filename="{fallback}"; '
                f"filename*=UTF-8''{urllib.parse.quote(name, safe='')}"
            ),
        },
        ExpiresIn=URL_TTL_SECONDS,
    )
    return _json(200, {"url": url})


def _delete_all(uid, task_id):
    owned = [
        {"Key": f"{task_id}/{attachment['id']}"}
        for attachment in _owned(uid, task_id)
    ]
    if owned:
        result = s3.delete_objects(
            Bucket=BUCKET, Delete={"Objects": owned, "Quiet": True}
        )
        if result.get("Errors"):
            raise ApiError(502, "storage_unavailable")
    return _empty()


def _keys(task_id):
    """Keys in the task folder. A folder never holds much more than
    MAX_PER_TASK objects, so one page is all there is."""
    listing = s3.list_objects_v2(Bucket=BUCKET, Prefix=f"{task_id}/")
    return [item["Key"] for item in listing.get("Contents", [])]


def _owned(uid, task_id):
    """The user's attachments in the task folder, oldest first."""
    keys = _keys(task_id)
    if not keys:
        return []
    with ThreadPoolExecutor(max_workers=8) as pool:
        heads = list(pool.map(_head_or_none, keys))
    attachments = [
        {
            "id": key.split("/", 1)[1],
            "name": urllib.parse.unquote(
                head["Metadata"].get("name", key.split("/", 1)[1])
            ),
            "size": head["ContentLength"],
            "contentType": head.get("ContentType", "application/octet-stream"),
            "createdAt": _iso(head["LastModified"]),
        }
        for key, head in zip(keys, heads)
        if head is not None and head["Metadata"].get("owner") == uid
    ]
    return sorted(attachments, key=lambda a: (a["createdAt"], a["id"]))


def _head_or_none(key):
    try:
        return s3.head_object(Bucket=BUCKET, Key=key)
    except ClientError as error:
        if _is_missing(error):
            return None
        raise


def _owned_head(uid, task_id, attachment_id):
    """Metadata of an attachment of this user. Someone else's attachment is
    reported as missing, so its existence is not revealed."""
    head = _head_or_none(f"{task_id}/{attachment_id}")
    if head is None or head["Metadata"].get("owner") != uid:
        raise ApiError(404, "attachment_not_found")
    return head


def _is_missing(error):
    status = error.response.get("ResponseMetadata", {}).get("HTTPStatusCode")
    return status == 404


def _require_task(event, uid, task_id):
    """Uploads only go to a task the user has. Firestore answers with the
    user's own token, so its security rules make the decision."""
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    url = (
        "https://firestore.googleapis.com/v1/projects/"
        f"{FIREBASE_PROJECT_ID}/databases/(default)/documents/users/"
        f"{urllib.parse.quote(uid, safe='')}/tasks/{task_id}"
        "?mask.fieldPaths=title"
    )
    request = urllib.request.Request(
        url, headers={"Authorization": headers.get("authorization", "")}
    )
    try:
        with urllib.request.urlopen(request, timeout=8):
            return
    except urllib.error.HTTPError as error:
        if error.code == 404:
            raise ApiError(404, "task_not_found") from error
        if error.code in (401, 403):
            raise ApiError(403, "forbidden") from error
        print("firestore status:", error.code)
        raise ApiError(502, "task_check_unavailable") from error
    except (urllib.error.URLError, TimeoutError) as error:
        print("firestore unreachable:", error)
        raise ApiError(502, "task_check_unavailable") from error


def _body(event):
    raw = event.get("body") or ""
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8", "replace")
    try:
        body = json.loads(raw)
    except ValueError as error:
        raise ApiError(400, "invalid_body") from error
    if not isinstance(body, dict):
        raise ApiError(400, "invalid_body")
    return body


def _clean_name(value):
    """The uploaded file's own name, without any directory and short enough
    to be stored as object metadata."""
    if not isinstance(value, str):
        raise ApiError(400, "invalid_name")
    name = re.sub(r"[\x00-\x1f\x7f]", "", value.replace("\\", "/"))
    name = name.rsplit("/", 1)[-1].strip()
    if not name or name in (".", ".."):
        raise ApiError(400, "invalid_name")
    stem, dot, extension = name.rpartition(".")
    if not dot or not stem:
        stem, extension = name, ""
    suffix = f".{extension}" if extension else ""
    while stem and len(urllib.parse.quote(stem + suffix, safe="")) > MAX_ENCODED_NAME:
        stem = stem[:-1]
    if not stem:
        raise ApiError(400, "invalid_name")
    return stem + suffix


def _extension(name):
    stem, dot, extension = name.rpartition(".")
    extension = extension.lower()
    if dot and stem and EXTENSION.match(extension):
        return f".{extension}"
    return ""


def _iso(instant):
    return instant.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def _json(status, payload):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json; charset=utf-8"},
        "body": json.dumps(payload, ensure_ascii=False),
    }


def _empty():
    return {"statusCode": 204}
