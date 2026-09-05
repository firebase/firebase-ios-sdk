# GeminiLanguageModel Tests

Unit and integration test suites validating `GeminiLanguageModel` protocol
conformance, streaming response generation, transcript translation, error
mapping, and backend integration.

## Quick Start

```bash
# Run all unit tests (fast, ~0.04s, skips integration tests)
swift test --skip Integration

# Run all tests in this target (including integration tests)
swift test --filter GeminiLanguageModelTests
```

## Test Suites

| Suite / File | Scope | Strategy |
|---|---|---|
| [`GeminiLanguageModelTests.swift`](GeminiLanguageModelTests.swift) | Protocol conformance, single/multi-turn responses, streaming | Unit (`MockHTTPURLProtocol`) |
| [`GeminiTranscriptTranslatorTests.swift`](GeminiTranscriptTranslatorTests.swift) | Apple `Transcript` <-> Gemini payload mapping | Unit (pure transformation) |
| [`GeminiErrorMapperTests.swift`](GeminiErrorMapperTests.swift) | HTTP and API error mapping to `LanguageModelError` | Unit (exhaustive mapping) |
| [`IntegrationTestingBackendTests.swift`](IntegrationTestingBackendTests.swift) | Endpoint resolution, socket probing, port discovery | Unit / Infrastructure |
| [`IntegrationTests/`](IntegrationTests/) | Real Gemini API and record/replay integration tests | Integration (see [`IntegrationTests/README.md`](IntegrationTests/README.md)) |

## Testing Architecture

This target separates tests into two distinct tiers:

1. **Unit Tests (Default)**:
   - Use `MockHTTPURLProtocol` for deterministic, zero-network, sub-second
     execution.
   - Run cleanly in offline, CI, and local development environments without
     any credentials or background daemons.

2. **Integration Tests (`IntegrationTests/`)**:
   - Tagged with `.tags(.integration)` and gated by
     `.requireIntegrationTestingBackend`.
   - Exercise live endpoints or replay recorded HTTP interactions via local
     `test-server`.
   - Isolated in the `IntegrationTests/` subfolder so unit test runs are never
     slowed down by network timeouts or external dependencies.

> [!TIP]
> For details on running, recording, and parameterizing integration tests, see
> the [Integration Tests Guide](IntegrationTests/README.md).
