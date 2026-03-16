// Copyright 2025 Google LLC
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

import XCTest
import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import GeneratedFirebaseAI

import FirebaseCore
import FirebaseAppCheckInterop
import FirebaseAuthInterop

class APIClientTests: XCTestCase {
  lazy var firebaseApp: FirebaseApp = {
    FirebaseFake(options: FirebaseOptions(apiKey: TestConstants.APIKey, projectID: TestConstants.ProjectID))
  }()

  lazy var mockSession: URLSession = {
    mockURLSession { request in
      let requestData = URLRequestData(from: request)
      let data = try JSONEncoder().encode(requestData)
      guard let response = HTTPURLResponse(url: requestData.url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
        fatalError("Failed to create HTTP response")
      }
      return (response, data)
    }
  }()

  override func tearDown() {
    MockURLProtocol.requestHandler = nil
  }

  func testUrlWorksWithGoogleAI() async throws {
    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .apiKey(TestConstants.APIKey),
      urlSession: mockSession
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    XCTAssertEqual(
      url.absoluteString,
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash/:generateContent"
    )
  }

  func testUrlWorksWithVertexAI() async throws {
    let api = APIClient(
      backend: .vertexAI(
        location: "test-location",
        publisher: "test-publisher",
        projectId: TestConstants.ProjectID,
        version: .v1beta
      ),
      authentication: .accessToken(TestConstants.APIKey),
      urlSession: mockSession
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    XCTAssertEqual(
      url.absoluteString,
      "https://aiplatform.googleapis.com/v1beta1/projects/\(TestConstants.ProjectID)/locations/test-location/publishers/test-publisher/models/gemini-2.0-flash/:generateContent"
    )
  }

  func testUrlWorksWithFirebaseAndVertexAI() async throws {
    let api = APIClient(
      backend: .vertexAI(
        location: "test-location",
        publisher: "test-publisher",
        projectId: TestConstants.ProjectID,
        version: .v1beta
      ),
      authentication: .firebase(app: firebaseApp),
      urlSession: mockSession
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    XCTAssertEqual(
      url.absoluteString,
      "https://firebasevertexai.googleapis.com/v1beta/projects/\(TestConstants.ProjectID)/locations/test-location/publishers/test-publisher/models/gemini-2.0-flash/:generateContent"
    )
  }

  func testUrlWorksWithFirebaseAndGoogleAI() async throws {
    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .firebase(app: firebaseApp),
      urlSession: mockSession
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    XCTAssertEqual(
      url.absoluteString,
      "https://firebasevertexai.googleapis.com/v1beta/projects/\(TestConstants.ProjectID)/models/gemini-2.0-flash/:generateContent"
    )
  }

  func testUrlWorksWithFirebaseAndGoogleAIDirect() async throws {
    let api = APIClient(
      backend: .googleAI(version: .v1beta, direct: true),
      authentication: .firebase(app: firebaseApp),
      urlSession: mockSession
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    XCTAssertEqual(
      url.absoluteString,
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash/:generateContent"
    )
  }

  func testAddsProperHeadersWithGoogleAI() async throws {
    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .apiKey(TestConstants.APIKey),
      urlSession: mockSession
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    let response: URLRequestData = try await api.loadRequest(params: EmptyRequest(), url: url, method: "POST")

    XCTAssertEqual(response.headers["x-goog-api-key"], TestConstants.APIKey)
    XCTAssertEqual(response.headers["x-goog-api-client"], "gl-swift/5")
    XCTAssertEqual(response.headers["Content-Type"], "application/json")
  }

  func testAddsProperHeadersWithVertexAI() async throws {
    let api = APIClient(
      backend: .vertexAI(projectId: TestConstants.ProjectID),
      authentication: .accessToken(TestConstants.APIKey),
      urlSession: mockSession
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    let response: URLRequestData = try await api.loadRequest(params: EmptyRequest(), url: url, method: "POST")

    XCTAssertEqual(response.headers["Authorization"], "Bearer \(TestConstants.APIKey)")
    XCTAssertEqual(response.headers["x-goog-api-client"], "gl-swift/5")
    XCTAssertEqual(response.headers["Content-Type"], "application/json")
  }

  func testAddsProperHeadersWithFirebase() async throws {
    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .firebase(app: firebaseApp),
      urlSession: mockSession,
      firebaseInfo: FirebaseInfo(app: firebaseApp)
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    let response: URLRequestData = try await api.loadRequest(params: EmptyRequest(), url: url, method: "POST")

    XCTAssertEqual(response.headers["x-goog-api-key"], TestConstants.APIKey)
    XCTAssertEqual(response.headers["x-goog-api-client"], "gl-swift/5 \(FirebaseVersion())")
    XCTAssertEqual(response.headers["Content-Type"], "application/json")
  }

  func testAddsAppCheckHeader() async throws {
    let appCheck = AppCheckInteropFake(token: "fake-test-token")

    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .firebase(app: firebaseApp),
      urlSession: mockSession,
      firebaseInfo: FirebaseInfo(app: firebaseApp, appCheck: appCheck)
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    let response: URLRequestData = try await api.loadRequest(params: EmptyRequest(), url: url, method: "POST")

    XCTAssertEqual(response.headers["X-Firebase-AppCheck"], "fake-test-token")
  }

  func testAddsFirebaseAuthHeader() async throws {
    let auth = AuthInteropFake(token: "fake-test-token")

    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .firebase(app: firebaseApp),
      urlSession: mockSession,
      firebaseInfo: FirebaseInfo(app: firebaseApp, auth: auth)
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    let response: URLRequestData = try await api.loadRequest(params: EmptyRequest(), url: url, method: "POST")

    XCTAssertEqual(response.headers["Authorization"], "Firebase fake-test-token")
  }

  func testAddsFirebaseDataCollectionHeaders() async throws {
    firebaseApp.isDataCollectionDefaultEnabled = true

    guard let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
      XCTFail("Missing short version string in main bundle")
      return
    }

    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .firebase(app: firebaseApp),
      urlSession: mockSession,
      firebaseInfo: FirebaseInfo(app: firebaseApp)
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    let response: URLRequestData = try await api.loadRequest(params: EmptyRequest(), url: url, method: "POST")

    XCTAssertEqual(response.headers["X-Firebase-AppId"], TestConstants.GoogleAppId)
    XCTAssertEqual(response.headers["X-Firebase-AppVersion"], bundleVersion)
  }

  func testUsesLimitedUseTokens() async throws {
    let appCheck = AppCheckInteropFake(token: "fake-test-token")

    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .firebase(app: firebaseApp),
      urlSession: mockSession,
      firebaseInfo: FirebaseInfo(app: firebaseApp, appCheck: appCheck, useLimitedUseTokens: true)
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)
    let response: URLRequestData = try await api.loadRequest(params: EmptyRequest(), url: url, method: "POST")

    XCTAssertEqual(response.headers["X-Firebase-AppCheck"], "limited_use_fake-test-token")
  }

  func testCatchesRPCErrors() async throws {
    let rpcErrorData = """
    {
      "error": {
        "code": 500,
        "message": "TEST FAILURE MESSAGE",
        "status": "TEST_STATUS",
        "details": [
          {
            "@type": "type.googleapis.com/google.rpc.ErrorInfo",
            "reason": "TEST_REASON",
            "metadata": {
              "method": "google.cloud.aiplatform.v1beta1.PredictionService.GenerateContent",
              "service": "aiplatform.googleapis.com"
            }
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let mockSession = mockURLSession { request in
      guard
        let url = request.url,
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
      else {
        fatalError("Failed to create HTTP response")
      }
      return (response, rpcErrorData)
    }

    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .apiKey(TestConstants.APIKey),
      urlSession: mockSession
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)

    do {
      let _: EmptyResponse = try await api.loadRequest(params: EmptyRequest(), url: url, method: "POST")
      XCTFail("Expected an error to be thrown.")
    } catch {
      XCTAssert(error is BackendError)
      let backendError = error as! BackendError
      XCTAssertEqual(backendError.httpResponseCode, 500)
      XCTAssertEqual(backendError.message, "TEST FAILURE MESSAGE")
      XCTAssertEqual(backendError.status, "TEST_STATUS")
    }
  }

  func testCatchesNon200Responses() async throws {
    let mockSession = mockURLSession { request in
      guard
        let url = request.url,
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
      else {
        fatalError("Failed to create HTTP response")
      }
      return (response, "".data(using: .utf8)!)
    }

    let api = APIClient(
      backend: .googleAI(version: .v1beta),
      authentication: .apiKey(TestConstants.APIKey),
      urlSession: mockSession
    )

    let url = try api.url(for: ":generateContent", model: TestConstants.Model)

    do {
      let _: EmptyResponse = try await api.loadRequest(params: EmptyRequest(), url: url, method: "POST")
      XCTFail("Expected an error to be thrown.")
    } catch {
      guard let error = error as? UnrecognizedBackendError else {
        return XCTFail("Unexpected error type: \(error)")
      }
      XCTAssertEqual(error.httpStatusCode, 500)
    }
  }
}

extension FirebaseInfo {
  /// Helper initializer with default values that are only relevant for tests.
  init(
    app: FirebaseApp,
    appCheck: AppCheckInterop? = nil,
    auth: AuthInterop? = nil,
    useLimitedUseTokens: Bool = false
  ) {
    self.init(
      appCheck: appCheck,
      auth: auth,
      projectID: TestConstants.ProjectID,
      apiKey: TestConstants.APIKey,
      firebaseAppID: TestConstants.GoogleAppId,
      firebaseApp: app,
      useLimitedUseAppCheckTokens: useLimitedUseTokens
    )
  }
}
