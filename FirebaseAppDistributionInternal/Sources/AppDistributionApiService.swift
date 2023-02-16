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

import Foundation
import FirebaseInstallations
import FirebaseCore

// Avoids exposing internal APIs to Swift users
@_implementationOnly import FirebaseCoreInternal


public typealias AppDistributionFetchReleasesCompletion = (_ releases: Array<Any>?, _ error: Error?) -> Void
public typealias AppDistributionGenerateAuthTokenCompletion = (_ identifier: String?, _ authTokenResult: InstallationsAuthTokenResult?, _ error: Error?) -> Void

enum Strings {
  static let errorDomain = "com.firebase.appdistribution.api"
  static let errorDetailsKey = "details"
  static let httpGet = "GET"
  static let releaseEndpointUrlTemplate = "https://firebaseapptesters.googleapis.com/v1alpha/devices/-/testerApps/%@/installations/%@/releases"
  static let installationsAuthHeader = "X-Goog-Firebase-Installations-Auth"
  static let apiHeaderKey = "X-Goog-Api-Key"
  static let apiBundleKey = "X-Ios-Bundle-Identifier"
  static let responseReleaseKey = "releases"
}

@objc(FIRFADApiError)
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


@objc(FIRFADSwiftApiService) open class AppDistributionApiService: NSObject {
  
  @objc(generateAuthTokenWithCompletion:) public static func generateAuthToken(completion: @escaping AppDistributionGenerateAuthTokenCompletion) {
    let installations = Installations.installations()
    
    installations.authToken(completion: { (authTokenResult, error) -> Void in
      if error != nil {
        Logger.logError(String(format: "Error getting auth token. Error: %@", error?.localizedDescription ?? ""))
        completion(nil, nil, error)
        return
      }
      
      installations.installationID(completion: { (identifier, error) -> Void in
        if error != nil {
          Logger.logError(String(format: "Error getting installation ID. Error: %@", error?.localizedDescription ?? ""))
          completion(nil, nil, error)
          return
        }
        
        completion(identifier, authTokenResult, nil)
      })
    })
  }
 
  @objc(fetchReleasesWithCompletion:) public static func fetchReleases(completion: @escaping AppDistributionFetchReleasesCompletion) {
    Logger.logInfo(String(format: "Requesting release for app id - %@", FirebaseApp.app()?.options.googleAppID ?? "unknown"))
    self.generateAuthToken() { (identifier, authTokenResult, error) in
      let urlString = String(format: Strings.releaseEndpointUrlTemplate, FirebaseApp.app()!.options.googleAppID, identifier!)
      let request = self.createHttpRequest(method: Strings.httpGet, url: urlString, authTokenResult: authTokenResult!)
      Logger.logInfo(String(format: "Url: %@ Auth token: %@ Api Key: %@", urlString, authTokenResult?.authToken ?? "", FirebaseApp.app()?.options.apiKey ?? "unknown"))
      
      let listReleaseDataTask = URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) in
        
        let releases = self.handleReleaseResponse(data: data! as NSData, response: response!, error: error)
        let statusCode = (response as! HTTPURLResponse).statusCode
        DispatchQueue.main.async {
          completion(releases, error)
        }
      }
      
      listReleaseDataTask.resume()
    }
  }
  
  static func handleError(error: inout Error?, description: String?, code: AppDistributionApiError) -> Bool {
    if error != nil {
      error = self.createError(description: description!, code: code)
      return true
    }
    
    return false
  }
  
  static func createError(description: String, code: AppDistributionApiError) -> Error {
    let userInfo = [NSLocalizedDescriptionKey: description]
    return NSError.init(domain: Strings.errorDomain, code: code.rawValue, userInfo: userInfo)
  }
  
  static func createError(statusCode: NSInteger) -> Error {
    switch statusCode {
    case 401:
      return self.createError(description: "Tester not authenticated", code: .ApiErrorUnauthenticated)
    case 403, 400:
      return self.createError(description: "Tester not authorized", code: .ApiErrorUnauthorized)
    case 404:
      return self.createError(description: "Tester or releases not found", code: .ApiErrorUnauthorized)
    case 408, 504:
      return self.createError(description: "Request timeout", code: .ApiErrorTimeout)
    default:
      Logger.logError(String(format: "Encountered unmapped status code: %ld", statusCode))
    }
    
    let description = String(format: "Unknown status code: %ld", statusCode)
    return self.createError(description: description, code: .ApiErrorUnknownFailure)
  }
    
  static func createHttpRequest(method: String, url: String, authTokenResult: InstallationsAuthTokenResult) -> NSMutableURLRequest {
    let request = NSMutableURLRequest()
    request.url = URL(string: url)
    request.httpMethod = method
    request.setValue(authTokenResult.authToken, forHTTPHeaderField: Strings.installationsAuthHeader)
    request.setValue(FirebaseApp.app()?.options.apiKey, forHTTPHeaderField: Strings.installationsAuthHeader)
    request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: Strings.apiBundleKey)
    return request
  }
  
  static func handleReleaseResponse(data: NSData, response: URLResponse, error: Error?) -> Array<Any>? {
    return self.parseApiResponseWithData(data: data, error: error)
  }
    
  static func parseApiResponseWithData(data: NSData, error: Error?) -> Array<Any>? {
    do {
      let serializedResponse = try JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as? [String: Any]
      return serializedResponse![Strings.responseReleaseKey] as? Array<Any>
    } catch {
      // TODO: Handle error
      return nil
    }
  }
}
