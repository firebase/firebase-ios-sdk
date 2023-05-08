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

/** @typedef FIRFetchAuthDomainCallback
    @brief The callback invoked at the end of the flow to fetch the Auth domain.
    @param authDomain The Auth domain.
    @param error The error that occurred while fetching the auth domain, if any.
 */
typealias FIRFetchAuthDomainCallback = (String?, Error?) -> Void

@objc(FIRAuthWebUtils) public class AuthWebUtils: NSObject {
  static func randomString(withLength length: Int) -> String {
    var randomString = ""
    for _ in 0 ..< length {
      let randomValue = UInt32(arc4random_uniform(26) + 65)
      guard let randomCharacter = Unicode.Scalar(randomValue) else { continue }
      randomString += String(Character(randomCharacter))
    }
    return randomString
  }

  @objc public static func isCallbackSchemeRegistered(forCustomURLScheme scheme: String,
                                                      urlTypes: [[String: Any]]) -> Bool {
    let expectedCustomScheme = scheme.lowercased()
    for urlType in urlTypes {
      guard let urlTypeSchemes = urlType["CFBundleURLSchemes"] else {
        continue
      }
      if let schemes = urlTypeSchemes as? [String] {
        for urlTypeScheme in schemes {
          if urlTypeScheme.lowercased() == expectedCustomScheme {
            return true
          }
        }
      }
    }
    return false
  }

  static func isExpectedCallbackURL(_ url: URL?, eventID: String, authType: String,
                                    callbackScheme: String) -> Bool {
    guard let url else {
      return false
    }
    var actualURLComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
    actualURLComponents?.query = nil
    actualURLComponents?.fragment = nil

    var expectedURLComponents = URLComponents()
    expectedURLComponents.scheme = callbackScheme
    expectedURLComponents.host = "firebaseauth"
    expectedURLComponents.path = "/link"

    guard let actualURL = actualURLComponents?.url,
          let expectedURL = expectedURLComponents.url else {
      return false
    }
    if expectedURL != actualURL {
      return false
    }
    let urlQueryItems = dictionary(withHttpArgumentsString: url.query)
    guard let deeplinkURLString = urlQueryItems["deep_link_id"],
          let deeplinkURL = URL(string: deeplinkURLString) else {
      return false
    }
    let deeplinkQueryItems = dictionary(withHttpArgumentsString: deeplinkURL.query)
    if deeplinkQueryItems["authType"] == authType, deeplinkQueryItems["eventId"] == eventID {
      return true
    }
    return false
  }

  static func fetchAuthDomain(withRequestConfiguration requestConfiguration: AuthRequestConfiguration,
                              completion: @escaping FIRFetchAuthDomainCallback) {
    if let emulatorHostAndPort = requestConfiguration.emulatorHostAndPort {
      // If we are using the auth emulator, we do not want to call the GetProjectConfig endpoint. The
      // widget is hosted on the emulator host and port, so we can return that directly.
      completion(emulatorHostAndPort, nil)
      return
    }

    let request = GetProjectConfigRequest(requestConfiguration: requestConfiguration)

    AuthBackend.post(withRequest: request) { response, error in
      if let error = error {
        completion(nil, error)
        return
      }
      // Look up an authorized domain ends with one of the supportedAuthDomains.
      // The sequence of supportedAuthDomains matters. ("firebaseapp.com", "web.app")
      // The searching ends once the first valid suportedAuthDomain is found.
      var authDomain: String?
      if let response = response as? GetProjectConfigResponse {
        for domain in response.authorizedDomains ?? [] {
          for supportedAuthDomain in Self.supportedAuthDomains {
            let index = domain.count - supportedAuthDomain.count
            if index >= 2, domain.hasSuffix(supportedAuthDomain),
               domain.count >= supportedAuthDomain.count + 2 {
              authDomain = domain
              break
            }
          }
          if authDomain != nil {
            break
          }
        }
      }

      if authDomain == nil || authDomain!.isEmpty {
        completion(
          nil,
          AuthErrorUtils.unexpectedErrorResponse(deserializedResponse: response)
        )
        return
      }
      completion(authDomain, nil)
    }
  }

  static func queryItemValue(name: String, from queryList: [URLQueryItem]) -> String? {
    for item in queryList where item.name == name {
      return item.value
    }
    return nil
  }

  @objc public static func dictionary(withHttpArgumentsString argString: String?)
    -> [String: String] {
    guard let argString else {
      return [:]
    }
    var ret = [String: String]()
    let components = argString.components(separatedBy: "&")
    // Use reverse order so that the first occurrence of a key replaces
    // those subsequent.
    for component in components.reversed() {
      if component.isEmpty { continue }
      let pos = component.firstIndex(of: "=")
      var key: String
      var val: String
      if pos == nil {
        key = string(byUnescapingFromURLArgument: component)
        val = ""
      } else {
        let index = component.index(after: pos!)
        key = string(byUnescapingFromURLArgument: String(component[..<pos!]))
        val = string(byUnescapingFromURLArgument: String(component[index...]))
      }
      if key.isEmpty { key = "" }
      if val.isEmpty { val = "" }
      ret[key] = val
    }
    return ret
  }

  static func string(byUnescapingFromURLArgument argument: String) -> String {
    return argument
      .replacingOccurrences(of: "+", with: " ")
      .removingPercentEncoding ?? ""
  }

  @objc public static func parseURL(_ urlString: String) -> [String: String] {
    let urlComponents = URLComponents(string: urlString)
    guard let linkURL = urlComponents?.query else {
      return [:]
    }
    let queryComponents = linkURL.components(separatedBy: "&")
    var queryItems = [String: String]()
    for component in queryComponents {
      if let equalRange = component.range(of: "=") {
        let queryItemKey = component[..<equalRange.lowerBound].removingPercentEncoding
        let queryItemValue = component[equalRange.upperBound...].removingPercentEncoding
        if let queryItemKey = queryItemKey, let queryItemValue = queryItemValue {
          queryItems[queryItemKey] = queryItemValue
        }
      }
    }
    return queryItems
  }

  static var supportedAuthDomains: [String] {
    return ["firebaseapp.com", "web.app"]
  }
}
