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

#if SWIFT_PACKAGE
  import FirebaseSessionsObjC
#endif // SWIFT_PACKAGE

///
/// These extensions allows us to console log properties of our Session Events
/// proto for development and debugging purposes without having to call decode
/// on each field manually. Instead you can read `<field>.description`.
///

extension firebase_appquality_sessions_EventType: Swift.CustomStringConvertible {
  public var description: String {
    switch self {
    case firebase_appquality_sessions_EventType_SESSION_START:
      return "SESSION_START"
    case firebase_appquality_sessions_EventType_EVENT_TYPE_UNKNOWN:
      return "UNKNOWN"
    default:
      return "Unrecognized EventType. Please update the firebase_appquality_sessions_EventType CustomStringConvertible extension"
    }
  }
}

extension firebase_appquality_sessions_DataCollectionState: Swift.CustomStringConvertible {
  public var description: String {
    switch self {
    case firebase_appquality_sessions_DataCollectionState_COLLECTION_ENABLED:
      return "ENABLED"
    case firebase_appquality_sessions_DataCollectionState_COLLECTION_SAMPLED:
      return "SAMPLED"
    case firebase_appquality_sessions_DataCollectionState_COLLECTION_UNKNOWN:
      return "UNKNOWN"
    case firebase_appquality_sessions_DataCollectionState_COLLECTION_DISABLED:
      return "DISABLED"
    case firebase_appquality_sessions_DataCollectionState_COLLECTION_DISABLED_REMOTE:
      return "DISABLED_REMOTE"
    case firebase_appquality_sessions_DataCollectionState_COLLECTION_SDK_NOT_INSTALLED:
      return "SDK_NOT_INSTALLED"
    default:
      return "Unrecognized DataCollectionState. Please update the firebase_appquality_sessions_DataCollectionState CustomStringConvertible extension"
    }
  }
}

extension firebase_appquality_sessions_OsName: Swift.CustomStringConvertible {
  public var description: String {
    switch self {
    case firebase_appquality_sessions_OsName_IOS:
      return "IOS"
    case firebase_appquality_sessions_OsName_IPADOS:
      return "IPADOS"
    case firebase_appquality_sessions_OsName_TVOS:
      return "TVOS"
    case firebase_appquality_sessions_OsName_IOS_ON_MAC:
      return "IOS_ON_MAC"
    case firebase_appquality_sessions_OsName_MACOS:
      return "MACOS"
    case firebase_appquality_sessions_OsName_MACCATALYST:
      return "MACCATALYST"
    case firebase_appquality_sessions_OsName_WATCHOS:
      return "WATCHOS"
    case firebase_appquality_sessions_OsName_UNKNOWN_OSNAME:
      return "UNKNOWN_OSNAME"
    case firebase_appquality_sessions_OsName_UNSPECIFIED:
      return "UNSPECIFIED"
    default:
      return "Unrecognized OsName. Please update the firebase_appquality_sessions_OsName CustomStringConvertible extension"
    }
  }
}

extension firebase_appquality_sessions_LogEnvironment: Swift.CustomStringConvertible {
  public var description: String {
    switch self {
    case firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_PROD:
      return "PROD"
    case firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_STAGING:
      return "STAGING"
    case firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_AUTOPUSH:
      return "AUTOPUSH"
    case firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_UNKNOWN:
      return "UNKNOWN"
    default:
      return "Unrecognized LogEnvironment. Please update the firebase_appquality_sessions_LogEnvironment CustomStringConvertible extension"
    }
  }
}

// This is written like this for Swift backwards-compatibility.
// Once we upgrade to Xcode 14, this can be written as
// UnsafeMutablePointer<pb_bytes_array_t>
extension UnsafeMutablePointer: Swift.CustomStringConvertible where Pointee == pb_bytes_array_t {
  public var description: String {
    let decoded = FIRSESDecodeString(self)
    if decoded.count == 0 {
      return "<EMPTY>"
    }
    return decoded
  }
}

// For an optional field
// This is written like this for Swift backwards-compatibility.
// Once we upgrade to Xcode 14, this can be written as
// UnsafeMutablePointer<pb_bytes_array_t>?
extension Optional: Swift.CustomStringConvertible
  where Wrapped == UnsafeMutablePointer<pb_bytes_array_t> {
  public var description: String {
    guard let this = self else {
      return "<NULL>"
    }
    return this.description
  }
}
