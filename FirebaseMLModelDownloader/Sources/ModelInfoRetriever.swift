// Copyright 2021 Google LLC
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
import FirebaseCore
import FirebaseInstallations

/// URL Session to use while retrieving model info.
protocol ModelInfoRetrieverSession {
  func getModelInfo(with request: URLRequest,
                    completion: @escaping (Data?, URLResponse?, Error?) -> Void)
}

/// Extension to customize data task requests.
extension URLSession: ModelInfoRetrieverSession {
  func getModelInfo(with request: URLRequest,
                    completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
    let task = dataTask(with: request) { data, response, error in
      completion(data, response, error)
    }
    task.resume()
  }
}

/// Model info result type.
/// Downloading model info will return new model info only if it different from local model info.
enum DownloadModelInfoResult {
  case modelInfo(RemoteModelInfo)
  case notModified
}

/// Model info response.
private struct ModelInfoResponse: Codable {
  let downloadURL: String
  let urlExpiryTime: String
  let size: String
  /// Properties for server response keys.
  enum CodingKeys: String, CodingKey {
    case downloadURL = "downloadUri"
    case urlExpiryTime = "expireTime"
    case size = "sizeBytes"
  }
}

/// Fetch model info for a model from server.
class ModelInfoRetriever {
  /// Model name.
  private let modelName: String
  /// Current Firebase app project ID.
  private let projectID: String
  /// Current Firebase app API key.
  private let apiKey: String
  /// Current Firebase app name.
  private let appName: String
  /// Auth token provider.
  typealias AuthTokenProvider = (_ completion: @escaping (Result<String, DownloadError>) -> Void)
    -> Void
  private let authTokenProvider: AuthTokenProvider
  /// URL session for model info request.
  private let session: ModelInfoRetrieverSession
  /// Local model info to validate model freshness.
  private let localModelInfo: LocalModelInfo?
  /// Telemetry logger.
  private let telemetryLogger: TelemetryLogger?

  /// Associate model info retriever with current Firebase app, and model name.
  init(modelName: String,
       projectID: String,
       apiKey: String,
       appName: String,
       authTokenProvider: @escaping AuthTokenProvider,
       session: ModelInfoRetrieverSession? = nil,
       localModelInfo: LocalModelInfo? = nil,
       telemetryLogger: TelemetryLogger? = nil) {
    self.modelName = modelName
    self.projectID = projectID
    self.apiKey = apiKey
    self.appName = appName
    self.authTokenProvider = authTokenProvider
    self.session = session ?? URLSession(configuration: .ephemeral)
    self.localModelInfo = localModelInfo
    self.telemetryLogger = telemetryLogger
  }

  /// Convenience init to use FirebaseInstallations as auth token provider.
  convenience init(modelName: String,
                   projectID: String,
                   apiKey: String,
                   appName: String,
                   installations: Installations,
                   session: ModelInfoRetrieverSession? = nil,
                   localModelInfo: LocalModelInfo? = nil,
                   telemetryLogger: TelemetryLogger? = nil) {
    self.init(modelName: modelName,
              projectID: projectID,
              apiKey: apiKey,
              appName: appName,
              authTokenProvider: ModelInfoRetriever.authTokenProvider(installation: installations),
              session: session,
              localModelInfo: localModelInfo,
              telemetryLogger: telemetryLogger)
  }

  /// Auth token provider to validate credentials.
  private static func authTokenProvider(installation: Installations) -> AuthTokenProvider {
    return { completion in
      installation.authToken { tokenResult, error in
        guard let result = tokenResult
        else {
          completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
              .authTokenError)))
          return
        }
        completion(.success(result.authToken))
      }
    }
  }

  /// Get model info from server.
  func downloadModelInfo(completion: @escaping (Result<DownloadModelInfoResult, DownloadError>)
    -> Void) {
    authTokenProvider { result in
      switch result {
      /// Successfully received FIS token.
      case let .success(authToken):
        DeviceLogger.logEvent(level: .debug,
                              message: ModelInfoRetriever.DebugDescription
                                .receivedAuthToken,
                              messageCode: .validAuthToken)
        /// Get model info fetch URL with appropriate HTTP headers.
        guard let request = self.getModelInfoFetchURLRequest(token: authToken) else {
          DeviceLogger.logEvent(level: .debug,
                                message: ModelInfoRetriever.ErrorDescription
                                  .invalidModelInfoFetchURL,
                                messageCode: .invalidModelInfoFetchURL)
          self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                           status: .modelInfoRetrievalFailed,
                                                           errorCode: .connectionFailed)
          completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
              .invalidModelInfoFetchURL)))
          return
        }
        /// Download model info.
        self.session.getModelInfo(with: request) {
          data, response, error in
          if let downloadError = error {
            let description = ModelInfoRetriever.ErrorDescription
              .failedModelInfoRetrieval(downloadError.localizedDescription)
            DeviceLogger.logEvent(level: .debug,
                                  message: description,
                                  messageCode: .modelInfoRetrievalError)
            self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                             status: .modelInfoRetrievalFailed,
                                                             errorCode: .connectionFailed)
            completion(.failure(.internalError(description: description)))
          } else {
            guard let httpResponse = response as? HTTPURLResponse else {
              DeviceLogger.logEvent(level: .debug,
                                    message: ModelInfoRetriever.ErrorDescription
                                      .invalidHTTPResponse,
                                    messageCode: .invalidHTTPResponse)
              self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                               status: .modelInfoRetrievalFailed,
                                                               errorCode: .connectionFailed)
              completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                  .invalidHTTPResponse)))
              return
            }
            DeviceLogger.logEvent(level: .debug,
                                  message: ModelInfoRetriever.DebugDescription
                                    .receivedServerResponse,
                                  messageCode: .validHTTPResponse)
            switch httpResponse.statusCode {
            case 200:
              guard let modelHash = httpResponse
                .allHeaderFields[ModelInfoRetriever.etagHTTPHeader] as? String else {
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelInfoRetriever.ErrorDescription.missingModelHash,
                                      messageCode: .missingModelHash)
                self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                                 status: .modelInfoRetrievalFailed,
                                                                 errorCode: .noHash)
                completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                    .missingModelHash)))
                return
              }
              guard let data = data else {
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelInfoRetriever.ErrorDescription
                                        .invalidHTTPResponse,
                                      messageCode: .invalidHTTPResponse)
                completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                    .invalidHTTPResponse)))
                return
              }
              do {
                /// Parse model info from HTTP response.
                let modelInfo = try self.getRemoteModelInfoFromResponse(data, modelHash: modelHash)
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelInfoRetriever.DebugDescription
                                        .modelInfoDownloaded,
                                      messageCode: .modelInfoDownloaded)
                self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                                 status: .modelInfoRetrievalSucceeded,
                                                                 errorCode: .noError)
                completion(.success(.modelInfo(modelInfo)))
              } catch {
                let description = ModelInfoRetriever.ErrorDescription
                  .invalidModelInfoJSON(error.localizedDescription)
                DeviceLogger.logEvent(level: .debug,
                                      message: description,
                                      messageCode: .invalidModelInfoJSON)
                completion(
                  .failure(.internalError(description: description))
                )
              }
            case 304:
              /// For this case to occur, local model info has to already be available on device.
              guard let localInfo = self.localModelInfo else {
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelInfoRetriever.ErrorDescription
                                        .unexpectedModelInfoDeletion,
                                      messageCode: .modelInfoDeleted)
                completion(
                  .failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                      .unexpectedModelInfoDeletion))
                )
                return
              }
              guard let modelHash = httpResponse
                .allHeaderFields[ModelInfoRetriever.etagHTTPHeader] as? String else {
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelInfoRetriever.ErrorDescription
                                        .missingModelHash,
                                      messageCode: .noModelHash)
                self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                                 status: .modelInfoRetrievalFailed,
                                                                 errorCode: .noHash)
                completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                    .missingModelHash)))
                return
              }
              /// Ensure that there is local model info on device with matching hash.
              guard modelHash == localInfo.modelHash else {
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelInfoRetriever.ErrorDescription
                                        .modelHashMismatch,
                                      messageCode: .modelHashMismatchError)
                self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                                 status: .modelInfoRetrievalFailed,
                                                                 errorCode: .hashMismatch)
                completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                    .modelHashMismatch)))
                return
              }
              DeviceLogger.logEvent(level: .debug,
                                    message: ModelInfoRetriever.DebugDescription
                                      .modelInfoUnmodified,
                                    messageCode: .modelInfoUnmodified)
              self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                               status: .modelInfoRetrievalSucceeded,
                                                               errorCode: .noError)
              completion(.success(.notModified))
            case 400:
              if let data = data,
                let responseJSON = try? JSONSerialization
                .jsonObject(with: data, options: []) as? [String: Any],
                let error = responseJSON["error"] as? [String: Any],
                let errorMessage = error["message"] as? String {
                DeviceLogger.logEvent(level: .debug,
                                      message: errorMessage,
                                      messageCode: .invalidArgument)
              } else {
                let description = ModelInfoRetriever.ErrorDescription
                  .invalidArgument(self.modelName)
                DeviceLogger.logEvent(level: .debug,
                                      message: description,
                                      messageCode: .invalidArgument)
              }
              self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                               status: .modelInfoRetrievalFailed,
                                                               errorCode: .httpError(code: httpResponse
                                                                 .statusCode))
              completion(.failure(.invalidArgument))
            case 401, 403:
              /// Error could be due to FirebaseML API not enabled for project, or invalid permissions.
              if let data = data,
                let responseJSON = try? JSONSerialization
                .jsonObject(with: data, options: []) as? [String: Any],
                let error = responseJSON["error"] as? [String: Any],
                let errorMessage = error["message"] as? String {
                DeviceLogger.logEvent(level: .debug,
                                      message: errorMessage,
                                      messageCode: .permissionDenied)
              } else {
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelInfoRetriever.ErrorDescription.permissionDenied,
                                      messageCode: .permissionDenied)
              }
              self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                               status: .modelInfoRetrievalFailed,
                                                               errorCode: .httpError(code: httpResponse
                                                                 .statusCode))
              completion(.failure(.permissionDenied))
            case 404:
              if let data = data,
                let responseJSON = try? JSONSerialization
                .jsonObject(with: data, options: []) as? [String: Any],
                let error = responseJSON["error"] as? [String: Any],
                let errorMessage = error["message"] as? String {
                DeviceLogger.logEvent(level: .debug,
                                      message: errorMessage,
                                      messageCode: .modelNotFound)
              } else {
                let description = ModelInfoRetriever.ErrorDescription.modelNotFound(self.modelName)
                DeviceLogger.logEvent(level: .debug,
                                      message: description,
                                      messageCode: .modelNotFound)
              }
              self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                               status: .modelInfoRetrievalFailed,
                                                               errorCode: .httpError(code: httpResponse
                                                                 .statusCode))
              completion(.failure(.notFound))
            case 429:
              if let data = data,
                let responseJSON = try? JSONSerialization
                .jsonObject(with: data, options: []) as? [String: Any],
                let error = responseJSON["error"] as? [String: Any],
                let errorMessage = error["message"] as? String {
                DeviceLogger.logEvent(level: .debug,
                                      message: errorMessage,
                                      messageCode: .resourceExhausted)
              } else {
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelInfoRetriever.ErrorDescription
                                        .resourceExhausted,
                                      messageCode: .resourceExhausted)
              }
              self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                               status: .modelInfoRetrievalFailed,
                                                               errorCode: .httpError(code: httpResponse
                                                                 .statusCode))
              completion(.failure(.resourceExhausted))
            default:
              var description: String
              if let data = data,
                let responseJSON = try? JSONSerialization
                .jsonObject(with: data, options: []) as? [String: Any],
                let error = responseJSON["error"] as? [String: Any],
                let errorMessage = error["message"] as? String {
                description = errorMessage
              } else {
                description = ModelInfoRetriever.ErrorDescription
                  .modelInfoRetrievalFailed(httpResponse.statusCode)
              }
              DeviceLogger.logEvent(level: .debug,
                                    message: description,
                                    messageCode: .modelInfoRetrievalError)
              self.telemetryLogger?.logModelInfoRetrievalEvent(eventName: .modelDownload,
                                                               status: .modelInfoRetrievalFailed,
                                                               errorCode: .httpError(code: httpResponse
                                                                 .statusCode))
              completion(.failure(.internalError(description: description)))
            }
          }
        }
      /// Error retrieving auth token.
      case .failure:
        DeviceLogger.logEvent(level: .debug,
                              message: ModelInfoRetriever.ErrorDescription
                                .authTokenError,
                              messageCode: .authTokenError)
        completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
            .authTokenError)))
        return
      }
    }
  }
}

/// Extension with helper methods to handle fetching model info from server.
extension ModelInfoRetriever {
  /// HTTP request headers.
  private static let fisTokenHTTPHeader = "x-goog-firebase-installations-auth"
  private static let hashMatchHTTPHeader = "if-none-match"
  private static let bundleIDHTTPHeader = "x-ios-bundle-identifier"
  /// HTTP response headers.
  private static let etagHTTPHeader = "Etag"

  /// Construct model fetch base URL.
  var modelInfoFetchURL: URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "firebaseml.googleapis.com"
    components.path = "/v1beta2/projects/\(projectID)/models/\(modelName):download"
    components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
    return components.url
  }

  /// Construct model fetch URL request.
  func getModelInfoFetchURLRequest(token: String) -> URLRequest? {
    guard let fetchURL = modelInfoFetchURL else { return nil }
    var request = URLRequest(url: fetchURL)
    request.httpMethod = "GET"
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    request.setValue(bundleID, forHTTPHeaderField: ModelInfoRetriever.bundleIDHTTPHeader)
    request.setValue(token, forHTTPHeaderField: ModelInfoRetriever.fisTokenHTTPHeader)
    /// Get model hash if local model info is available on device.
    if let modelInfo = localModelInfo {
      request.setValue(
        modelInfo.modelHash,
        forHTTPHeaderField: ModelInfoRetriever.hashMatchHTTPHeader
      )
    }
    return request
  }

  /// Parse date from string - used to get download URL expiry time.
  private static func getDateFromString(_ strDate: String) -> Date? {
    if #available(iOS 11, macOS 10.13, macCatalyst 13.0, tvOS 11.0, watchOS 4.0, *) {
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
      dateFormatter.formatOptions = [.withFractionalSeconds]
      return dateFormatter.date(from: strDate)
    } else {
      let dateFormatter = DateFormatter()
      dateFormatter.locale = Locale(identifier: "en-US_POSIX")
      dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
      dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
      return dateFormatter.date(from: strDate)
    }
  }

  /// Return model info created from server response.
  private func getRemoteModelInfoFromResponse(_ data: Data,
                                              modelHash: String) throws -> RemoteModelInfo {
    guard let modelInfoJSON = try? JSONDecoder().decode(ModelInfoResponse.self, from: data) else {
      throw DownloadError
        .internalError(description: ModelInfoRetriever.ErrorDescription.decodeModelInfoResponse)
    }
    guard let downloadURL = URL(string: modelInfoJSON.downloadURL) else {
      throw DownloadError
        .internalError(description: ModelInfoRetriever.ErrorDescription
          .invalidModelDownloadURL)
    }
    guard let size = Int(modelInfoJSON.size) else {
      throw DownloadError
        .internalError(description: ModelInfoRetriever.ErrorDescription
          .invalidModelSize)
    }
    guard let expiryTime = ModelInfoRetriever.getDateFromString(modelInfoJSON.urlExpiryTime) else {
      throw DownloadError
        .internalError(description: ModelInfoRetriever.ErrorDescription
          .invalidModelDownloadURLExpiryTime)
    }
    return RemoteModelInfo(
      name: modelName,
      downloadURL: downloadURL,
      modelHash: modelHash,
      size: size,
      urlExpiryTime: expiryTime
    )
  }
}

/// Model info retrieval error codes.
enum ModelInfoErrorCode {
  case noError
  case noHash
  case httpError(code: Int)
  case connectionFailed
  case hashMismatch
}

/// Possible error messages for model info retrieval.
extension ModelInfoRetriever {
  /// Debug descriptions.
  private enum DebugDescription {
    static let receivedAuthToken = "Generated valid auth token."
    static let receivedServerResponse = "Received a valid response from model info server."
    static let modelInfoDownloaded = "Successfully downloaded model info."
    static let modelInfoUnmodified = "Local model info matches the latest on server."
  }

  /// Error descriptions.
  private enum ErrorDescription {
    static let authTokenError = "Error retrieving auth token."
    static let invalidModelInfoFetchURL = "Unable to create URL to fetch model info."
    static let invalidHTTPResponse =
      "Could not get a valid HTTP response for model info retrieval."
    static let serverResponseError = { (errorCode: Int) in
      "Server returned with HTTP error code: \(errorCode)."
    }

    static let missingModelHash = "Model hash missing in model info server response."
    static let modelHashMismatch = "Unexpected model hash value."
    static let unexpectedModelInfoDeletion = "Model info was deleted unexpectedly."
    static let modelNotFound = { (name: String) in
      "No model found with name: \(name)"
    }

    static let invalidArgument = { (name: String) in
      "Invalid argument for model name: \(name)"
    }

    static let permissionDenied = "Invalid or missing permissions to retrieve model info."
    static let resourceExhausted = "Resource exhausted due to too many requests."
    static let modelInfoRetrievalFailed = { (code: Int) in
      "Model info retrieval failed with HTTP error code: \(code)"
    }

    static let decodeModelInfoResponse =
      "Unable to decode model info response from server."
    static let invalidModelDownloadURL =
      "Invalid model download URL from server."
    static let invalidModelSize = "Invalid model size from server."
    static let invalidModelDownloadURLExpiryTime =
      "Invalid download URL expiry time from server."
    static let invalidModelInfoJSON = { (error: String) in
      "Failed to parse model info: \(error)"
    }

    static let failedModelInfoRetrieval = { (error: String) in
      "Failed to retrieve model info: \(error)"
    }
  }
}
