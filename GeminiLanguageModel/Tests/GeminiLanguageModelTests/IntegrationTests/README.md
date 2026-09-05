# GeminiLanguageModel Integration Tests

End-to-end integration tests validating `GeminiLanguageModel` sessions against
Gemini backends using recorded HTTP interactions or direct remote connections.

## Quick Start

```bash
# Run content generation integration tests
swift test --filter BasicContentGenerationIntegrationTests

# Run without remote credentials or internet (requires test-server in replay mode)
./scripts/test_server/run_test_server.sh replay
swift test --filter BasicContentGenerationIntegrationTests
```

## Dual-Mode Execution

Tests in this directory support two execution modes:

1. **Replay Mode (Local `test-server`)**:
   - Uses [`google/test-server`](https://github.com/google/test-server) running
     on localhost (`http://localhost:1443` and `http://localhost:1444`).
   - Replays previously recorded HTTP interactions deterministically.
   - Requires zero remote credentials, no API keys, and no internet access.

2. **Direct Mode (Remote Endpoints)**:
   - Connects directly to Google Cloud or Firebase when credentials are
     detected in the environment:
     - `GEMINI_API_KEY` or `GOOGLE_API_KEY` for Developer API.
     - `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`, `FIREBASE_API_KEY`, and
       `APP_CHECK_DEBUG_TOKEN` for Firebase AI Logic.

3. **Clean Skipping**:
   - If neither a local `test-server` nor valid credentials are present, tests
     using `.requireIntegrationTestingBackend` are automatically and cleanly
     skipped without failing the test run.

## Supported Backends

All integration tests are parameterized across
`IntegrationTestingBackend.availableBackends`:

* `.developerAPI`: Direct Gemini Developer API
  (`generativelanguage.googleapis.com`).
* `.firebaseAILogicDeveloperAPI`: Firebase AI Logic proxy to Gemini Developer
  API (`firebasevertexai.googleapis.com`).
* `.firebaseAILogicAgentPlatform(location:)`: Firebase AI Logic proxy to Gemini
  Enterprise Agent Platform (defaulting to `location: "global"`).

## Files in this Directory

* [`BasicContentGenerationIntegrationTests.swift`](BasicContentGenerationIntegrationTests.swift):
  Parameterized integration tests for single-turn prompt response, multi-turn
  chat sessions, and streaming chunk responses.
* [`GuidedGenerationIntegrationTests.swift`](GuidedGenerationIntegrationTests.swift):
  Parameterized integration tests for guided generation (structured outputs)
  using `@Generable` types, including single-turn and streaming generation,
  enum classification, and rich multi-type recursive hierarchies.
* [`IntegrationTestingBackend+GeminiLanguageModel.swift`](IntegrationTestingBackend+GeminiLanguageModel.swift):
  Convenience extension providing `backend.makeModel()` to instantiate a
  pre-configured `GeminiLanguageModel`.

## Writing New Integration Tests

To add a new integration test suite, parameterize on
`IntegrationTestingBackend`:

```swift
@Suite("My New Feature Integration Tests", .requireFoundationModels)
struct MyNewFeatureIntegrationTests {
  @Test(
    .tags(.integration),
    .requireIntegrationTestingBackend,
    arguments: IntegrationTestingBackend.availableBackends
  )
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  func testFeature(backend: IntegrationTestingBackend) async throws {
    let model = try await backend.makeModel()
    let session = LanguageModelSession(model: model)
    // Execute test assertions...
  }
}
```

> [!NOTE]
> For instructions on starting `test-server` or recording new interactions,
> see the [`test_server` Documentation](../../scripts/test_server/README.md).
