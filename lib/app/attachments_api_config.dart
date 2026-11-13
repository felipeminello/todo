/// Base URL of the task attachments API: the `ApiUrl` output of the
/// CloudFormation stack in `infra/attachments`. It is public; every call
/// still needs the signed-in user's ID token.
final attachmentsApiUrl = Uri.parse(
  'https://rb9c2jqr63.execute-api.us-east-1.amazonaws.com',
);
