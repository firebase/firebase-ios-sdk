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
class ModelInfoRetriever: NSObject {
  /// Current Firebase app options.
  private var options: FirebaseOptions
  /// Model name.
  private var modelName: String
  /// Firebase installations.
  private var installations: Installations
  /// Current Firebase app name.
  private let appName: String
  /// Local model info to validate model freshness.
  private var localModelInfo: LocalModelInfo?

  /// Associate model info retriever with current Firebase app, and model name.
  init(modelName: String, options: FirebaseOptions, installations: Installations, appName: String,
       localModelInfo: LocalModelInfo? = nil) {
    self.modelName = modelName
    self.options = options
    self.installations = installations
    self.appName = appName
    self.localModelInfo = localModelInfo
  }
}

/// Extension to handle fetching model info from server.
extension ModelInfoRetriever {
  /// HTTP request headers.
  private static let fisTokenHTTPHeader = "x-goog-firebase-installations-auth"
  private static let hashMatchHTTPHeader = "if-none-match"
  private static let bundleIDHTTPHeader = "x-ios-bundle-identifier"

  /// HTTP response headers.
  private static let etagHTTPHeader = "Etag"

  /// Construct model fetch base URL.
  var modelInfoFetchURL: URL {
    let projectID = options.projectID ?? ""
    let apiKey = options.apiKey
    var components = URLComponents()
    components.scheme = "https"
    components.host = "firebaseml.googleapis.com"
    components.path = "/v1beta2/projects/\(projectID)/models/\(modelName):download"
    components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
    // TODO: handle nil
    return components.url!
  }

  /// Construct model fetch URL request.
  private func getModelInfoFetchURLRequest(token: String) -> URLRequest {
    var request = URLRequest(url: modelInfoFetchURL)
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

  /// Get installations auth token.
  private func getAuthToken(completion: @escaping (Result<String, DownloadError>) -> Void) {
    /// Get FIS token.
    installations.authToken { tokenResult, error in
      guard let result = tokenResult
      else {
        completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
            .tokenError)))
        return
      }
      completion(.success(result.authToken))
    }
  }

  /// Get model info from server.
  func downloadModelInfo(completion: @escaping (Result<DownloadModelInfoResult, DownloadError>)
    -> Void) {
    getAuthToken { result in
      switch result {
      /// Successfully received FIS token.
      case let .success(authToken):
        /// Get model info fetch URL with appropriate HTTP headers.
        let request = self.getModelInfoFetchURLRequest(token: authToken)
        let session = URLSession(configuration: .ephemeral)
        /// Download model info.
        let dataTask = session.dataTask(with: request) {
          data, response, error in
          if let downloadError = error {
            completion(.failure(.internalError(description: downloadError.localizedDescription)))
          } else {
            guard let httpResponse = response as? HTTPURLResponse else {
              completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                  .invalidHTTPResponseError)))
              return
            }

            switch httpResponse.statusCode {
            case 200:
              guard let modelHash = httpResponse
                .allHeaderFields[ModelInfoRetriever.etagHTTPHeader] as? String else {
                completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                    .missingModelHashError)))
                return
              }

              guard let data = data else {
                completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                    .invalidHTTPResponseError)))
                return
              }
              do {
                let modelInfo = try self.getRemoteModelInfoFromResponse(data, modelHash: modelHash)
                completion(.success(.modelInfo(modelInfo)))
              } catch {
                completion(
                  .failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                      .modelInfoRetrievalError(error.localizedDescription)))
                )
              }
            case 304:
              /// For this case to occur, local model info has to already be available on device.
              // TODO: Is this needed? Currently handles the case if model info disappears between request and response
              guard self.localModelInfo != nil else {
                completion(
                  .failure(.internalError(description: ModelInfoRetriever.ErrorDescription
                      .unexpectedModelInfoDeletionError))
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
                    .ErrorDescription.serverResponseError(httpResponse.statusCode)
                )
              ))
            }
          }
        }
        dataTask.resume()
      /// FIS token error.
      case .failure:
        completion(.failure(.internalError(description: ModelInfoRetriever.ErrorDescription
            .tokenError)))
        return
      }
    }
  }

  /// Parse date from string - used to get download URL expiry time.
  private static func getDateFromString(_ strDate: String) -> Date? {
    if #available(iOS 11, *) {
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
        .internalError(description: "Unable to decode model info response from server.")
    }
    // TODO: Possibly improve handling invalid server responses.
    guard let downloadURL = URL(string: modelInfoJSON.downloadURL) else {
      throw DownloadError
        .internalError(description: ModelInfoRetriever.ErrorDescription
          .invalidModelDownloadURLError)
    }
    let modelHash = modelHash
    let size = Int(modelInfoJSON.size) ?? 0
    guard let expiryTime = ModelInfoRetriever.getDateFromString(modelInfoJSON.urlExpiryTime) else {
      throw DownloadError
        .internalError(description: ModelInfoRetriever.ErrorDescription
          .invalidModelDownloadURLExpiryTimeError)
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
    static let tokenError = "Error retrieving FIS token."
    static let selfDeallocatedError = "Self deallocated."
    static let missingModelHashError = "Model hash missing in server response."
    static let invalidHTTPResponseError =
      "Could not get a valid HTTP response from server."
    static let modelInfoRetrievalError = { (error: String) in
      "Failed to parse model info: \(error)"
    }

    static let unexpectedModelInfoDeletionError =
      "Model info was deleted unexpectedly."
    static let serverResponseError = { (errorCode: Int) in
      "Server returned with HTTP error code: \(errorCode)."
    }

    static let modelInfoResponseDecodeError =
      "Unable to decode model info response from server."
    static let invalidModelDownloadURLError =
      "Invalid model download URL from server."
    static let invalidModelDownloadURLExpiryTimeError =
      "Invalid download URL expiry time from server."
  }
}
