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


@objc(FIRFADFetchReleasesCompletion) typealias AppDistributionFetchReleasesCompletion = (releases: Array?, error: Error?)
@objc(FIRFADGenerateAuthTokenCompletion) typealias AppDistributionGenerateAuthTokenCompletion = (identifier: String?, authTokenResult: InstallationsAuthTokenResult?, error: Error?)


@objc(FIRFADSwiftApiService) open class AppDistributionApiService: NSObject {
  @objc(generateAuthTokenWithCompletion:) public static func generateAuthToken(completion: @escaping AppDistributionGenerateAuthTokenCompletion) {

  }
  
  @objc(fetchReleasesWithCompletion:) public static func fetchReleases(completion: @escaping AppDistributionFetchReleasesCompletion) {

  }
}
