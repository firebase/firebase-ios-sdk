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
  func fetch(appInfo: ApplicationInfoProtocol, completion block: @escaping (Result<[String: Any], Error>) -> Void)
}

class SettingsDownloader: SettingsDownloadClient {
  func fetch(appInfo: ApplicationInfoProtocol, completion: @escaping (Result<[String: Any], Error>) -> Void) {
    guard let url = buildURL(appInfo: appInfo) else {
      completion(.failure(FirebaseSessionsError.SettingsError("Invalid URL")))
      return
    }
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let data = data {
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          completion(.success(dict))
        } else {
          completion(.failure(FirebaseSessionsError.SettingsError("Failed to parse JSON to dictionary")))
        }
      } else if error != nil {
        completion(.failure(FirebaseSessionsError.SettingsError("Network request failed with error \(String(describing: error))")))
      }
    }
    task.resume()
  }

  private func buildURL(appInfo: ApplicationInfoProtocol) -> URL? {
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
}
