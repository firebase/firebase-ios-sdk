// Copyright 2020 Google LLC
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

import FirebaseCore

class RemoteConfigConsole {
  private let projectID: String
  private var latestConfig: [String: Any]!

  public var requestTimeout: TimeInterval = 10

  private var consoleURL: URL {
    let api = "https://firebaseremoteconfig.googleapis.com"
    let endpoint = "/v1/projects/\(projectID)/remoteConfig"
    return URL(string: api + endpoint)!
  }

  private lazy var accessToken: String = {
    guard let fileURL = Bundle.main.url(forResource: "AccessToken", withExtension: "json") else {
      fatalError("Could not find AccessToken.json in bundle.")
    }

    guard let data = try? Data(contentsOf: fileURL),
          let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
          let jsonDict = json as? [String: Any],
          let accessToken = jsonDict["access_token"] as? String else {
      fatalError("Could not retrieve access token.")
    }
    return accessToken
  }()

  /// Synchronously fetches and returns currently active Remote Config, if it exists.
  public var activeRemoteConfig: [String: Any]? {
    var config: [String: Any]?
    perform(configRequest: .get) { latestConfigJSON in
      config = latestConfigJSON
    }
    if let config {
      saveConfig(config)
    }
    return config
  }

  /// Exposing this initializer allows us to create`RemoteConfigConsole` instances without
  /// depending on a `GoogleService-Info.plist`.
  init(projectID: String) {
    self.projectID = projectID
    syncWithConsole()
  }

  /// This initializer will attempt to read from a `GoogleService-Info.plist` to set `projectID`.
  convenience init() {
    let projectID = FirebaseApp.app()?.options.projectID
    self.init(projectID: projectID!)
  }

  // MARK: - Public API

  /// Update Remote Config with multiple String key value pairs.
  /// - Parameter parameters: Dictionary representation of config key value pairs.
  public func updateRemoteConfig(with parameters: [String: CustomStringConvertible]) {
    var updatedConfig: [String: Any] = latestConfig

    let latestParameters = latestConfig["parameters"] as? [String: Any]
    var updatedParameters = latestParameters ?? [String: Any]()
    for (key, value) in parameters {
      updatedParameters.updateValue(["defaultValue": ["value": value.description]], forKey: key)
    }
    updatedConfig.updateValue(updatedParameters, forKey: "parameters")

    publish(config: updatedConfig)
  }

  /// Updates a Remote Config value for a given key.
  /// - Parameters:
  ///   - value: Use strings, numbers, and booleans to represent Remote Config values.
  ///   - key: The corresponding string key that maps to the given value.
  public func updateRemoteConfigValue(_ value: CustomStringConvertible, forKey key: String) {
    var updatedConfig: [String: Any] = latestConfig

    let latestParameters = latestConfig["parameters"] as? [String: Any]
    if var parameters = latestParameters {
      parameters.updateValue(["defaultValue": ["value": value.description]], forKey: key)
      updatedConfig.updateValue(parameters, forKey: "parameters")

    } else {
      updatedConfig.updateValue(
        [key: ["defaultValue": ["value": value.description]]],
        forKey: "parameters"
      )
    }

    publish(config: updatedConfig)
  }

  public func removeRemoteConfigValue(forKey key: String) {
    var updatedConfig: [String: Any] = latestConfig

    let latestParameters = latestConfig["parameters"] as? [String: Any]
    if var parameters = latestParameters {
      parameters.removeValue(forKey: key)
      updatedConfig.updateValue(parameters, forKey: "parameters")
    }

    publish(config: updatedConfig)
  }

  public func clearRemoteConfig() {
    var updatedConfig: [String: Any]! = latestConfig
    updatedConfig.removeValue(forKey: "parameters")
    publish(config: updatedConfig)
  }

  // MARK: - Networking

  private enum ConfigRequest {
    case get, put(_ data: Data)

    var httpMethod: String {
      switch self {
      case .get: return "GET"
      case .put(data: _): return "PUT"
      }
    }

    var httpBody: Data? {
      switch self {
      case .get: return nil
      case let .put(data: data): return data
      }
    }

    var httpHeaderFields: [String: String]? {
      switch self {
      case .get: return nil
      case .put(data: _):
        return ["Content-Type": "application/json; UTF8", "If-Match": "*"]
      }
    }

    func secureRequest(url: URL, with token: String, _ timeout: TimeInterval = 10) -> URLRequest {
      var request = URLRequest(url: url, timeoutInterval: timeout)
      request.httpMethod = httpMethod
      request.allHTTPHeaderFields = httpHeaderFields
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      request.httpBody = httpBody
      return request
    }
  }

  /// Performs a given `ConfigRequest` synchronously.
  private func perform(configRequest: ConfigRequest,
                       _ completion: (([String: Any]?) -> Void)? = nil) {
    let request = configRequest.secureRequest(url: consoleURL, with: accessToken, requestTimeout)

    let semaphore = DispatchSemaphore(value: 0)

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      // Signal the semaphore when this scope is escaped.
      defer { semaphore.signal() }

      guard let data = data else {
        print(String(describing: error))
        return
      }

      let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)

      if let response = response as? HTTPURLResponse,
         let json = json as? [String: Any] {
        if response.statusCode >= 400 {
          print("RemoteConfigConsole Error: \(String(describing: json["error"]!))")
        }
      }

      completion?(json as? [String: Any])
    }

    task.resume()
    semaphore.wait()
  }

  /// Publishes a config object to the live console and updates `latestConfig`.
  private func publish(config: [String: Any]) {
    let configData = data(withConfig: config)
    perform(configRequest: .put(configData))
    saveConfig(config)
  }

  // MARK: - Private Helpers

  /// Creates an optional Data object given a config object.
  /// Used for serializing config objects before posting them to live console.
  private func data(withConfig config: [String: Any]) -> Data {
    let dictionary = NSDictionary(dictionary: config, copyItems: true)
    let data = try! JSONSerialization.data(withJSONObject: dictionary, options: .fragmentsAllowed)
    return data
  }

  /// Perform a synchronous sync with remote config console.
  private func syncWithConsole() {
    if let activeRemoteConfig {
      latestConfig = activeRemoteConfig
    } else {
      fatalError("Could not sync with console.")
    }
  }

  /// A more intuitively named setter for `latestConfig`.
  private func saveConfig(_ config: [String: Any]) {
    latestConfig = config
  }
}

// MARK: - Extensions

extension Bundle {
  func plistValue(forKey key: String, fromPlist plist: String) -> Any? {
    guard let plistURL = url(forResource: plist, withExtension: "") else {
      print("Could not find plist file \(plist) in bundle.")
      return nil
    }
    let plistDictionary = NSDictionary(contentsOf: plistURL)
    return plistDictionary?.object(forKey: key)
  }
}
