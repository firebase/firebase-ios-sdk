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

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

import FirebaseCore
import FirebaseAppCheckInterop
import FirebaseAuthInterop

@available(iOS 15.0, macOS 13.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class APIClient: Sendable {

  /// The language of the SDK in the format `gl-<language>/<version>`.
  static let languageTag = "gl-swift/5"

  let backend: Backend
  let authenticationMethod: AuthenticationMethod
  let urlSession: URLSession
  let firebaseInfo: FirebaseInfo?
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  public init(backend: Backend, authentication: AuthenticationMethod, urlSession: URLSession) {
    if case .firebase(let app, let useLimitedUseAppCheckTokens) = authentication {
      guard let projectID = app.options.projectID else {
        fatalError("The Firebase app named \"\(app.name)\" has no project ID in its configuration.")
      }
      guard let apiKey = app.options.apiKey else {
        fatalError("The Firebase app named \"\(app.name)\" has no API key in its configuration.")
      }
      firebaseInfo = FirebaseInfo(
        appCheck: ComponentType<AppCheckInterop>.instance(
          for: AppCheckInterop.self,
          in: app.container
        ),
        auth: ComponentType<AuthInterop>.instance(for: AuthInterop.self, in: app.container),
        projectID: projectID,
        apiKey: apiKey,
        firebaseAppID: app.options.googleAppID,
        firebaseApp: app,
        useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
      )
    } else {
      firebaseInfo = nil
    }

    self.backend = backend
    self.authenticationMethod = authentication
    self.urlSession = urlSession
  }

  init(backend: Backend, authentication: AuthenticationMethod, urlSession: URLSession, firebaseInfo: FirebaseInfo?) {
    self.backend = backend
    self.authenticationMethod = authentication
    self.urlSession = urlSession
    self.firebaseInfo = firebaseInfo
  }

  /// Whether the Vertex AI backend is being used.
  public func isVertexAI() -> Bool {
    guard case .vertexAI = backend else {
      return false
    }

    return true
  }

  /// Whether the Google AI backend is being used.
  public func isMlDeveloper() -> Bool {
    guard case .googleAI = backend else {
      return false
    }

    return true
  }

  /// Whether the Firebase authentication is being used.
  public func isFirebase() -> Bool {
    guard case .firebase = authenticationMethod else {
      return false
    }

    return true
  }

  // TODO: Add support for extra query parameters whenever we add a proper conversion layer
  func url(for endpoint: String, model: String? = nil) throws -> URL {
    guard var url = URL(string: baseURL()) else {
      throw NSError(
        domain: "Swift SDK",
        code: 0,
        userInfo: [
          NSLocalizedFailureReasonErrorKey: "Invalid URL: \(baseURL())"
        ]
      )
    }

    switch backend {
    case .vertexAI(_, _, _, let version):
      // vertex uses v1beta1 instead of v1beta (unless you're using firebase)
      let versionName = version == .v1beta && !isFirebase() ? "v1beta1" : "\(version)"
      url = url.appendingPathComponent("/\(versionName)", isDirectory: true)
    case .googleAI(let version, _):
      url = url.appendingPathComponent("/\(version)", isDirectory: true)
    }

    if let model {
      url = url.appendingPathComponent(modelName(for: model), isDirectory: true)
    }

    if !endpoint.isEmpty {
      url = url.appendingPathComponent("\(endpoint)", isDirectory: false)
    }

    return url
  }

  /// Computes the name of a model, depending on the backend.
  ///
  /// Also takes into account if the firebase proxy is being used.
  private func modelName(for model: String) -> String {
    switch backend {
    case .vertexAI(let location, let publisher, let projectId, _):
      return "projects/\(projectId)/locations/\(location)/publishers/\(publisher)/models/\(model)"
    case .googleAI(_, let direct):
      if !direct, let projectId = firebaseInfo?.projectID {
        return "projects/\(projectId)/models/\(model)"
      }
      return "models/\(model)"
    }
  }

  /// Computes the base URL for the currently targeted backend.
  ///
  /// Takes into account if the firebase proxy is being used, and if direct mode is enabled for
  /// the Google AI backend.
  private func baseURL() -> String {
    switch backend {
    case .vertexAI:
      if !isFirebase() {
        return "https://aiplatform.googleapis.com"
      }
    case .googleAI(_, let direct):
      if direct || !isFirebase() {
        return "https://generativelanguage.googleapis.com"
      }
    }

    // Firebase proxy endpoint; supports both Google AI/Vertex AI backends
    return "https://firebasevertexai.googleapis.com"
  }

  func loadRequest<RequestParams: Encodable, ResponseType: Decodable>(
    params: RequestParams,
    url: URL,
    method: String
  ) async throws -> ResponseType {
    let urlRequest = try await urlRequest(params: params, url: url, method: method)
    return try await performRequest(urlRequest)
  }

  func loadRequest<ResponseType: Decodable>(
    params: [String: Any],
    url: URL,
    method: String
  ) async throws -> ResponseType {
    let urlRequest = try await urlRequest(params: params, url: url, method: method)
    return try await performRequest(urlRequest)
  }

  private func performRequest<ResponseType: Decodable>(_ urlRequest: URLRequest) async throws -> ResponseType {
//#if DEBUG
  printCURLCommand(from: urlRequest)
//#endif

    let data: Data
    let rawResponse: URLResponse
    (data, rawResponse) = try await urlSession.data(for: urlRequest)

    let response = try httpResponse(urlResponse: rawResponse)

    // Verify the status code is 200
    guard response.statusCode == 200 else {
      AILog.error(
        code: .loadRequestResponseError,
        "The server responded with an error: \(response)"
      )
      if let responseString = String(data: data, encoding: .utf8) {
        AILog.error(
          code: .loadRequestResponseErrorPayload,
          "Response payload: \(responseString)"
        )
      }

      throw parseError(httpResponseCode: response.statusCode, responseData: data)
    }

    decoder.userInfo[.configuration] = self

    // If the expected type is Data, return the raw data directly
    if ResponseType.self == Data.self {
      return data as! ResponseType
    }

    return try parseResponse(ResponseType.self, from: data)
  }

  // TODO(daymxn): implement streaming support once we have proper support/testing for non streaming
 /// Loads a stream request where the parameters are a dictionary `[String: Any]`.
  @available(macOS 13.0, *)
  func loadRequestStream<ResponseType: Decodable>(
    params: [String: Any],
    url: URL,
    method: String
  ) -> AsyncThrowingStream<ResponseType, Error> {
    return AsyncThrowingStream { continuation in
      // TODO: Implement actual streaming logic here.
      fatalError("Streaming implementation pending")
    }
  }

  // MARK: - Private Helpers

  private func urlRequest<Params: Encodable>(
    params: Params,
    url: URL,
    method: String
  ) async throws -> URLRequest {
    var urlRequest = try await makeBaseURLRequest(url: url, method: method)
    encoder.userInfo[.configuration] = self
    urlRequest.httpBody = try encoder.encode(params)
    return urlRequest
  }

  private func urlRequest(
    params: [String: Any],
    url: URL,
    method: String
  ) async throws -> URLRequest {
    var urlRequest = try await makeBaseURLRequest(url: url, method: method)
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: params)
    return urlRequest
  }

  private func makeBaseURLRequest(url: URL, method: String) async throws -> URLRequest {
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = method

    switch authenticationMethod {
    case .apiKey(let key):
      urlRequest.setValue(key, forHTTPHeaderField: "x-goog-api-key")
    case .accessToken(let token):
      urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    case .firebase:
      guard let firebaseInfo else {
        fatalError("FirebaseInfo should be defined for Firebase authentication.")
      }
      urlRequest.setValue(firebaseInfo.apiKey, forHTTPHeaderField: "x-goog-api-key")
    }

    let version = isFirebase() ? " \(FirebaseVersion())" : ""
    urlRequest.setValue(
      "\(APIClient.languageTag)\(version)",
      forHTTPHeaderField: "x-goog-api-client"
    )
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    try await addFirebaseHeaders(for: &urlRequest)

    return urlRequest
  }

  /// Adds headers to a url request that are unique to Firebase.
  ///
  /// Headers include:
  /// - App Check
  /// - Auth
  /// - Data Collection
  ///
  /// If the Firebase authentication method isn't being used, then calling this method is no-op.
  private func addFirebaseHeaders(for urlRequest: inout URLRequest) async throws {
    guard let firebaseInfo else {
      return
    }

    if let appCheck = firebaseInfo.appCheck {
      let tokenResult = try await appCheck.fetchAppCheckToken(
        limitedUse: firebaseInfo.useLimitedUseAppCheckTokens,
        domain: "\(Self.self)"
      )
      urlRequest.setValue(tokenResult.token, forHTTPHeaderField: "X-Firebase-AppCheck")
      if let error = tokenResult.error {
        AILog.error(
          code: .appCheckTokenFetchFailed,
          "Failed to fetch AppCheck token. Error: \(error)"
        )
      }
    }

    if let auth = firebaseInfo.auth, let authToken = try await auth.getToken(forcingRefresh: false) {
      urlRequest.setValue("Firebase \(authToken)", forHTTPHeaderField: "Authorization")
    }

    if firebaseInfo.app.isDataCollectionDefaultEnabled == true {
      urlRequest.setValue(firebaseInfo.firebaseAppID, forHTTPHeaderField: "X-Firebase-AppId")
      if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-Firebase-AppVersion")
      }
    }
  }

  private func httpResponse(urlResponse: URLResponse) throws -> HTTPURLResponse {
    // The following condition should always be true: "Whenever you make HTTP URL load requests, any
    // response objects you get back from the URLSession, NSURLConnection, or NSURLDownload class
    // are instances of the HTTPURLResponse class."
    guard let response = urlResponse as? HTTPURLResponse else {
      AILog.error(
        code: .generativeAIServiceNonHTTPResponse,
        "Response wasn't an HTTP response, internal error \(urlResponse)"
      )
      throw URLError(
        .badServerResponse,
        userInfo: [NSLocalizedDescriptionKey: "Response was not an HTTP response."]
      )
    }

    return response
  }

  private func jsonData(jsonText: String) throws -> Data {
    guard let data = jsonText.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(DecodingError.Context(
        codingPath: [],
        debugDescription: "Could not parse response as UTF8."
      ))
    }
    return data
  }

  private func parseError(httpResponseCode: Int, responseBody: String) -> Error {
    do {
      let data = try jsonData(jsonText: responseBody)
      return parseError(httpResponseCode: httpResponseCode, responseData: data)
    } catch {
      return error
    }
  }

  private func parseError(httpResponseCode: Int, responseData: Data) -> Error {
    do {
      let rpcError = try decoder.decode(RPCError.self, from: responseData)
      let backendError = BackendError(httpResponseCode: httpResponseCode, error: rpcError)
      logRPCError(backendError)
      return backendError
    } catch {
      return UnrecognizedBackendError(underlyingError: error, httpStatusCode: httpResponseCode)
    }
  }

  // Log specific RPC errors that cannot be mitigated or handled by user code.
  // These errors do not produce specific GenerateContentError or CountTokensError cases.
  private func logRPCError(_ error: BackendError) {
    guard let firebaseInfo else { return }

    let projectID = firebaseInfo.projectID
    if error.isVertexAIInFirebaseServiceDisabledError() {
      AILog.error(code: .vertexAIInFirebaseAPIDisabled, """
      The Firebase AI SDK requires the Firebase AI API \
      (`firebasevertexai.googleapis.com`) to be enabled in your Firebase project. Enable this API \
      by visiting the Firebase Console at
      https://console.firebase.google.com/project/\(projectID)/genai/ and clicking "Get started". \
      If you enabled this API recently, wait a few minutes for the action to propagate to our \
      systems and then retry.
      """)
    }
  }

  private func parseResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      if let json = String(data: data, encoding: .utf8) {
        AILog.error(code: .loadRequestParseResponseFailedJSON, "JSON response: \(json)")
      }
      AILog.error(
        code: .loadRequestParseResponseFailedJSONError,
        "Error decoding server JSON: \(error)"
      )
      throw error
    }
  }

//  #if DEBUG
    private func cURLCommand(from request: URLRequest) -> String {
      var returnValue = "curl "
      if let allHeaders = request.allHTTPHeaderFields {
        for (key, value) in allHeaders {
          returnValue += "-H '\(key): \(value)' "
        }
      }

      guard let url = request.url else { return "" }
      returnValue += "'\(url.absoluteString)' "

      guard let body = request.httpBody,
            let jsonStr = String(bytes: body, encoding: .utf8) else { return "" }
      let escapedJSON = jsonStr.replacingOccurrences(of: "'", with: "'\\''")
      returnValue += "-d '\(escapedJSON)'"

      return returnValue
    }

    private func printCURLCommand(from request: URLRequest) {
      guard AILog.additionalLoggingEnabled() else {
        return
      }
      let command = cURLCommand(from: request)
      AILog.debug(code: .fallbackValueUsed,
        """
        Creating request with the equivalent cURL command:
        ----- cURL command -----
        \(command)
        ------------------------
        """)
    }
//  #endif // DEBUG
}
