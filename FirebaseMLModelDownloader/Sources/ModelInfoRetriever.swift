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

/// Model info response object.
private struct ModelInfoResponse: Codable {
  var downloadURL: String
  var urlExpiryTime: String
  var size: String
}

/// Properties for server response keys.
private extension ModelInfoResponse {
  enum CodingKeys: String, CodingKey {
    case downloadURL = "downloadUri"
    case urlExpiryTime = "expireTime"
    case size = "sizeBytes"
  }
}

/// Downloading model info will return new model info only if it different from local model info.
enum DownloadModelInfoResult {
  case notModified
  case modelInfo(RemoteModelInfo)
}

/// Model info retriever for a model from local user defaults or server.
class ModelInfoRetriever {
  /// Model name.
  private let modelName: String
  /// URL session for model info request.
  private let session: ModelInfoRetrieverSession
  /// Firebase installations.
  private let installations: Installations
  /// Current Firebase app project ID.
  private let projectID: String
  /// Current Firebase app API key.
  private let apiKey: String
  /// Current Firebase app name.
  private let appName: String
  /// Local model info to validate model freshness.
  private let localModelInfo: LocalModelInfo?

  /// Associate model info retriever with current Firebase app, and model name.
  init(modelName: String,
       projectID: String,
       apiKey: String,
       installations: Installations,
       appName: String,
       localModelInfo: LocalModelInfo? = nil,
       session: ModelInfoRetrieverSession? = nil) {
    self.modelName = modelName
    self.projectID = projectID
    self.apiKey = apiKey
    self.installations = installations
    self.appName = appName
    self.localModelInfo = localModelInfo
    if let urlSession = session {
      self.session = urlSession
    } else {
      self.session = URLSession(configuration: .ephemeral)
    }
  }

  /// Get installations auth token.
  lazy var authTokenProvider = { (completion: @escaping (Result<String, DownloadError>) -> Void) in
    /// Get FIS token.
    self.installations.authToken { tokenResult, error in
      guard let result = tokenResult
      else {
        completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
            .fisToken)))
        return
      }
      completion(.success(result.authToken))
    }
  }

  /// Get model info from server.
  func downloadModelInfo(completion: @escaping (Result<DownloadModelInfoResult, DownloadError>)
    -> Void) {
    authTokenProvider { result in
      switch result {
      /// Successfully received FIS token.
      case let .success(authToken):
        /// Get model info fetch URL with appropriate HTTP headers.
        guard let request = self.getModelInfoFetchURLRequest(token: authToken) else {
          completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
              .invalidModelInfoFetchURL)))
          return
        }
        /// Download model info.
        self.session.getModelInfo(with: request) {
          data, response, error in
          if let downloadError = error {
            completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                .failedModelInfoRetrieval(downloadError.localizedDescription))))
          } else {
            guard let httpResponse = response as? HTTPURLResponse else {
              completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                  .invalidHTTPResponse)))
              return
            }

            switch httpResponse.statusCode {
            case 200:
              guard let modelHash = httpResponse
                .allHeaderFields[ModelInfoRetriever.etagHTTPHeader] as? String else {
                completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                    .missingModelHash)))
                return
              }

              guard let data = data else {
                completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                    .invalidHTTPResponse)))
                return
              }
              do {
                let modelInfo = try self.getRemoteModelInfoFromResponse(data, modelHash: modelHash)
                completion(.success(.modelInfo(modelInfo)))
              } catch {
                completion(
                  .failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                      .invalidmodelInfoJSON(error.localizedDescription)))
                )
              }
            case 304:
              /// For this case to occur, local model info has to already be available on device.
              // TODO: Is this needed? Currently handles the case if model info disappears between request and response
              guard self.localModelInfo != nil else {
                completion(
                  .failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                      .unexpectedModelInfoDeletion))
                )
                return
              }
              completion(.success(.notModified))
            case 404:
              completion(.failure(.notFound))
            // TODO: Handle more http status codes
            default:
              completion(.failure(
                .internalError(
                  description: ModelInfoRetriever
                    .ErrorDescription.serverResponse(httpResponse.statusCode)
                )
              ))
            }
          }
        }
      /// FIS token error.
      case .failure:
        completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
            .fisToken)))
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
    // TODO: Check if bundle ID needs to be part of the request header.
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
    let decoder = JSONDecoder()
    guard let modelInfoJSON = try? decoder.decode(ModelInfoResponse.self, from: data) else {
      throw DownloadError
        .internalError(description: ModelInfoRetriever.ErrorDescription.decodeModelInfoResponse)
    }
    // TODO: Possibly improve handling invalid server responses.
    guard let downloadURL = URL(string: modelInfoJSON.downloadURL) else {
      throw DownloadError
        .internalError(description: ModelInfoRetriever.ErrorDescription
          .invalidModelDownloadURL)
    }
    let modelHash = modelHash
    let size = Int(modelInfoJSON.size) ?? 0
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

/// Possible error messages for model info retrieval.
extension ModelInfoRetriever {
  /// Error descriptions.
  private enum ErrorDescription {
    static let fisToken = "Error retrieving FIS token."
    static let selfDeallocated = "Self deallocated."
    static let missingModelHash = "Model hash missing in server response."
    static let invalidModelInfoFetchURL = "Unable to create URL to fetch model info."
    static let invalidHTTPResponse =
      "Could not get a valid HTTP response from server."
    static let invalidmodelInfoJSON = { (error: String) in
      "Failed to parse model info: \(error)"
    }

    static let failedModelInfoRetrieval = { (error: String) in
      "Failed to retrieve model info: \(error)"
    }

    static let unexpectedModelInfoDeletion =
      "Model info was deleted unexpectedly."
    static let serverResponse = { (errorCode: Int) in
      "Server returned with HTTP error code: \(errorCode)."
    }

    static let decodeModelInfoResponse =
      "Unable to decode model info response from server."
    static let invalidModelDownloadURL =
      "Invalid model download URL from server."
    static let invalidModelDownloadURLExpiryTime =
      "Invalid download URL expiry time from server."
  }
}
