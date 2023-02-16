//
// Copyright 2022 Google LLC
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

@testable import FirebaseSessions

class MockSettingsDownloader: SettingsDownloadClient {
  public var shouldSucceed: Bool = true
  public var successResponse: [String: Any]

  init(successResponse: [String: Any]) {
    self.successResponse = successResponse
  }

  func fetch(completion: @escaping (Result<[String: Any], SettingsDownloaderError>) -> Void) {
    if shouldSucceed {
      completion(.success(successResponse))
    } else {
      completion(.failure(.URLError("Mocked Error.")))
    }
  }
}
