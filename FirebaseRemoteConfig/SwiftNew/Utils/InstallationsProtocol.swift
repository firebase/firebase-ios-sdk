// Copyright 2025 Google LLC
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

/// Enable faking Installations for fetch and realtime testing.
@objc(FIRInstallationsProtocol) public protocol InstallationsProtocol {
  func installationID(completion: @escaping (String?, (any Error)?) -> Void)
  func authToken(completion: @escaping (InstallationsAuthTokenResult?, (any Error)?) -> Void)
}

extension Installations: InstallationsProtocol {}
