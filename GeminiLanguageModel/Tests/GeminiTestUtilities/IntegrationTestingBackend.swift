// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if canImport(Testing)
  import Foundation
  package import GeminiAPIClient
  package import Testing

  #if canImport(Glibc)
    import Glibc
  #elseif canImport(Musl)
    import Musl
  #endif

  /// Represents an integration testing backend for Gemini API requests.
  package enum IntegrationTestingBackend:
    Sendable,
    Hashable,
    CaseIterable,
    CustomStringConvertible
  {
    /// Gemini Developer API (via `generativelanguage.googleapis.com` or local `test-server`).
    case developerAPI

    /// Firebase AI Logic proxying to the Gemini Developer API (via
    /// `firebasevertexai.googleapis.com` or local `test-server`).
    case firebaseAILogicDeveloperAPI

    /// Firebase AI Logic proxying to the Gemini Enterprise Agent Platform (via
    /// `firebasevertexai.googleapis.com` or local `test-server`).
    case firebaseAILogicAgentPlatform(location: String)

    /// Convenience instance targeting the global Gemini Enterprise Agent Platform.
    package static var firebaseAILogicAgentPlatform: IntegrationTestingBackend {
      .firebaseAILogicAgentPlatform(location: "global")
    }

    /// All canonical backend configurations for parameterized testing.
    package static let allCases: [IntegrationTestingBackend] = [
      .developerAPI,
      .firebaseAILogicDeveloperAPI,
      .firebaseAILogicAgentPlatform(location: "global"),
    ]

    package var description: String {
      switch self {
      case .developerAPI:
        return "Developer API"
      case .firebaseAILogicDeveloperAPI:
        return "Firebase AI Logic (Developer API)"
      case .firebaseAILogicAgentPlatform(let location):
        return "Firebase AI Logic (Agent Platform, \(location))"
      }
    }

    /// Indicates whether the required server or credentials are available for this backend.
    package var isAvailable: Bool {
      switch self {
      case .developerAPI:
        return isTestServerRunning(port: defaultTestServerPort) || hasGeminiAPIKey
      case .firebaseAILogicDeveloperAPI, .firebaseAILogicAgentPlatform:
        return isTestServerRunning(port: defaultTestServerFirebasePort)
          || hasFirebaseAILogicCredentials
      }
    }

    /// The list of backends that are currently available to execute tests against.
    package static var availableBackends: [IntegrationTestingBackend] {
      allCases.filter(\.isAvailable)
    }

    /// The network endpoint configuration for this backend.
    package var endpointConfiguration: EndpointConfiguration {
      switch self {
      case .developerAPI:
        if isTestServerRunning(port: defaultTestServerPort) {
          return EndpointConfiguration(
            scheme: "http",
            host: "localhost",
            port: defaultTestServerPort,
            apiVersion: EndpointConfiguration.geminiDeveloperAPIVersion
          )
        }
        return .geminiDeveloperAPI

      case .firebaseAILogicDeveloperAPI, .firebaseAILogicAgentPlatform:
        if isTestServerRunning(port: defaultTestServerFirebasePort) {
          return EndpointConfiguration(
            scheme: "http",
            host: "localhost",
            port: defaultTestServerFirebasePort,
            apiVersion: EndpointConfiguration.firebaseAILogicAPIVersion
          )
        }
        return .firebaseAILogic
      }
    }

    /// The model resource configuration for this backend given a model identifier.
    package func modelResource(
      modelID: String = ModelResource.gemini35FlashLiteID
    ) throws -> ModelResource {
      switch self {
      case .developerAPI:
        return ModelResource(
          modelID: modelID,
          urlResourceName: "models/\(modelID)",
          payloadResourceName: "models/\(modelID)"
        )

      case .firebaseAILogicDeveloperAPI:
        let projectID = try resolveProjectID()
        return ModelResource(
          modelID: modelID,
          urlResourceName: "projects/\(projectID)/models/\(modelID)",
          payloadResourceName: "models/\(modelID)"
        )

      case .firebaseAILogicAgentPlatform(let location):
        let projectID = try resolveProjectID()
        let resourcePath =
          "projects/\(projectID)/locations/\(location)/publishers/google/models/\(modelID)"
        return ModelResource(
          modelID: modelID,
          urlResourceName: resourcePath,
          payloadResourceName: "models/\(modelID)"
        )
      }
    }

    /// Creates the authentication header provider for this backend.
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    package func makeHeaderProvider() async throws -> (
      @Sendable () async throws -> [String: String]
    )? {
      switch self {
      case .developerAPI:
        if let apiKey = geminiAPIKey {
          return { ["x-goog-api-key": apiKey] }
        }
        return nil

      case .firebaseAILogicDeveloperAPI, .firebaseAILogicAgentPlatform:
        let isProxy = isTestServerRunning(port: defaultTestServerFirebasePort)
        if isProxy && !hasFirebaseAILogicCredentials {
          let apiKey = firebaseAPIKey ?? "test-api-key"
          return {
            [
              "x-goog-api-key": apiKey,
              "x-firebase-appcheck": "test-token",
            ]
          }
        }
        let projectID = try #require(firebaseProjectID)
        let appID = try #require(firebaseAppID)
        let apiKey = try #require(firebaseAPIKey)
        let debugToken = try #require(appCheckDebugToken)
        let appCheckToken = try await AppCheckTokenCache.shared.token(
          projectID: projectID,
          appID: appID,
          apiKey: apiKey,
          debugToken: debugToken
        )
        return {
          [
            "x-goog-api-key": apiKey,
            "x-firebase-appcheck": appCheckToken,
          ]
        }
      }
    }

    private func resolveProjectID() throws -> String {
      let isProxy = isTestServerRunning(port: defaultTestServerFirebasePort)
      if isProxy && !hasFirebaseAILogicCredentials {
        return firebaseProjectID ?? "REDACTED"
      }
      return try #require(firebaseProjectID)
    }
  }

  // MARK: - Server Ports and Probing

  /// The default port number used by `test-server` for Developer API requests.
  package var defaultTestServerPort: Int {
    if let envStr = ProcessInfo.processInfo.environment["TEST_SERVER_PORT"],
      let port = Int(envStr)
    {
      return port
    }
    return 1443
  }

  /// The default port number used by `test-server` for Firebase AI Logic requests.
  package var defaultTestServerFirebasePort: Int {
    if let fbStr = ProcessInfo.processInfo.environment["TEST_SERVER_FIREBASE_PORT"],
      let port = Int(fbStr)
    {
      return port
    }
    if let envStr = ProcessInfo.processInfo.environment["TEST_SERVER_PORT"],
      let port = Int(envStr)
    {
      return port + 1
    }
    return 1444
  }

  private final class TestServerStatusCache: @unchecked Sendable {
    static let shared = TestServerStatusCache()
    private let lock = NSLock()
    private var cache: [Int: Bool] = [:]

    func status(for port: Int, probe: () -> Bool) -> Bool {
      if let cached = lock.withLock({ cache[port] }) {
        return cached
      }
      let isRunning = probe()
      lock.withLock { cache[port] = isRunning }
      return isRunning
    }

    func reset() {
      lock.withLock { cache.removeAll() }
    }
  }

  /// Checks whether `test-server` is actively listening on localhost at the specified port.
  package func isTestServerRunning(port: Int = defaultTestServerPort) -> Bool {
    TestServerStatusCache.shared.status(for: port) {
      probePort(port)
    }
  }

  /// Clears the cached `test-server` port probe results.
  package func resetTestServerStatusCache() {
    TestServerStatusCache.shared.reset()
  }

  private func probePort(_ port: Int) -> Bool {
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(port).bigEndian
    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

    let sock = socket(AF_INET, SOCK_STREAM, 0)
    guard sock >= 0 else { return false }
    defer { close(sock) }

    var tv = timeval(tv_sec: 0, tv_usec: 50_000)
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

    return withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
      }
    }
  }

  // MARK: - Testing Traits

  /// Indicates whether any integration backend (Developer API or Firebase AI Logic) is available.
  package var hasIntegrationTestingBackend: Bool {
    !IntegrationTestingBackend.availableBackends.isEmpty
  }

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  extension Trait where Self == Testing.ConditionTrait {
    /// Requires at least one integration backend to be available.
    package static var requireIntegrationTestingBackend: Self {
      .enabled(
        if: hasIntegrationTestingBackend,
        Comment(
          rawValue: "Requires test-server running on localhost or credentials for Developer API / "
            + "Firebase AI Logic"
        )
      )
    }
  }
#endif  // canImport(Testing)
