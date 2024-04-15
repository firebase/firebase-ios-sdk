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

#if SWIFT_PACKAGE
  @_implementationOnly import GoogleUtilities_Environment
#else
  @_implementationOnly import GoogleUtilities
#endif // SWIFT_PACKAGE

protocol SettingsDownloadClient {
  func fetch(completion: @escaping (Result<[String: Any], SettingsDownloaderError>) -> Void)
}

enum SettingsDownloaderError: Error {
  /// Error contructing the URL
  case URLError(String)
  /// Error from the URLSession task
  case URLSessionError(String)
  /// Error parsing the JSON response from Settings
  case JSONParseError(String)
  /// Error getting the Installation ID
  case InstallationIDError(String)
}

class SettingsDownloader: SettingsDownloadClient {
  private let appInfo: ApplicationInfoProtocol
  private let installations: InstallationsProtocol

  init(appInfo: ApplicationInfoProtocol, installations: InstallationsProtocol) {
    self.appInfo = appInfo
    self.installations = installations
  }

  func fetch(completion: @escaping (Result<[String: Any], SettingsDownloaderError>) -> Void) {
    guard let validURL = url else {
      completion(.failure(.URLError("Invalid URL")))
      return
    }

    installations.installationID { result in
      switch result {
      case let .success(fiid):
        let request = self.buildRequest(url: validURL, fiid: fiid)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
          if let data = data {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
              completion(.success(dict))
            } else {
              completion(.failure(
                .JSONParseError("Failed to parse JSON to dictionary")
              ))
            }
          } else if let error = error {
            completion(.failure(.URLSessionError(error.localizedDescription)))
          }
        }
        // Start the task that sends the network request
        task.resume()
      case let .failure(error):
        completion(.failure(.InstallationIDError(error.localizedDescription)))
      }
    }
  }

  private var url: URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "firebase-settings.crashlytics.com"
    components.path = "/spi/v2/platforms/\(appInfo.osName)/gmp/\(appInfo.appID)/settings"
    components.queryItems = [
      URLQueryItem(name: "build_version", value: appInfo.appBuildVersion),
      URLQueryItem(name: "display_version", value: appInfo.appDisplayVersion),
    ]
    return components.url
  }

  private func buildRequest(url: URL, fiid: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(fiid, forHTTPHeaderField: "X-Crashlytics-Installation-ID")
    request.setValue(appInfo.deviceModel, forHTTPHeaderField: "X-Crashlytics-Device-Model")
    request.setValue(
      appInfo.osBuildVersion,
      forHTTPHeaderField: "X-Crashlytics-OS-Build-Version"
    )
    request.setValue(
      appInfo.osDisplayVersion,
      forHTTPHeaderField: "X-Crashlytics-OS-Display-Version"
    )
    request.setValue(appInfo.sdkVersion, forHTTPHeaderField: "X-Crashlytics-API-Client-Version")
    return request
  }
}
