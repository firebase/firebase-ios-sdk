// Copyright 2023 Google LLC
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

import FirebaseCore
import FirebaseInstallations
import Foundation
import UIKit

// Avoids exposing internal APIs to Swift users
@_implementationOnly import FirebaseCoreInternal

enum Strings {
  static let errorDomain = "com.firebase.appdistribution.api"
  static let errorDetailsKey = "details"
  static let httpGet = "GET"
  static let httpPost = "POST"
  static let releaseEndpointUrlTemplate =
    "https://firebaseapptesters.googleapis.com/v1alpha/devices/-/testerApps/%@/installations/%@/releases"
  static let findReleaseEndpointUrlTemplate =
    "https://firebaseapptesters.googleapis.com/v1alpha/projects/%@/installations/%@/releases:find?compositeBinaryId.displayVersion=%@&compositeBinaryId.buildVersion=%@&compositeBinaryId.codeHash=%@"
  static let createFeedbackEndpointUrlTemplate =
    "https://firebaseapptesters.googleapis.com/v1alpha/%@/feedbackReports"
  static let uploadImageEndpointUrlTemplate =
    "https://firebaseapptesters.googleapis.com/upload/v1alpha/%@:uploadArtifact"
  static let commitFeedbackEndpointUrlTemplate =
    "https://firebaseapptesters.googleapis.com/v1alpha/%@:commit"
  static let installationsAuthHeader = "X-Goog-Firebase-Installations-Auth"
  static let apiHeaderKey = "X-Goog-Api-Key"
  static let apiBundleKey = "X-Ios-Bundle-Identifier"
  static let responseReleaseKey = "releases"
  static let compositeBinaryIdQueryParamName = "compositeBinaryId"
  static let uploadArtifactTypeQueryParamName = "type"
  static let uploadArtifactScreenshotType = "SCREENSHOT"
  static let GoogleUploadProtocolHeader = "X-Goog-Upload-Protocol"
  static let GoogleUploadProtocolRaw = "raw"
  static let GoogleUploadFileNameHeader = "X-Goog-Upload-File-Name"
  static let GoogleUploadFileName = "screenshot.png"
  static let contentTypeHeader = "Content-Type"
  static let jsonContentType = "application/json"
}

enum AppDistributionApiError: NSInteger {
  case ApiErrorTimeout = 0
  case ApiTokenGenerationFailure = 1
  case ApiInstallationIdentifierError = 2
  case ApiErrorUnauthenticated = 3
  case ApiErrorUnauthorized = 4
  case ApiErrorNotFound = 5
  case ApiErrorUnknownFailure = 6
  case ApiErrorParseFailure = 7
}

struct CompositeBinaryId: Codable {
  var displayVersion: String
  var buildVersion: String
  var codeHash: String
}

struct FindReleaseResponse: Codable {
  var release: String
}

struct FeedbackReport: Codable {
  var name: String?
  var text: String?
}

@objc(FIRFADApiServiceSwift) open class ApiService: NSObject {
  @objc(generateAuthTokenWithCompletion:) public static func generateAuthToken(completion: @escaping (_ identifier: String?,
                                                                                                      _ authTokenResult: InstallationsAuthTokenResult?,
                                                                                                      _ error: Error?)
      -> Void) {
    generateAuthToken(installations: Installations.installations(), completion: completion)
  }

  static func generateAuthToken(installations: InstallationsProtocol,
                                completion: @escaping (_ identifier: String?,
                                                       _ authTokenResult: InstallationsAuthTokenResult?,
                                                       _ error: Error?)
                                  -> Void) {
    installations.authToken(completion: { authTokenResult, error in
      var fadError: Error? = error
      if self.handleError(
        error: &fadError,
        description: "Failed to generate Firebase installation auth token",
        code: .ApiTokenGenerationFailure
      ) {
        Logger
          .logError(String(format: "Error getting auth token. Error: %@",
                           error?.localizedDescription ?? ""))
        completion(nil, nil, fadError)
        return
      }

      installations.installationID(completion: { identifier, error in
        var fadError: Error? = error
        if self.handleError(
          error: &fadError,
          description: "Failed to generate Firebase installation id",
          code: .ApiInstallationIdentifierError
        ) {
          Logger
            .logError(String(format: "Error getting installation ID. Error: %@",
                             error?.localizedDescription ?? ""))
          completion(nil, nil, fadError)
          return
        }

        completion(identifier, authTokenResult, nil)
      })
    })
  }

  @objc(fetchReleasesWithCompletion:) public static func fetchReleases(completion: @escaping (_ releases: [
      Any,
    ]?,
    _ error: Error?)
      -> Void) {
    guard let app = FirebaseApp.app() else {
      return
    }
    fetchReleases(
      app: app,
      installations: Installations.installations(),
      urlSession: URLSession.shared,
      completion: completion
    )
  }

  static func fetchReleases(app: FirebaseApp, installations: InstallationsProtocol,
                            urlSession: URLSession, completion: @escaping (_ releases: [Any]?,
                                                                           _ error: Error?)
                              -> Void) {
    Logger.logInfo(String(
      format: "Requesting release for app id - %@",
      app.options.googleAppID
    ))
    generateAuthToken(installations: installations) { identifier, authTokenResult, error in
      let urlString = String(
        format: Strings.releaseEndpointUrlTemplate,
        app.options.googleAppID,
        identifier!
      )
      let request = self.createHttpRequest(
        app: app,
        method: Strings.httpGet,
        url: urlString,
        authTokenResult: authTokenResult!
      )
      Logger.logInfo(String(
        format: "Url: %@ Auth token: %@ Api Key: %@",
        urlString,
        authTokenResult?.authToken ?? "",
        app.options.apiKey ?? ""
      ))

      let listReleaseDataTask = urlSession
        .dataTask(with: request as URLRequest) { data, response, error in
          var fadError = error
          let releasesResponse = self.handleResponse(data: data,
                                                     response: response,
                                                     error: &fadError,
                                                     returnType: [String: [Any]].self)
          DispatchQueue.main.async {
            completion(releasesResponse?[Strings.responseReleaseKey], fadError)
          }
        }

      listReleaseDataTask.resume()
    }
  }

  @objc(findReleaseWithDisplayVersion:buildVersion:codeHash:completion:)
  public static func findRelease(displayVersion: String, buildVersion: String, codeHash: String,
                                 completion: @escaping (_ releaseName: String?, _ error: Error?)
                                   -> Void) {
    findRelease(
      app: FirebaseApp.app()!,
      installations: Installations.installations(),
      urlSession: URLSession.shared,
      displayVersion: displayVersion,
      buildVersion: buildVersion,
      codeHash: codeHash,
      completion: completion
    )
  }

  private static func buildFindReleaseUrl(projectNumber: String, identifier: String,
                                          displayVersion: String, buildVersion: String,
                                          codeHash: String) -> String {
    return String(
      format: Strings.findReleaseEndpointUrlTemplate,
      projectNumber,
      identifier,
      displayVersion,
      buildVersion,
      codeHash
    )
  }

  static func findRelease(app: FirebaseApp, installations: InstallationsProtocol,
                          urlSession: URLSession, displayVersion: String,
                          buildVersion: String, codeHash: String,
                          completion: @escaping (_ releaseName: String?, _ error: Error?)
                            -> Void) {
    generateAuthToken(installations: installations) { identifier, authTokenResult, error in
      // TODO(tundeagboola) The backend may not accept project ID here in which case
      // we'll have to figure out a way to get the project number
      let urlString = buildFindReleaseUrl(
        projectNumber: app.options.gcmSenderID,
        identifier: identifier!,
        displayVersion: displayVersion,
        buildVersion: buildVersion,
        codeHash: codeHash
      )
      let request = self.createHttpRequest(
        app: app,
        method: Strings.httpGet,
        url: URL(string: urlString),
        authTokenResult: authTokenResult!
      )
      let findReleaseDataTask = urlSession
        .dataTask(with: request as URLRequest) { data, response, error in
          var fadError = error
          let findReleaseResponse = self.handleCodableResponse(
            data: data,
            response: response,
            error: &fadError,
            returnType: FindReleaseResponse.self
          )
          DispatchQueue.main.async {
            completion(findReleaseResponse?.release, fadError)
          }
        }

      findReleaseDataTask.resume()
    }
  }

  @objc(createFeedbackWithReleaseName:feedbackText:completion:)
  public static func createFeedback(releaseName: String,
                                    feedbackText: String,
                                    completion: @escaping (_ feedbackName: String?, _ error: Error?)
                                      -> Void) {
    createFeedback(
      app: FirebaseApp.app()!,
      installations: Installations.installations(),
      urlSession: URLSession.shared,
      releaseName: releaseName,
      feedbackText: feedbackText,
      completion: completion
    )
  }

  static func createFeedback(app: FirebaseApp, installations: InstallationsProtocol,
                             urlSession: URLSession, releaseName: String,
                             feedbackText: String,
                             completion: @escaping (_ feedbackName: String?, _ error: Error?)
                               -> Void) {
    generateAuthToken(installations: installations) { identifier, authTokenResult, error in
      guard let authTokenResult = authTokenResult else {
        completion(nil, error)
        return
      }
      let urlString = String(
        format: Strings.createFeedbackEndpointUrlTemplate,
        releaseName
      )
      let request = createHttpRequest(
        app: app,
        method: Strings.httpPost,
        url: urlString,
        authTokenResult: authTokenResult
      )
      request.setValue(Strings.jsonContentType, forHTTPHeaderField: Strings.contentTypeHeader)
      let feedbackReport = FeedbackReport(text: feedbackText)
      request.httpBody = try? JSONEncoder().encode(feedbackReport)
      let createFeedbackTask = urlSession
        .dataTask(with: request as URLRequest) { data, response, error in
          var fadError = error
          let feedback = self.handleCodableResponse(
            data: data,
            response: response,
            error: &fadError,
            returnType: FeedbackReport.self
          )
          DispatchQueue.main.async {
            completion(feedback?.name, fadError)
          }
        }

      createFeedbackTask.resume()
    }
  }

  @objc(uploadImageWithFeedbackName:image:completion:)
  public static func uploadImage(feedbackName: String,
                                 image: UIImage,
                                 completion: @escaping (_ error: Error?)
                                   -> Void) {
    uploadImage(
      app: FirebaseApp.app()!,
      installations: Installations.installations(),
      urlSession: URLSession.shared,
      feedbackName: feedbackName,
      image: image,
      completion: completion
    )
  }

  static func uploadImage(app: FirebaseApp, installations: InstallationsProtocol,
                          urlSession: URLSession, feedbackName: String,
                          image: UIImage,
                          completion: @escaping (_ error: Error?)
                            -> Void) {
    generateAuthToken(installations: installations) { identifier, authTokenResult, error in
      guard let authTokenResult = authTokenResult else {
        completion(error)
        return
      }
      let urlString = String(
        format: Strings.uploadImageEndpointUrlTemplate,
        feedbackName
      )
      guard var urlComponents = URLComponents(string: urlString) else {
        // TODO(tundeagboola) We should throw exceptions here instead of piping errors
        Logger.logError("Unable to build URL for uploadArtifact request")
        return
      }
      urlComponents.queryItems = [URLQueryItem(
        name: Strings.uploadArtifactTypeQueryParamName,
        value: Strings.uploadArtifactScreenshotType
      )]
      guard let url = urlComponents.url else {
        // TODO(tundeagboola) We should throw exceptions here instead of piping errors
        Logger.logError("Unable to build URL for uploadArtifact request")
        return
      }
      let request = createHttpRequest(
        app: app,
        method: Strings.httpPost,
        url: url,
        authTokenResult: authTokenResult
      )
      request.setValue(
        Strings.GoogleUploadProtocolHeader,
        forHTTPHeaderField: Strings.GoogleUploadProtocolRaw
      )
      request.setValue(
        Strings.GoogleUploadFileNameHeader,
        forHTTPHeaderField: Strings.GoogleUploadFileName
      )
      // TODO(tundeagboola) Add support for jpegs
      request.httpBody = image.pngData()
      let uploadImageTask = urlSession
        .dataTask(with: request as URLRequest) { data, response, error in
          var fadError = error
          self.handleError(httpResponse: response as? HTTPURLResponse, error: &fadError)
          DispatchQueue.main.async {
            completion(fadError)
          }
        }

      uploadImageTask.resume()
    }
  }

  @objc(commitFeedbackWithFeedbackName:completion:)
  public static func commitFeedback(feedbackName: String,
                                    completion: @escaping (_ error: Error?)
                                      -> Void) {
    commitFeedback(
      app: FirebaseApp.app()!,
      installations: Installations.installations(),
      urlSession: URLSession.shared,
      feedbackName: feedbackName,
      completion: completion
    )
  }

  static func commitFeedback(app: FirebaseApp, installations: InstallationsProtocol,
                             urlSession: URLSession,
                             feedbackName: String,
                             completion: @escaping (_ error: Error?)
                               -> Void) {
    generateAuthToken(installations: installations) { identifier, authTokenResult, error in
      guard let authTokenResult = authTokenResult else {
        completion(error)
        return
      }
      let urlString = String(
        format: Strings.commitFeedbackEndpointUrlTemplate,
        feedbackName
      )
      let request = createHttpRequest(
        app: app,
        method: Strings.httpPost,
        url: urlString,
        authTokenResult: authTokenResult
      )
      let commitFeedbackTask = urlSession
        .dataTask(with: request as URLRequest) { data, response, error in
          var fadError = error
          self.handleError(httpResponse: response as? HTTPURLResponse, error: &fadError)
          DispatchQueue.main.async {
            completion(fadError)
          }
        }

      commitFeedbackTask.resume()
    }
  }

  @discardableResult
  static func handleError(httpResponse: HTTPURLResponse?, error: inout Error?) -> Bool {
    // TODO(tundeagboola) We should be throwing errors instead of piping the error object through
    if error != nil || httpResponse == nil {
      return handleError(
        error: &error,
        description: "Unknown http error occurred",
        code: .ApiErrorUnknownFailure
      )
    } else if httpResponse?.statusCode != 200 {
      error = createError(statusCode: httpResponse!.statusCode)
      return true
    }

    return false
  }

  @discardableResult
  static func handleError(error: inout Error?, description: String?,
                          code: AppDistributionApiError) -> Bool {
    // TODO(tundeagboola) We should be throwing errors instead of piping the error object through
    if error != nil {
      error = createError(description: description!, code: code)
      return true
    }
    return false
  }

  static func createError(description: String, code: AppDistributionApiError) -> Error {
    let userInfo = [NSLocalizedDescriptionKey: description]
    return NSError(domain: Strings.errorDomain, code: code.rawValue, userInfo: userInfo)
  }

  static func createError(statusCode: NSInteger) -> Error {
    switch statusCode {
    case 401:
      return createError(description: "Tester not authenticated", code: .ApiErrorUnauthenticated)
    case 403, 400:
      return createError(description: "Tester not authorized", code: .ApiErrorUnauthorized)
    case 404:
      return createError(description: "Tester or releases not found", code: .ApiErrorUnauthorized)
    case 408, 504:
      return createError(description: "Request timeout", code: .ApiErrorTimeout)
    default:
      print("Unknown status code")
    }

    let description = String(format: "Unknown status code: %ld", statusCode)
    return createError(description: description, code: .ApiErrorUnknownFailure)
  }

  static func createHttpRequest(app: FirebaseApp, method: String, url: String,
                                authTokenResult: InstallationsAuthTokenResult)
    -> NSMutableURLRequest {
    return createHttpRequest(
      app: app,
      method: method,
      url: URL(string: url),
      authTokenResult: authTokenResult
    )
  }

  static func createHttpRequest(app: FirebaseApp, method: String, url: URL?,
                                authTokenResult: InstallationsAuthTokenResult)
    -> NSMutableURLRequest {
    let request = NSMutableURLRequest()
    request.url = url
    request.httpMethod = method
    request.setValue(authTokenResult.authToken, forHTTPHeaderField: Strings.installationsAuthHeader)
    request.setValue(
      app.options.apiKey,
      forHTTPHeaderField: Strings.apiHeaderKey
    )
    request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: Strings.apiBundleKey)
    return request
  }

  static func validateResponse(response: URLResponse?, error: inout Error?) -> Bool {
    guard let response = response else {
      handleError(
        error: &error,
        description: "URLResponse is nil",
        code: .ApiErrorUnknownFailure
      )
      return false
    }

    let httpResponse = response as! HTTPURLResponse
    Logger
      .logInfo(String(format: "HTTPResponse status code %ld, response %@", httpResponse.statusCode,
                      httpResponse))
    if handleError(httpResponse: httpResponse, error: &error) {
      Logger
        .logError(String(format: "App tester API service error: %@",
                         error?.localizedDescription ?? ""))
      return false
    }

    return true
  }

  static func handleCodableResponse<T: Codable>(data: Data?, response: URLResponse?,
                                                error: inout Error?,
                                                returnType: T.Type) -> T? {
    if !validateResponse(response: response, error: &error) {
      return nil
    }

    guard let data = data else {
      return nil
    }

    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch let thrownError {
      handleApiParserError(thrownError, &error)
      return nil
    }
  }

  static func handleResponse<T>(data: Data?, response: URLResponse?,
                                error: inout Error?, returnType: T.Type) -> T? {
    if !validateResponse(response: response, error: &error) {
      return nil
    }

    guard let data = data else {
      return nil
    }

    do {
      return try JSONSerialization.jsonObject(
        with: data,
        options: JSONSerialization.ReadingOptions(rawValue: 0)
      ) as? T
    } catch let thrownError {
      handleApiParserError(thrownError, &error)
      return nil
    }
  }

  static func handleApiParserError(_ thrownError: Error, _ error: inout Error?) {
    let description: String = (thrownError as NSError)
      .userInfo[NSLocalizedDescriptionKey] as? String ?? "Failed to parse response"
    error = thrownError
    handleError(error: &error, description: description, code: .ApiErrorParseFailure)
    Logger.logError("Tester API - Error deserializing json response")
  }
}
