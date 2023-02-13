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
// Avoids exposing internal APIs to Swift users
@_implementationOnly import FirebaseCoreInternal
@_implementationOnly import FirebaseInstallations

@objc(FIRFADFetchReleasesCompletion)
typealias AppDistributionFetchReleasesCompletion = (releases: Array?, error: Error?)

@objc(FIRFADGenerateAuthTokenCompletion)
typealias AppDistributionGenerateAuthTokenCompletion = (identifier: String?, authTokenResult: InstallationsAuthTokenResult?, error: Error?)

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
      
      
    })

  }
  
  @objc(fetchReleasesWithCompletion:) public static func fetchReleases(completion: @escaping AppDistributionFetchReleasesCompletion) {

  }
}
