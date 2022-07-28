// Copyright 2021 Google LLC
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

/// Conform to this protocol for the Firebase Decoder to extract values as from a RemoteConfigValue object.
public protocol FirebaseRemoteConfigValueDecoding {
  func numberValue() -> NSNumber
  func boolValue() -> Bool
  func stringValue() -> String
  func dataValue() -> Data
  func arrayValue() -> [AnyHashable]?
  func dictionaryValue() -> [String: AnyHashable]?
}
