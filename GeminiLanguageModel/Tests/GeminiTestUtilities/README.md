# GeminiTestUtilities

Shared testing infrastructure, network mocking utilities, environment condition
traits, and integration test backends for `GeminiLanguageModel` and
`GeminiAPIClient`.

## Overview

`GeminiTestUtilities` is an internal test support target consumed across all
test suites in the package. It provides centralized utilities so tests avoid
duplicating mock handlers, endpoint URLs, credential checks, or port probes.

## Component Breakdown

| Category | Files | Purpose |
|---|---|---|
| **Network Mocking** | [`MockHTTPURLProtocol.swift`](MockHTTPURLProtocol.swift), [`HTTPURLResponse+Mock.swift`](HTTPURLResponse+Mock.swift) | Offline URLSession request interception, response mocking, and SSE streaming simulation |
| **Integration Backends** | [`IntegrationTestingBackend.swift`](IntegrationTestingBackend.swift), [`AppCheckDebugClient.swift`](AppCheckDebugClient.swift) | Backend routing configurations, TCP socket probing, App Check debug token exchange and caching |
| **Testing Traits & Tags** | [`ConditionTrait+Credentials.swift`](ConditionTrait+Credentials.swift), [`ConditionTrait+FoundationModels.swift`](ConditionTrait+FoundationModels.swift), [`Tag+Integration.swift`](Tag+Integration.swift) | Swift Testing conditional skip traits (`.requireAPIKey`, `.requireFoundationModels`) and `.integration` tag |
| **Constants** | [`TestConstants.swift`](TestConstants.swift) | Centralized model resource IDs and canonical endpoint configurations |

## Common Recipes

### 1. Mocking HTTP URL Responses

Use `MockHTTPURLProtocol` and `HTTPURLResponse.mock` to simulate API responses
without network access:

```swift
defer { MockHTTPURLProtocol.reset() }
let expectedURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")!
let response = try HTTPURLResponse.mock(url: expectedURL, statusCode: 200)

MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
  proto.client?.urlProtocol(proto, didReceive: response, cacheStoragePolicy: .notAllowed)
  proto.client?.urlProtocol(proto, didLoad: Data("{}".utf8))
  proto.client?.urlProtocolDidFinishLoading(proto)
}
```

### 2. Guarding Tests with Condition Traits

Swift Testing condition traits allow tests to cleanly skip when prerequisites
(like API keys or specific OS versions) are absent:

```swift
// Skip if neither local test-server nor remote credentials are available
@Test(.requireIntegrationTestingBackend)
func myBackendTest() async throws { ... }

// Skip on platforms where FoundationModels is unavailable (< macOS 27)
@Suite("Model Tests", .requireFoundationModels)
struct ModelTests { ... }
```

### 3. App Check Token Caching

`AppCheckTokenCache` manages debug token exchange for Firebase AI Logic
integration tests, caching active tokens in-memory and deduplicating in-flight
network requests:

```swift
let token = try await AppCheckTokenCache.shared.token(
  projectID: projectID,
  appID: appID,
  apiKey: apiKey,
  debugToken: debugToken
)
```
