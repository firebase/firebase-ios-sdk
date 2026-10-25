# GeminiLanguageModel Integration Tests

End-to-end integration tests validating `GeminiLanguageModel` sessions against
remote Gemini and Firebase AI Logic backends.

## Quick Start

```bash
# Run integration tests (using environment variables or GoogleService-Info.plist)
swift test --filter IntegrationTests

# Run a specific integration test suite
swift test --filter ToolCallingIntegrationTests

# Run all unit tests (fast, skips all integration tests)
swift test --skip IntegrationTests
```

## Running Integration Tests

Integration tests in this directory connect to Google Cloud or Firebase
endpoints when credentials are configured:

1. **Gemini Developer API**:
   Set `GEMINI_API_KEY` or `GOOGLE_API_KEY` in your environment.
2. **Firebase AI Logic**:
   Provide credentials via a configuration file or individual variables:
   - Set `FIREBASE_PLIST_PATH` pointing to a valid `GoogleService-Info.plist`
     file, along with `AppCheckDebugToken`.
   - Alternatively, supply `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`,
     `FIREBASE_API_KEY`, and `AppCheckDebugToken`.

### Automatic Skipping

If credentials are not present in the environment, integration tests marked with
`.requireIntegrationTestingBackend` are automatically and cleanly skipped
without failing test execution.

### Recorded Tests

Suites with recordings can run without credentials by replaying responses from
[test-server](https://github.com/google/test-server):

```bash
scripts/test-server.sh replay IntegrationTests
```

In replay mode, backends are always available, so tests run instead of being
skipped. See [`Tests/TestServer/README.md`](../../TestServer/README.md) for
recording, retries, and limitations.

## Supported Backends

All integration tests are parameterized across
`IntegrationTestingBackend.availableBackends`:

* `.firebaseAILogicDeveloperAPI`: Firebase AI Logic proxy to Gemini Developer
  API (`firebasevertexai.googleapis.com`).
* `.firebaseAILogicAgentPlatform(location:)`: Firebase AI Logic proxy to Gemini
  Enterprise Agent Platform (defaulting to `location: "global"`).
* `.developerAPI`: Direct Gemini Developer API
  (`generativelanguage.googleapis.com`). Disabled by default; uncomment it in
  `IntegrationTestingBackend.allCases` for manual testing.

## Files in this Directory

* [`BasicContentGenerationIntegrationTests.swift`](BasicContentGenerationIntegrationTests.swift):
  Parameterized integration tests for single-turn prompt response, multi-turn
  chat sessions, and streaming chunk responses.
* [`GuidedGenerationIntegrationTests.swift`](GuidedGenerationIntegrationTests.swift):
  Parameterized integration tests for guided generation (structured outputs)
  using `@Generable` types, including single-turn and streaming generation,
  enum classification, and rich multi-type recursive hierarchies.
* [`ToolCallingIntegrationTests.swift`](ToolCallingIntegrationTests.swift):
  Parameterized integration tests for tool calling (function calling) using
  FoundationModels `Tool` definitions, covering single-turn tool calls,
  sequential tool calls, parallel tool calls, tool calling mode configuration,
  parameterless tools with empty arguments, and reasoning models.
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
