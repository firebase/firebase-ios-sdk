// Copyright 2024 Google LLC
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

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct DataConnectSettings: Hashable, Equatable {
  public private(set) var host: String
  public private(set) var port: Int
  public private(set) var sslEnabled: Bool

  public init(host: String, port: Int, sslEnabled: Bool) {
    self.host = host
    self.port = port
    self.sslEnabled = sslEnabled
  }

  public init() {
    self.host = "firebasedataconnect.googleapis.com"
    self.port = 443
    self.sslEnabled = true
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(host)
    hasher.combine(port)
    hasher.combine(sslEnabled)
  }

  public static func == (lhs: DataConnectSettings, rhs: DataConnectSettings) -> Bool {
    return lhs.host == rhs.host &&
    lhs.port == rhs.port &&
    lhs.sslEnabled == rhs.sslEnabled
  }

}
