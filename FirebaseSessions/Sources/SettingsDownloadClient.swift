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

protocol SettingsDownloadClient {
  func fetch(completion block: @escaping (Result<[String: Any], Error>) -> Void)
}

class SettingsDownloader: SettingsDownloadClient {
  private static let baseEndpoint: String =
    "https://firebase-settings.crashlytics.com/spi/v2/platforms/android/gmp/"

  private let appInfo: ApplicationInfoProtocol

  private var url: URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "firebase-settings.crashlytics.com"
    components.path = "/spi/v2/platforms/android/gmp/\(appInfo.appID)/settings"
    components.queryItems = [
      URLQueryItem(name: "build_version", value: appInfo.appBuildVersion),
      URLQueryItem(name: "display_version", value: appInfo.appDisplayVersion),
      URLQueryItem(name: "instance", value: "abadc0de"),
      URLQueryItem(name: "source", value: "4"), // 4 is enum value for AppStore
    ]
    return components.url
  }

  init(appInfo: ApplicationInfoProtocol) {
    self.appInfo = appInfo
  }

  func fetch(completion: @escaping (Result<[String: Any], Error>) -> Void) {
    guard let url = url else {
      Logger.logError("[Settings] Invalid URL")
      completion(.failure(FirebaseSessionsError.SettingsError))
      return
    }
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let data = data {
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          completion(.success(dict))
        } else {
          completion(.failure(FirebaseSessionsError.SettingsError))
        }
      } else if error != nil {
        completion(.failure(FirebaseSessionsError.SettingsError))
      }
    }
  }
}
