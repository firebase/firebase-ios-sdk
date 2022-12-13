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

@_implementationOnly import GoogleUtilities

protocol SettingsDownloadClient {
  func fetch(completion: @escaping (Result<[String: Any], Error>) -> Void)
}

class SettingsDownloader: SettingsDownloadClient {
  private let appInfo: ApplicationInfoProtocol
  private let identifiers: IdentifierProvider
  private let installations: InstallationsProtocol

  init(appInfo: ApplicationInfoProtocol, identifiers: IdentifierProvider,
       installations: InstallationsProtocol) {
    self.appInfo = appInfo
    self.identifiers = identifiers
    self.installations = installations
  }

  func fetch(completion: @escaping (Result<[String: Any], Error>) -> Void) {
    guard let validURL = url else {
      completion(.failure(FirebaseSessionsError.SettingsError("Invalid URL")))
      return
    }

    buildRequest(url: validURL) { result in
      switch result {
      case let .success(request):
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
          if let data = data {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
              completion(.success(dict))
            } else {
              completion(.failure(FirebaseSessionsError
                  .SettingsError("Failed to parse JSON to dictionary")))
            }
          } else if let error = error {
            completion(.failure(FirebaseSessionsError.SettingsError(error.localizedDescription)))
          }
        }
        // Start the task that sends the network request
        task.resume()
      case let .failure(error):
        completion(.failure(FirebaseSessionsError.SettingsError(error.localizedDescription)))
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

  private func buildRequest(url: URL, completion: @escaping (Result<URLRequest, Error>) -> Void) {
    installations.installationID { [self] result in
      switch result {
      case let .success(fiid):
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
        completion(.success(request))
      case let .failure(error):
        completion(.failure(error))
      }
    }
  }
}
