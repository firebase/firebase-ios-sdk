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


@objc(FIRFADSwiftApiService) open class AppDistributionApiService: NSObject {
  
  @objc(generateAuthTokenWithCompletion:) public static func generateAuthToken(completion: @escaping AppDistributionGenerateAuthTokenCompletion) {
    let installations = Installations.installations()
    
    installations.authToken(completion: { (authTokenResult, error) -> Void in
      if error != nil {
        completion(nil, nil, error)
        return
      }
      
      installations.installationID(completion: { (identifier, error) -> Void in
        if error != nil {
          completion(nil, nil, error)
          return
        }
        
        completion(identifier, authTokenResult, nil)
      })
    })
  }
 
  @objc(fetchReleasesWithCompletion:) public static func fetchReleases(completion: @escaping AppDistributionFetchReleasesCompletion) {
    self.generateAuthToken() { (identifier, authTokenResult, error) in
      let urlString = String(format: Strings.releaseEndpointUrlTemplate, FirebaseApp.app()!.options.googleAppID, identifier!)
      let request = self.createHttpRequest(method: Strings.httpGet, url: urlString, authTokenResult: authTokenResult!)
      
      let listReleaseDataTask = URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) in
        let (releases, fadError) = self.handleReleaseResponse(data: data! as NSData, response: response!, error: error)
        let statusCode = (response as! HTTPURLResponse).statusCode
        DispatchQueue.main.async {
          completion(releases, fadError)
        }
      }
      
      listReleaseDataTask.resume()
    }
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
  
  static func handleReleaseResponse(data: NSData, response: URLResponse, error: Error?) -> (Array<Any>?, Error?) {
    return self.parseApiResponseWithData(data: data, error: error)
  }
    
  static func parseApiResponseWithData(data: NSData, error: Error?) -> (Array<Any>?, Error?) {
    do {
      let serializedResponse = try JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as? [String: Any]
      return (serializedResponse![Strings.responseReleaseKey] as? Array<Any>, nil)
    } catch {
      // TODO: Handle error
      return (nil, nil)
    }
  }
}
