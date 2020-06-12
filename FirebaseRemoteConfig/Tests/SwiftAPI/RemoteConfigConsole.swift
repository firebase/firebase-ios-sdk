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

class RemoteConfigConsole {
  private let projectID: String
  private var latestConfig: [String: Any]!

  public var requestTimeout: TimeInterval = 10

  private var consoleURL: URL {
    let api = "https://firebaseremoteconfig.googleapis.com"
    let endpoint = "/v1/projects/\(projectID)/remoteConfig"
    return URL(string: api + endpoint)!
  }

  private var accessToken: String {
    // PASTE ACCESS TOKEN HERE
    "12837498639736566939736476397"
  }

  /// Synchronously fetches and returns currently active
  /// remote config, if it exists
  public var activeRemoteConfig: [String: Any]? {
    var config: [String: Any]?
    perform(configRequest: .get) { latestConfigJSON in
      config = latestConfigJSON
    }
    if let config = config {
      save(config)
    }
    return config
  }

  /// Exposing this initializer allows us to
  /// create`RemoteConfigConsole` instances without
  /// dependence on a`GoogleService-Info.plist`.
  init(projectID: String) {
    self.projectID = projectID
    syncWithConsole()
  }

  /// This initializer will attempt to read from a
  /// `GoogleService-Info.plist` to set `projectID`
  convenience init() {
    let currentBundle = Bundle(for: type(of: self))
    let projectID = currentBundle.plistValue(for: "PROJECT_ID", from: "GoogleService-Info.plist")
    self.init(projectID: projectID! as! String)
  }

  // MARK: - Public API

  public func updateRemoteConfig(parameters: [String: Any]) {
    var updatedConfig: [String: Any] = latestConfig

    let latestParameters = latestConfig["parameters"] as? [String: Any]
    if var updatedParameters = latestParameters {
      for (key, value) in parameters {
        updatedParameters.updateValue(["defaultValue": ["value": value]], forKey: key)
      }
      updatedConfig.updateValue(updatedParameters, forKey: "parameters")

    } else {
      var newParameters = [String: Any]()

      for (key, value) in parameters {
        newParameters.updateValue(["defaultValue": ["value": value]], forKey: key)
      }
      updatedConfig.updateValue(newParameters, forKey: "parameters")
    }

    publish(config: updatedConfig)
  }

  public func updateRemoteConfigValue(_ value: Any, for key: String) {
    var updatedConfig: [String: Any] = latestConfig

    let latestParameters = latestConfig["parameters"] as? [String: Any]
    if var parameters = latestParameters {
      parameters.updateValue(["defaultValue": ["value": value]], forKey: key)
      updatedConfig.updateValue(parameters, forKey: "parameters")

    } else {
      updatedConfig.updateValue([key: ["defaultValue": ["value": value]]], forKey: "parameters")
    }

    publish(config: updatedConfig)
  }

  public func removeRemoteConfigValue(for key: String) {
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

  // Other possible API's
  public func currentRemoteConfigValue(for key: String) -> Any { "" }

  public func validateRemoteConfig(with values: [String: Any]) -> Bool { false }

  // MARK: - Networking

  private enum ConfigRequest {
    case get, post(data: Data)

    var httpMethod: String {
      switch self {
      case .get: return "GET"
      case .post(data: _): return "PUT"
      }
    }

    var httpBody: Data? {
      switch self {
      case .get: return nil
      case let .post(data: data): return data
      }
    }

    var HTTPHeaderFields: [String: String]? {
      switch self {
      case .get: return nil
      case .post(data: _):
        return ["Content-Type": "application/json; UTF8", "If-Match": "*"]
      }
    }

    func secureRequest(url: URL, with token: String, _ timeout: TimeInterval = 10) -> URLRequest {
      var request = URLRequest(url: url, timeoutInterval: timeout)
      request.httpMethod = self.httpMethod
      request.allHTTPHeaderFields = self.HTTPHeaderFields
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      request.httpBody = self.httpBody
      return request
    }
  }

  /// Performs a given `ConfigRequest` synchronously.
  private func perform(configRequest: ConfigRequest,
                       _ completion: (([String: Any]) -> Void)? = nil) {
    let request = configRequest.secureRequest(url: consoleURL, with: accessToken, requestTimeout)

    let semaphore = DispatchSemaphore(value: 0)

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data else {
        print(String(describing: error))
        return
      }

      // TODO: Handle errors. As of now, errors are returned in `data` and will be
      // noticed in the Xcode console when the following line runs
//            print(String(data: data, encoding: .utf8)!)

      if let completion = completion {
        let json = try! JSONSerialization
          .jsonObject(with: data, options: .fragmentsAllowed) as! [String: Any]
        completion(json)
      }

      semaphore.signal()
    }

    task.resume()
    semaphore.wait()
  }

  /// Publishes a config object to the live console
  /// and updates`latestConfig`
  private func publish(config: [String: Any]) {
    if let configData = data(with: config) {
      perform(configRequest: .post(data: configData))
    }
    save(config)
  }

  // MARK: - Private Helpers

  /// Creates an optional Data object given a config object
  /// Used for serializing config objects before posting them to live console
  private func data(with config: [String: Any]) -> Data? {
    let dictionary = NSDictionary(dictionary: config, copyItems: true)
    let data = try? JSONSerialization.data(withJSONObject: dictionary, options: .fragmentsAllowed)
    return data
  }

  /// Perform a synchronous sync with remote config console.
  private func syncWithConsole() {
    if let consoleConfig = activeRemoteConfig {
      latestConfig = consoleConfig
    } else {
      print("Could not sync with console.")
    }
  }

  /// A more intuitively named setter for `latestConfig`
  private func save(_ config: [String: Any]) {
    latestConfig = config
  }
}

// MARK: - Extensions

extension Bundle {
  func plistValue(for key: String, from plist: String) -> Any? {
    guard let plistURL = url(forResource: plist, withExtension: "") else {
      print("Could not find plist file \(plist) in bundle.")
      return nil
    }
    let plistDictionary = NSDictionary(contentsOf: plistURL)
    return plistDictionary?.object(forKey: key)
  }
}
