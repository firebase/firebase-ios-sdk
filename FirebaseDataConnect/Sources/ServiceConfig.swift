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
public enum ServiceRegion: String {
  case USCentral1 = "us-central1"
  case USWest1 = "us-west1"
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct ServiceConfig {
  public private(set) var serviceId: String
  public private(set) var location: ServiceRegion
  public private(set) var connector: String
  public private(set) var revision: String

  public init(serviceId: String, location: ServiceRegion, connector: String, revision: String) {
    self.serviceId = serviceId
    self.location = location
    self.connector = connector
    self.revision = revision
  }
}
