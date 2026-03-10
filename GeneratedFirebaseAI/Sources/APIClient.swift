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

import Foundation
import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore

#if os(Linux)
  import FoundationNetworking
#endif


/// Needs testing, but since our dict is JSON encoded, it should be sendable anyways, but it's hard
/// to define that in a type safe manner. This wrapper type should help fix that.
struct SendableDict: @unchecked Sendable {
  let dictionary: NSDictionary
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class APIClient: Sendable {
  /// The language of the SDK in the format `gl-<language>/<version>`.
  static let languageTag = "gl-swift/5"

  let backend: Backend
  let authenticationMethod: AuthenticationMethod
  let urlSession: URLSession
  let firebaseInfo: FirebaseInfo?
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  public init(backend: Backend, authentication: AuthenticationMethod, urlSession: URLSession) throws
  {
    if case let .firebase(app, useLimitedUseAppCheckTokens) = authentication {
      guard let projectID = app.options.projectID else {
        throw CommonErrors.MissingFirebaseProjectID(appName: app.name)
      }
      guard let apiKey = app.options.apiKey else {
        throw CommonErrors.MissingFirebaseAPIKey(appName: app.name)
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
    authenticationMethod = authentication
    self.urlSession = urlSession
  }

  init(backend: Backend, authentication: AuthenticationMethod, urlSession: URLSession,
       firebaseInfo: FirebaseInfo?) {
    self.backend = backend
    authenticationMethod = authentication
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

  /// Computes the base URL for the currently targeted backend.
  ///
  /// Takes into account if the firebase proxy is being used, and if direct mode is enabled for
  /// the Google AI backend.
  private func baseURL() -> String {
    switch backend {
    case let .vertexAI(_, _, _, version):
      if !isFirebase() {
        // vertex uses v1beta1 instead of v1beta (unless you're using firebase)
        let versionName = version == .v1beta ? "v1beta1" : "\(version)"
        return "https://aiplatform.googleapis.com/\(versionName)"
      }
      return "https://firebasevertexai.googleapis.com/\(version)"
    case let .googleAI(version, direct):
      if direct || !isFirebase() {
        return "https://generativelanguage.googleapis.com/\(version)"
      }
      return "https://firebasevertexai.googleapis.com/\(version)"
    }
  }

  private func performRequest(_ urlRequest: URLRequest) async throws -> NSMutableDictionary {
    // #if DEBUG
    printCURLCommand(from: urlRequest)
    // #endif

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

    return try parseResponse(from: data)
  }

  func prepareRequest(params: NSMutableDictionary,
                      url: String) throws -> (URL, SendableDict) {
    let url = try createURL(params: params, templateUrl: "\(baseURL())/\(url)")
    let bodyParams = SendableDict(dictionary: params)

    return (url, bodyParams)
  }

  func loadRequest(params: NSMutableDictionary,
                   url: String,
                   method: String) async throws -> NSMutableDictionary {
    let url = try createURL(params: params, templateUrl: "\(baseURL())/\(url)")
    let bodyParams = SendableDict(dictionary: params)
    let urlRequest = try await urlRequest(params: bodyParams, url: url, method: method)

    return try await performRequest(urlRequest)
  }

  func loadRequestStream(params: SendableDict,
                         url: URL,
                         method: String) throws -> AsyncThrowingStream<NSMutableDictionary, Error> {
    return AsyncThrowingStream { continuation in
      Task {
        let urlRequest: URLRequest
        do {
          urlRequest = try await self.urlRequest(params: params, url: url, method: method)
        } catch {
          continuation.finish(throwing: error)
          return
        }

        // #if DEBUG
        printCURLCommand(from: urlRequest)
        // #endif

        let stream: URLSession.AsyncBytes
        let rawResponse: URLResponse
        do {
          (stream, rawResponse) = try await urlSession.bytes(for: urlRequest)
        } catch {
          continuation.finish(throwing: error)
          return
        }

        // Verify the status code is 200
        let response: HTTPURLResponse
        do {
          response = try httpResponse(urlResponse: rawResponse)
        } catch {
          continuation.finish(throwing: error)
          return
        }

        // Verify the status code is 200
        guard response.statusCode == 200 else {
          AILog.error(
            code: .loadRequestStreamResponseError,
            "The server responded with an error: \(response)"
          )
          var responseBody = ""
          for try await line in stream.lines {
            responseBody += line + "\n"
          }

          AILog.error(
            code: .loadRequestStreamResponseErrorPayload,
            "Response payload: \(responseBody)"
          )
          continuation.finish(
            throwing: parseError(httpResponseCode: response.statusCode, responseBody: responseBody)
          )

          return
        }

        // Received lines that are not server-sent events (SSE); these are not prefixed with "data:"
        var extraLines = ""

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        for try await line in stream.lines {
          AILog.debug(code: .loadRequestStreamResponseLine, "Stream response: \(line)")

          if line.hasPrefix("data:") {
            // We can assume 5 characters since it's utf-8 encoded, removing `data:`.
            let jsonText = String(line.dropFirst(5))
            let data: Data
            do {
              data = try jsonData(jsonText: jsonText)
            } catch {
              continuation.finish(throwing: error)
              return
            }

            // Handle the content.
            do {
              let content = try parseResponse(from: data)
              continuation.yield(content)
            } catch {
              continuation.finish(throwing: error)
              return
            }
          } else {
            extraLines += line
          }
        }

        if extraLines.count > 0 {
          continuation.finish(
            throwing: parseError(httpResponseCode: response.statusCode, responseBody: extraLines)
          )
          return
        }

        continuation.finish(throwing: nil)
      }
    }
  }

  public func encodeToDict<T>(_ value: T) throws -> NSMutableDictionary where T: Encodable {
    let json = try encoder.encode(value)
    return try JSONSerialization.jsonObject(
      with: json, options: [.mutableContainers, .mutableLeaves]
    ) as! NSMutableDictionary
  }

  // MARK: - Private Helpers

  private func urlRequest(params: SendableDict,
                          url: URL,
                          method: String) async throws -> URLRequest {
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = method

    switch authenticationMethod {
    case let .apiKey(key):
      urlRequest.setValue(key, forHTTPHeaderField: "x-goog-api-key")
    case let .accessToken(token):
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

    if params.dictionary.count > 0 {
      urlRequest.httpBody = try JSONSerialization.data(withJSONObject: params.dictionary)
    }

    return urlRequest
  }

  private func createURL(params: NSMutableDictionary,
                         templateUrl: String) throws -> URL {
    var urlString = templateUrl

    var queryItems: [URLQueryItem] = []
    if let queryParams = params["_query"] as? NSMutableDictionary {
      for (key, value) in queryParams {
        queryItems.append(URLQueryItem(name: "\(key)", value: "\(value)"))
      }
    }
    params.removeObject(forKey: "_query")

    if let urlParams = params["_url"] as? NSMutableDictionary {
      for (key, value) in urlParams {
        urlString = urlString.replacingOccurrences(of: "{\(key)}", with: "\(value)")
      }
    }
    params.removeObject(forKey: "_url")

    guard var urlComponents = URLComponents(string: urlString) else {
      throw InternalError.InvalidURL(url: urlString)
    }
    urlComponents.queryItems = urlComponents.queryItems ?? []
    urlComponents.queryItems?.append(contentsOf: queryItems)

    guard let url = urlComponents.url else {
      // if it fails here, it must be from the query items (since that's all we change from above)
      throw InternalError.InvalidURLQueryItems(
        url: urlString,
        queryItems: urlComponents.queryItems ?? []
      )
    }

    return url
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

    if let auth = firebaseInfo.auth, let authToken = try await auth.getToken(forcingRefresh: false)
    {
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
      throw BackendErrors.NonHTTPResponse(response: urlResponse)
    }

    return response
  }

  private func jsonData(jsonText: String) throws -> Data {
    guard let data = jsonText.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Could not parse response as UTF8."
        )
      )
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
      let backendError = rpcError.toBackendError(responseCode: httpResponseCode)

      return backendError
    } catch {
      return BackendErrors.UnrecognizedError(
        responseCode: httpResponseCode, data: responseData, cause: error
      )
    }
  }

  private func parseResponse(from data: Data) throws -> NSMutableDictionary {
    do {
      return try JSONSerialization.jsonObject(
        with: data, options: [.mutableContainers, .mutableLeaves]
      ) as! NSMutableDictionary
    } catch {
      throw BackendErrors.FailedToParseResponse(data: data, cause: error)
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
          let jsonStr = String(bytes: body, encoding: .utf8)
    else { return "" }
    let escapedJSON = jsonStr.replacingOccurrences(of: "'", with: "'\\''")
    returnValue += "-d '\(escapedJSON)'"

    return returnValue
  }

  private func printCURLCommand(from request: URLRequest) {
    guard AILog.additionalLoggingEnabled() else {
      return
    }
    let command = cURLCommand(from: request)
    AILog.debug(
      code: .fallbackValueUsed,
      """
      Creating request with the equivalent cURL command:
      ----- cURL command -----
      \(command)
      ------------------------
      """
    )
  }
  //  #endif // DEBUG
}
