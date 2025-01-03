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

import FirebaseCore
import Foundation

private let serverURLVersion = "/v1"
private let serverURLProjects = "/projects/"
private let serverURLNamespaces = "/namespaces/"
private let serverURLQuery = "fetch"

class Utils {
  class func constructServerURL(domain: String, apiKey: String?, optionsID: String,
                                namespace: String) -> URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = domain

    guard let apiKey else {
      fatalError("Missing `APIKey` from `FirebaseOptions`, please ensure the configured " +
        "`FirebaseApp` is configured with `FirebaseOptions` that contains an `APIKey`.")
    }
    components.path =
      "\(serverURLVersion)\(serverURLProjects)\(optionsID)\(serverURLNamespaces)" +
      "\(namespaceOnly(namespace)):\(serverURLQuery)"
    components.queryItems = [
      URLQueryItem(name: "key", value: apiKey),
    ]
    guard let url = components.url else {
      fatalError("Could not construct valid URL.  Check your project ID, namespace, and API Key")
    }
    return url
  }

  class func namespaceOnly(_ fullyQualifiedNamespace: String) -> String {
    let separatorIndex = fullyQualifiedNamespace.firstIndex(of: ":") ?? fullyQualifiedNamespace
      .endIndex
    return String(fullyQualifiedNamespace[..<separatorIndex])
  }
}
