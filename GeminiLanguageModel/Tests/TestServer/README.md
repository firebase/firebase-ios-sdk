# Recorded integration tests

GeminiLanguageModel integration tests can run against recordings served by
[test-server](https://github.com/google/test-server), a record/replay reverse
proxy. Replay needs no credentials or network access and runs in well under a
second, so it suits every pull request. Recording runs the same tests against
the live backends and saves each request and response.

## Quick start

```bash
cd GeminiLanguageModel

# Replay all recorded integration tests (no credentials needed).
scripts/test-server.sh replay IntegrationTests

# Re-record a suite against the live backends (requires credentials; see below).
scripts/test-server.sh record ToolCallingIntegrationTests

# Explain why requests don't match their recordings.
scripts/test-server.sh diff IntegrationTests
```

The first argument is a `swift test --filter` regular expression. Any further
arguments are passed to `swift test`. `IntegrationTests` matches every
integration suite in the package; all of them have recordings.

## Diagnosing mismatches

test-server answers a request that doesn't match its recording with HTTP 500
and a hash. When `replay` fails, the script re-runs the failed tests behind a
capture proxy ([`test_server_diagnostics.py`](../../scripts/test_server_diagnostics.py))
and prints, for each test, how its first unmatched request differs from the
recorded request: the method, URL, matched headers, or a JSON body diff. Long
values such as thought signatures are shortened and labeled with a hash. Run
`diff` to do this without a failing replay first.

For example, reintroducing a bug that moved a thought signature onto its own
data-less part produces:

```text
✘ GeminiLanguageModelTests/ToolCallingIntegrationTests/sessionRespondSequentialToolCalls/developer-api
  Request #3 (POST /v1beta/models/gemini-3.5-flash-lite:streamGenerateContent?alt=sse) was not matched.
  Differences from recorded request #3 in developer-api.json:
  Body:
  --- recorded body
  +++ request body
  -          "text": "The current weather in Seattle is 22°C and sunny.",
  +          "text": "The current weather in Seattle is 22°C and sunny."
  +        },
  +        {
  +          "thought": true,
             "thoughtSignature": "EmAKXgFpFH0T5X5e4o7z… <132 chars, sha256 6ce795a20ec3>"
```

If the change is intentional, re-record the affected tests and review the
recording diff.

## How it works

`INTEGRATION_TEST_MODE` selects how `IntegrationTestingBackend` sends requests:

| Mode | Requests go to | Credentials |
| --- | --- | --- |
| `live` (default) | The live backends | Required |
| `record` | test-server, which forwards them and saves the interaction | Required |
| `replay` | test-server, which answers from recordings | Not used |

`scripts/test-server.sh` downloads a pinned, checksum-verified test-server
binary into `.build/test-server`, starts it with
[`test-server.yml`](test-server.yml), sets the mode, and runs `swift test`.

- **Recording names**: `makeModel()` sends a `Test-Name` header derived from the
  calling test's file, function, and backend, so each parameterized case has
  its own file under `recordings/`.
- **Matching**: test-server matches a request by hashing its method, URL, JSON
  body (key order doesn't matter), the previous request in the same recording,
  and every header not listed under `redact_request_headers`.
- **Secrets**: in `record` mode the script passes credential values in
  `TEST_SERVER_SECRETS`, so test-server replaces them with `REDACTED` anywhere
  they appear, including the Firebase project ID in URLs. Replay uses
  `REDACTED` as the project ID.
- **Serial execution**: test-server tracks request order per endpoint rather
  than per test, so the script runs tests with `--no-parallel`.

## Recording

Recording requires the same credentials as live integration tests:
`GEMINI_API_KEY` (or `GOOGLE_API_KEY`), plus either `FIREBASE_PLIST_PATH` or
`FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`, and `FIREBASE_API_KEY`, and
`AppCheckDebugToken`.

If tests fail, the script restarts test-server and re-records only the failed
test functions, up to `TEST_SERVER_MAX_ATTEMPTS` (default `3`) attempts.
Restarting is required: retrying against the same test-server process appends
the failed attempt to the recording, and replay would serve the failed
response first.

### Header audit

After recording, the script runs `scripts/test-server.sh audit --fix`, which:

1. Strips noisy response headers (such as `Date`) that change on every
   recording but aren't needed for replay.
2. Fails if any recorded request or response header isn't listed in
   [`recording-policy.json`](recording-policy.json).

An unlisted header fails the audit whatever its value, so a new credential
header (for example, `Authorization: Bearer …`) can't be committed by accident,
even in formats that secret scanners miss. Only header names are printed, never
values. The `audit-recordings` CI job runs the same check without `--fix`.

To resolve a violation, redact the header in
[`test-server.yml`](test-server.yml) (credentials, or values that vary between
machines), add it to `strippedResponseHeaders` (noise), or add it to an
allowlist after confirming it can't contain credentials.

> [!IMPORTANT]
> Review recording diffs before committing them. The header audit doesn't scan
> URLs or bodies, and recordings capture full model responses.

## Limitations

- Only suites with recordings can run in `replay` mode; other integration tests
  fail with HTTP 500 from test-server.
- Re-running a test against the same replay server fails, so don't use
  `-test-iterations` or `-retry-tests-on-failure` in replay mode.
- Requests must be deterministic. Today, if a backend omits function call IDs,
  `GeminiLanguageModelExecutor` synthesizes random ones for Foundation Models
  and they're incorrectly sent back to the backend, which would change
  follow-up requests and break replay.
- Changing request encoding requires re-recording affected tests.
- test-server v0.2.9 replays JSON error bodies on streaming (`alt=sse`) URLs as
  server-sent events, so `GeminiAPIClient` reports `.httpError` instead of
  `.apiError`. `streamGenerateContentWithoutAuthThrows` is skipped in replay
  mode until test-server records each response's body format; a proposed fix
  adds a `bodyFormat` field to recordings, which older test-server versions
  ignore.

## Running on an iOS Simulator

The simulator can't launch processes, but it shares the host's `localhost`.
Start test-server in the background and pass the mode to the test runner:

```bash
scripts/test-server.sh start replay
TEST_RUNNER_INTEGRATION_TEST_MODE=replay xcodebuild test-without-building ...
scripts/test-server.sh stop
```
