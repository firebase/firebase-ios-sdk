//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 13/02/2023.
//

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
        for _ in 0..<length {
            let randomValue = UInt32(arc4random_uniform(26) + 65)
            guard let randomCharacter = Unicode.Scalar(randomValue) else { continue }
            randomString += String(Character(randomCharacter))
        }
        return randomString
    }

    @objc public static func isCallbackSchemeRegisteredForCustomURLScheme(_ scheme: String) -> Bool {
        let expectedCustomScheme = scheme.lowercased()
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }
        for urlType in urlTypes {
            guard let urlTypeSchemes = urlType["CFBundleURLSchemes"] as? [String] else {
                continue
            }
            for urlTypeScheme in urlTypeSchemes {
                if urlTypeScheme.lowercased() == expectedCustomScheme {
                    return true
                }
            }
        }
        return false
    }

    static func isExpectedCallbackURL(_ url: URL?, eventID: String, authType: String, callbackScheme: String) -> Bool {
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

        guard let actualURL = actualURLComponents?.url, let expectedURL = expectedURLComponents.url else {
            return false
        }
        if expectedURL != actualURL {
            return false
        }
        let URLQueryItems = dictionary(withHttpArgumentsString: url.query)
        guard let deeplinkURLString = URLQueryItems["deep_link_id"], let deeplinkURL = URL(string: deeplinkURLString) else {
            return false
        }
        let deeplinkQueryItems = dictionary(withHttpArgumentsString: deeplinkURL.query)
        if deeplinkQueryItems["authType"] == authType && deeplinkQueryItems["eventId"] == eventID {
            return true
        }
        return false
    }

    static func fetchAuthDomain(withRequestConfiguration requestConfiguration: AuthRequestConfiguration, completion: @escaping FIRFetchAuthDomainCallback) {

        if let emulatorHostAndPort = requestConfiguration.emulatorHostAndPort {
            completion(emulatorHostAndPort, nil)
            return
        }

        let request = GetProjectConfigRequest(requestConfiguration: requestConfiguration)

        FIRAuthBackend.getProjectConfig(request) { (response, error) in
            if let error = error {
                completion(nil, error)
                return
            }

            var authDomain: String?
            for domain in response?.authorizedDomains ?? [] {
                for supportedAuthDomain in Self.supportedAuthDomains {
                    let index = domain.count - supportedAuthDomain.count
                    if index >= 2, domain.hasSuffix(supportedAuthDomain), domain.count >= supportedAuthDomain.count + 2 {
                        authDomain = domain
                        break
                    }
                }

                if authDomain != nil {
                    break
                }
            }

            if authDomain == nil || authDomain!.isEmpty {
                completion(nil, AuthErrorUtils.unexpectedErrorResponse(deserializedResponse: response))
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

    static func dictionary(withHttpArgumentsString argString: String?) -> [String: String] {
        guard let argString else {
            return [:]
        }
        var ret = [String: String]()
        let components = argString.components(separatedBy: "&")
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
