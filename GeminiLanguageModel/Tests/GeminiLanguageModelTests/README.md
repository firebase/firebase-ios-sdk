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
| [`GeminiLanguageModelTests.swift`](GeminiLanguageModelTests.swift) | Protocol conformance, single/multi-turn responses, streaming, tool calling, thought summaries, and dynamic profiles | Unit (`MockHTTPURLProtocol`) |
| [`GeminiRequestMetadataTests.swift`](GeminiRequestMetadataTests.swift) | Structured request metadata serialization, deserialization, and dictionary helpers | Unit (pure transformation) |
| [`GenerationSchema+GeminiTests.swift`](GenerationSchema+GeminiTests.swift) | JSON Schema encoding and property ordering conversion | Unit (pure transformation) |
| [`GeminiRequestTranslatorTests.swift`](GeminiRequestTranslatorTests.swift) | Request, generation config, tool declarations, thinking configuration, and metadata precedence | Unit (pure transformation) |
| [`GeminiTranscriptTranslatorTests.swift`](GeminiTranscriptTranslatorTests.swift) | Apple `Transcript` <-> Gemini payload mapping (tools, reasoning, prompts) | Unit (pure transformation) |
| [`GeminiErrorMapperTests.swift`](GeminiErrorMapperTests.swift) | HTTP and API error mapping to `LanguageModelError` | Unit (exhaustive mapping) |
| [`IntegrationTestingBackendTests.swift`](IntegrationTestingBackendTests.swift) | Endpoint resolution and credential discovery | Unit / Infrastructure |
| [`IntegrationTests/`](IntegrationTests/) | End-to-end Gemini and Firebase AI Logic integration tests | Integration (see [`IntegrationTests/README.md`](IntegrationTests/README.md)) |

## Reasoning and Thought Summaries

Gemini reasoning capabilities and thought summaries are validated across
multiple layers:

* **Model Configuration**: `GeminiLanguageModel(thinking:)` sets the default
  thought summary mode (`.auto` or `.off`) on the model.
* **Dynamic Profiles**: `LanguageModelSession.DynamicProfile` extensions provide
  `.geminiThinking(summaries:)` and `.geminiThinking(perform:)` to configure or
  observe thought summaries within a session profile without mutating model
  instances. Active profiles automatically maintain
  `session.properties.geminiThoughtSummary` as observable state.
  Reasoning depth/budget is configured via Apple's standard
  `.reasoningLevel` profile modifier using `.light`, `.moderate`, or `.deep`.
* **Response & Snapshot Inspection**: `response.geminiThoughtSummary` and
  `snapshot.geminiThoughtSummary` provide first-class, zero-synchronization
  access to generated thought summary text without requiring callbacks or locks.
* **Request Metadata**: Per-turn overrides via `session.respond(metadata:)` or
  `session.streamResponse(metadata:)` use `GeminiRequestMetadata` (stored under
  the `"gemini"` key) or the `.gemini(thinkingSummaries:)` dictionary helper.
* **Precedence Resolution**: The request translator resolves configurations
  hierarchically: per-turn request metadata > profile prompt metadata > model
  default.
* **Transcript Translation**: Thought parts returned by the Gemini API
  (`thought: true`) stream into Apple's `Transcript.Reasoning` entries with
  preserved thought signatures.

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
   - Exercise endpoints on Google Cloud and Firebase using configured
     credentials.
   - Isolated in the `IntegrationTests/` subfolder so unit test runs are never
     slowed down by network timeouts or external dependencies.

> [!TIP]
> For details on configuring credentials and parameterizing integration tests,
> see the [Integration Tests Guide](IntegrationTests/README.md).
