# Local Integration Testing with test-server

This directory provides configuration and automation scripts for running
record-replay integration tests against Gemini APIs using
[google/test-server](https://github.com/google/test-server).

## Overview

Integration tests can execute in two modes:
1. **Local test server (`testServer`)**: Uses `google/test-server` as a local
   reverse proxy (`http://localhost:1443`) to record or replay HTTP
   interactions without hitting backend quota limits or requiring active remote
   credentials.
2. **Direct remote connection (`direct`)**: Connects directly over HTTPS to the
   remote service (`generativelanguage.googleapis.com` or
   `firebasevertexai.googleapis.com`) when remote credentials (`GEMINI_API_KEY`
   or `GOOGLE_API_KEY`) are present in the environment.

## Prerequisites

Install `google/test-server`:

```bash
go install github.com/google/test-server@latest
```

Alternatively, download a pre-built binary from the
[test-server releases page](https://github.com/google/test-server/releases) and
place it in your `$PATH` or set `TEST_SERVER_BIN`.

## Workflow

### 1. Recording API interactions

To record new test runs against the remote backend:

```bash
export GEMINI_API_KEY="your-api-key"
./scripts/test_server/run_test_server.sh record
```

Then run the integration tests:

```bash
# Run all integration tests:
swift test --filter IntegrationTests

# Or run a specific suite (e.g. tool calling):
swift test --filter ToolCallingIntegrationTests
```

The test runner will detect `test-server` on port 1443 and route requests
through the proxy. All requests and responses are recorded to
`scripts/test_server/recordings/` with authentication and environment-variant
headers (`X-Goog-Api-Key`, `Authorization`, `X-Firebase-AppCheck`,
`Accept-Language`, `User-Agent`, `X-Goog-Api-Client`) automatically redacted.

### 2. Replaying recorded interactions

To run tests deterministically without remote credentials or internet access:

```bash
./scripts/test_server/run_test_server.sh replay
```

In another terminal, run tests:

```bash
# Run all integration tests:
swift test --filter IntegrationTests

# Or run a specific suite (e.g. tool calling):
swift test --filter ToolCallingIntegrationTests
```

### 3. Project ID redaction for Firebase AI Logic & Agent Platform

Firebase AI Logic and Gemini Enterprise Agent Platform embed the GCP Project ID
in the URL path (`/v1beta/projects/{projectID}/...`). To ensure recordings can be
replayed across different developer projects and in CI:
- `run_test_server.py` automatically passes `FIREBASE_PROJECT_ID`,
  `GOOGLE_CLOUD_PROJECT`, and `GCLOUD_PROJECT` into `TEST_SERVER_SECRETS`. If
  `FIREBASE_PLIST_PATH` is set, `PROJECT_ID` and `API_KEY` are automatically
  sourced from the plist.
- During recording, `test-server` sends the real path upstream to Google Cloud,
  then redacts the project ID to `REDACTED` (`/v1beta/projects/REDACTED/...`)
  before saving the recording to disk.
- During replay, `test-server` redacts the local project ID to `REDACTED` before
  computing the request checksum, ensuring an exact match.
- In CI or headless environments, tests can simply set
  `FIREBASE_PROJECT_ID="REDACTED"` or `GOOGLE_CLOUD_PROJECT="REDACTED"`.

### 4. Running in CI or Xcode schemes

In CI environments (e.g., GitHub Actions) or Xcode schemes with pre-actions:
- Start `test-server replay` in the background prior to test execution.
- If neither `test-server` nor an API key is available, tests using
  `.requireIntegrationTestingBackend` are automatically and cleanly skipped.
