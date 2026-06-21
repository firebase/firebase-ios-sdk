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

/// Bitmask value indicating the error represents a public error code when this bit is
/// zeroed. Error codes which don't contain this flag will be wrapped in an `NSError` whose
/// code is `AuthErrorCodeInternalError`.
let FIRAuthPublicErrorCodeFlag: Int = 1 << 20

enum SharedErrorCode {
  case `public`(AuthErrorCode)
  case `internal`(AuthInternalErrorCode)
}

/// Error codes used internally by Firebase Auth.
///
/// All errors are generated using an internal error code. These errors are automatically
/// converted to the appropriate public version of the `NSError` by the methods in AuthErrorUtils.
enum AuthInternalErrorCode: Int {
  /// Indicates a network error occurred (such as a timeout, interrupted connection, or
  /// unreachable host.)
  ///
  /// These types of errors are often recoverable with a retry.
  ///
  /// See the `NSUnderlyingError` value in the `NSError.userInfo` dictionary for details about
  /// the network error which occurred.
  case networkError = 17020

  /// Indicates an error encoding the RPC request.
  ///
  /// This is typically due to some sort of unexpected input value.
  ///
  /// See the `NSUnderlyingError` value in the `NSError.userInfo` dictionary for details.
  case RPCRequestEncodingError = 1

  /// Indicates an error serializing an RPC request.
  ///
  /// This is typically due to some sort of unexpected input value.
  ///
  /// If an `JSONSerialization.isValidJSONObject` check fails, the error will contain no
  /// `NSUnderlyingError` key in the `NSError.userInfo` dictionary. If an error was
  /// encountered calling `NSJSONSerialization.dataWithJSONObject`, the
  /// resulting error will be associated with the `NSUnderlyingError` key in the
  /// `NSError.userInfo` dictionary.
  case JSONSerializationError = 2

  /// Indicates an HTTP error occurred and the data returned either couldn't be deserialized
  /// or couldn't be decoded.
  ///
  /// See the `NSUnderlyingError` value in the `NSError.userInfo` dictionary for details
  /// about the HTTP error which occurred.
  ///
  /// If the response could be deserialized as JSON then the `NSError.userInfo` dictionary will
  /// contain a value for the key `AuthErrorUserInfoDeserializedResponseKey` which is the
  /// deserialized response value.
  ///
  /// If the response could not be deserialized as JSON then the `NSError.userInfo` dictionary
  /// will contain values for the `NSUnderlyingErrorKey` and `AuthErrorUserInfoDataKey` keys.
  case unexpectedErrorResponse = 3

  /// Indicates the HTTP response indicated the request was a successes, but the response
  /// contains something other than a JSON-encoded dictionary, or the data type of the response
  /// indicated it is different from the type of response we expected.
  ///
  /// See the `NSUnderlyingError` value in the `NSError.userInfo` dictionary.
  /// If this key is present in the dictionary, it may contain an error from
  /// `NSJSONSerialization` error (indicating the response received was of the wrong data type).
  ///
  /// See the `AuthErrorUserInfoDeserializedResponseKey` value in the `NSError.userInfo`
  /// dictionary. If the response could be deserialized, it's deserialized representation will
  /// be associated with this key. If the @c NSUnderlyingError value in the @c NSError.userInfo
  /// dictionary is @c nil, this indicates the JSON didn't represent a dictionary.
  case unexpectedResponse = 4

  /// Indicates an error decoding the RPC response.
  ///
  /// This is typically due to some sort of unexpected response value from the server.
  ///
  /// See the `NSUnderlyingError` value in the `NSError.userInfo` dictionary for details.
  ///
  /// See the `userInfoDeserializedResponseKey` value in the `NSError.userInfo` dictionary.
  /// The deserialized representation of the response will be associated with this key.
  case RPCResponseDecodingError = 5
}
