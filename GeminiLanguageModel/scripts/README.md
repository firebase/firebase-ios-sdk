# Development and Testing Scripts

Developer automation scripts, proxies, and tooling for `GeminiLanguageModel`.

## Overview

This directory contains automation tooling for building, testing, and
maintaining the `GeminiLanguageModel` package.

## Tooling Directory

### [`test_server/`](test_server/)

Automation and configuration for running record-and-replay integration tests
against Gemini APIs using
[`google/test-server`](https://github.com/google/test-server).

* **`run_test_server.sh`**: Launch helper that discovers the local
  `test-server` binary, populates secrets redaction parameters, and starts
  the proxy in either `record` or `replay` mode.
* **`test_server_config.yaml`**: Route mapping and header redaction rules for:
  - Gemini Developer API (`http://localhost:1443` -> `generativelanguage.googleapis.com:443`)
  - Firebase AI Logic (`http://localhost:1444` -> `firebasevertexai.googleapis.com:443`)
* **`recordings/`**: Stored JSON files containing recorded HTTP interactions
  with sensitive headers and project IDs redacted.

## Quick Start

```bash
# Start test-server in replay mode for offline integration testing
./scripts/test_server/run_test_server.sh replay

# Start test-server in record mode (requires remote credentials)
export GEMINI_API_KEY="your-api-key"
./scripts/test_server/run_test_server.sh record
```

> [!TIP]
> For complete setup, installation, and CI integration instructions, see the
> [test-server Guide](test_server/README.md).
