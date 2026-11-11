"""Sends the screenshots compose.py made, in build/store_media/final/, to the
stores, replacing the ones that are there.

    python tool/store_media/upload.py appstore <ios|macos> <version>
    python tool/store_media/upload.py play

appstore: the screenshots of the App Store version <version> (it has to be
editable, as in "Prepare for Submission"), in every language it has. iOS gets
the iPhone (6.5") and the iPad (13") sets, macOS the Mac set. Same credentials
as tool/applestore_publish.sh: ASC_ISSUER_ID, ASC_KEY_ID and the key in
~/.appstoreconnect/private_keys/AuthKey_<ID>.p8 (or ASC_KEY_PATH).

play: the phone screenshots of the store listing, in every language it has,
in one edit that is committed at the end. Listing changes go to Google's
review and, once approved, show on the store page, even before the release
they show is out. Same service account as tool/playstore_publish.sh
(PLAY_SERVICE_ACCOUNT_JSON or ~/play-service-account-todo-bomber.json).

Only the standard library and openssl.
"""

import base64
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
MEDIA = ROOT / 'build' / 'store_media' / 'final'

BUNDLE_ID = 'br.dev.minello.todo'
ASC = 'https://api.appstoreconnect.apple.com/v1'
PLAY = ('https://androidpublisher.googleapis.com/androidpublisher/v3/'
        f'applications/{BUNDLE_ID}')
PLAY_UPLOAD = ('https://androidpublisher.googleapis.com/upload/'
               f'androidpublisher/v3/applications/{BUNDLE_ID}')

# App Store display type of each folder, by platform.
APPLE_SETS = {
    'ios': [('APP_IPHONE_65', 'ios-1284x2778'),
            ('APP_IPAD_PRO_3GEN_129', 'ipad-2064x2752')],
    'macos': [('APP_DESKTOP', 'macos-desktop-2880x1800')],
}
PLAY_FOLDER = 'android-1080x1920'


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def openssl_sign(key_path, message):
    return subprocess.run(['openssl', 'dgst', '-sha256', '-sign', key_path],
                          input=message, capture_output=True,
                          check=True).stdout


def der_to_raw(der):
    """ES256 in a JWT is r and s, 32 bytes each; openssl gives DER."""
    def integer(at):
        assert der[at] == 0x02
        length = der[at + 1]
        value = der[at + 2:at + 2 + length]
        return value.lstrip(b'\0').rjust(32, b'\0'), at + 2 + length
    at = 2 if der[1] < 0x80 else 3
    r, at = integer(at)
    s, _ = integer(at)
    return r + s


class ApiError(Exception):
    def __init__(self, method, url, code, detail):
        super().__init__(f'{method} {url} → HTTP {code}: {detail}')
        self.code = code


def request(method, url, token=None, body=None, headers=None, raw=None):
    headers = dict(headers or {})
    if token:
        headers['Authorization'] = f'Bearer {token}'
    data = raw
    if body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    for attempt in range(4):
        req = urllib.request.Request(url, data=data, method=method,
                                     headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as response:
                text = response.read()
                return json.loads(text) if text.strip() else None
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors='replace')
            # Both APIs fail the odd request with a 5xx; trying again works.
            if error.code >= 500 and attempt < 3:
                time.sleep(3 * (attempt + 1))
                continue
            raise ApiError(method, url, error.code, detail) from None


def screenshots(folder):
    files = sorted((MEDIA / folder).glob('*.png'))
    if not files:
        raise SystemExit(f'nothing in {MEDIA / folder}: run compose.py first')
    return files


# --- App Store Connect -----------------------------------------------------

def asc_token():
    key_id = os.environ.get('ASC_KEY_ID')
    issuer = os.environ.get('ASC_ISSUER_ID')
    if not key_id or not issuer:
        raise SystemExit('set ASC_KEY_ID and ASC_ISSUER_ID')
    key_path = os.environ.get('ASC_KEY_PATH') or str(
        pathlib.Path.home() / '.appstoreconnect' / 'private_keys'
        / f'AuthKey_{key_id}.p8')
    now = int(time.time())
    header = b64url(json.dumps(
        {'alg': 'ES256', 'kid': key_id, 'typ': 'JWT'}).encode())
    claims = b64url(json.dumps({
        'iss': issuer, 'aud': 'appstoreconnect-v1',
        'iat': now, 'exp': now + 1100}).encode())
    signing_input = f'{header}.{claims}'.encode()
    signature = der_to_raw(openssl_sign(key_path, signing_input))
    return f'{header}.{claims}.{b64url(signature)}'


class Asc:
    """Calls the App Store Connect API with a token that is renewed before
    it expires and, once, when Apple refuses it (which it sometimes does to
    a valid one)."""

    def __init__(self):
        self.renew()

    def renew(self):
        self.token = asc_token()
        self.issued = time.time()

    def __call__(self, method, path, body=None):
        if time.time() - self.issued > 900:
            self.renew()
        url = path if path.startswith('http') else ASC + path
        try:
            return request(method, url, self.token, body)
        except ApiError as error:
            if error.code != 401:
                raise
            time.sleep(5)
            self.renew()
            return request(method, url, self.token, body)


def upload_apple_screenshot(asc, set_id, file):
    data = file.read_bytes()
    reservation = asc('POST', '/appScreenshots', {'data': {
        'type': 'appScreenshots',
        'attributes': {'fileName': file.name, 'fileSize': len(data)},
        'relationships': {'appScreenshotSet': {
            'data': {'type': 'appScreenshotSets', 'id': set_id}}},
    }})['data']
    for operation in reservation['attributes']['uploadOperations']:
        offset, length = operation['offset'], operation['length']
        headers = {h['name']: h['value']
                   for h in operation['requestHeaders']}
        request(operation['method'], operation['url'], headers=headers,
                raw=data[offset:offset + length])
    asc('PATCH', f"/appScreenshots/{reservation['id']}", {'data': {
        'type': 'appScreenshots', 'id': reservation['id'],
        'attributes': {'uploaded': True,
                       'sourceFileChecksum': hashlib.md5(data).hexdigest()},
    }})
    return reservation['id']


def wait_apple_processing(asc, ids):
    """Apple checks each file after the upload; a bad one shows up here."""
    pending = set(ids)
    deadline = time.time() + 600
    while pending and time.time() < deadline:
        for shot_id in list(pending):
            state = asc('GET', f'/appScreenshots/{shot_id}')['data'][
                'attributes']['assetDeliveryState']
            if state['state'] == 'COMPLETE':
                pending.discard(shot_id)
            elif state['state'] == 'FAILED':
                raise SystemExit(f'Apple rejected {shot_id}: {state}')
        if pending:
            time.sleep(5)
    if pending:
        print(f'  still processing: {len(pending)} (check App Store Connect)')


def appstore(platform, version):
    asc = Asc()
    platform_name = {'ios': 'IOS', 'macos': 'MAC_OS'}[platform]
    app = asc('GET', f'/apps?filter[bundleId]={BUNDLE_ID}')['data'][0]
    versions = asc('GET', f"/apps/{app['id']}/appStoreVersions"
                   f'?filter[platform]={platform_name}'
                   f'&filter[versionString]={version}')['data']
    if not versions:
        raise SystemExit(f'no App Store version {version} for {platform}')
    store_version = versions[0]
    state = store_version['attributes']['appVersionState']
    print(f'{platform} {version}: {state}')
    localizations = asc('GET', f"/appStoreVersions/{store_version['id']}"
                        '/appStoreVersionLocalizations')['data']
    for localization in localizations:
        locale = localization['attributes']['locale']
        sets = asc('GET', f"/appStoreVersionLocalizations/{localization['id']}"
                   '/appScreenshotSets?include=appScreenshots')
        by_type = {s['attributes']['screenshotDisplayType']: s
                   for s in sets['data']}
        for display_type, folder in APPLE_SETS[platform]:
            files = screenshots(folder)
            existing = by_type.get(display_type)
            if existing:
                set_id = existing['id']
                for old in existing['relationships']['appScreenshots'][
                        'data']:
                    asc('DELETE', f"/appScreenshots/{old['id']}")
            else:
                set_id = asc('POST', '/appScreenshotSets', {'data': {
                    'type': 'appScreenshotSets',
                    'attributes': {'screenshotDisplayType': display_type},
                    'relationships': {'appStoreVersionLocalization': {
                        'data': {'type': 'appStoreVersionLocalizations',
                                 'id': localization['id']}}},
                }})['data']['id']
            ids = [upload_apple_screenshot(asc, set_id, f) for f in files]
            wait_apple_processing(asc, ids)
            # The order on the store page is the set's order.
            asc('PATCH', f'/appScreenshotSets/{set_id}/relationships/'
                'appScreenshots',
                {'data': [{'type': 'appScreenshots', 'id': i} for i in ids]})
            print(f'  {locale} {display_type}: {len(ids)} screenshots '
                  f'from {folder}/')


# --- Google Play -----------------------------------------------------------

def play_token():
    path = os.environ.get('PLAY_SERVICE_ACCOUNT_JSON') or str(
        pathlib.Path.home() / 'play-service-account-todo-bomber.json')
    account = json.loads(pathlib.Path(path).read_text())
    now = int(time.time())
    header = b64url(json.dumps({'alg': 'RS256', 'typ': 'JWT'}).encode())
    claims = b64url(json.dumps({
        'iss': account['client_email'],
        'scope': 'https://www.googleapis.com/auth/androidpublisher',
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': now, 'exp': now + 3600}).encode())
    # openssl reads the key from a file; this one is readable only by us
    # and is deleted on close.
    with tempfile.NamedTemporaryFile('w', suffix='.pem') as key:
        key.write(account['private_key'])
        key.flush()
        signature = openssl_sign(key.name, f'{header}.{claims}'.encode())
    assertion = f'{header}.{claims}.{b64url(signature)}'
    body = urllib.parse.urlencode({
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': assertion}).encode()
    response = request('POST', 'https://oauth2.googleapis.com/token',
                       raw=body, headers={
                           'Content-Type': 'application/x-www-form-urlencoded'})
    return response['access_token']


def play():
    files = screenshots(PLAY_FOLDER)
    if len(files) > 8:
        raise SystemExit(f'the Play takes up to 8 phone screenshots, '
                         f'{PLAY_FOLDER}/ has {len(files)}')
    token = play_token()
    edit = request('POST', f'{PLAY}/edits', token)['id']
    committed = False
    try:
        listings = request('GET', f'{PLAY}/edits/{edit}/listings',
                           token).get('listings', [])
        for listing in listings:
            language = listing['language']
            base = f'edits/{edit}/listings/{language}/phoneScreenshots'
            request('DELETE', f'{PLAY}/{base}', token)
            for file in files:
                request('POST', f'{PLAY_UPLOAD}/{base}?uploadType=media',
                        token, raw=file.read_bytes(),
                        headers={'Content-Type': 'image/png'})
            print(f'  {language}: {len(files)} phone screenshots '
                  f'from {PLAY_FOLDER}/')
        request('POST', f'{PLAY}/edits/{edit}:commit', token)
        committed = True
        print('committed: the listing goes to Google for review')
    finally:
        if not committed:
            request('DELETE', f'{PLAY}/edits/{edit}', token)


def main():
    try:
        if sys.argv[1:2] == ['appstore'] and len(sys.argv) == 4:
            appstore(sys.argv[2], sys.argv[3])
        elif sys.argv[1:] == ['play']:
            play()
        else:
            raise SystemExit(__doc__)
    except ApiError as error:
        raise SystemExit(f'error: {error}') from None


if __name__ == '__main__':
    main()
