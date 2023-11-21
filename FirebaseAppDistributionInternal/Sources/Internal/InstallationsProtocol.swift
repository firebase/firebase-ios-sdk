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

import FirebaseInstallations
import Foundation

// Wraps around the use of FIRInstallations in a protocol to be able to inject a fake one for
// unit testing.
protocol InstallationsProtocol {
  func authToken(completion: @escaping (InstallationsAuthTokenResult?, Error?) -> Void)
  func installationID(completion: @escaping (String?, Error?) -> Void)
}

extension Installations: InstallationsProtocol {}
