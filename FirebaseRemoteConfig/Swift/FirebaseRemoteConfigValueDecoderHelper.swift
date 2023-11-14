/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
#if SWIFT_PACKAGE
  @_exported import FirebaseRemoteConfigInternal
#endif // SWIFT_PACKAGE
import FirebaseSharedSwift

/// Implement the FirebaseRemoteConfigValueDecoding protocol for the shared Firebase decoder to
/// decode Remote Config Values. It returns the four different kinds of values from
/// a RemoteConfigValue object.
struct FirebaseRemoteConfigValueDecoderHelper: FirebaseRemoteConfigValueDecoding {
  let value: RemoteConfigValue

  func numberValue() -> NSNumber {
    return value.numberValue
  }

  func boolValue() -> Bool {
    return value.boolValue
  }

  func stringValue() -> String {
    return value.stringValue ?? ""
  }

  func dataValue() -> Data {
    return value.dataValue
  }

  func arrayValue() -> [AnyHashable]? {
    guard let value = value.jsonValue as? [AnyHashable] else {
      return nil
    }
    return value
  }

  func dictionaryValue() -> [String: AnyHashable]? {
    guard let value = value.jsonValue as? [String: AnyHashable] else {
      return nil
    }
    return value
  }
}
