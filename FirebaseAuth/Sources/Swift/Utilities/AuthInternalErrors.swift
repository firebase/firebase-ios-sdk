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

/** @var FIRAuthPublicErrorCodeFlag
    @brief Bitmask value indicating the error represents a public error code when this bit is
        zeroed. Error codes which don't contain this flag will be wrapped in an @c NSError whose
        code is @c FIRAuthErrorCodeInternalError.
 */
let FIRAuthPublicErrorCodeFlag: Int = 1 << 20

/** @var FIRAuthInternalErrorCode
    @brief Error codes used internally by Firebase Auth.
    @remarks All errors are generated using an internal error code. These errors are automatically
        converted to the appropriate public version of the @c NSError by the methods in
        @c FIRAuthErrorUtils
 */

enum SharedErrorCode {
  case `public`(AuthErrorCode)
  case `internal`(AuthInternalErrorCode)
}

enum AuthInternalErrorCode: Int {
  case networkError = 17020

  /** @var FIRAuthInternalErrorCodeRPCRequestEncodingError
   @brief Indicates an error encoding the RPC request.
   @remarks This is typically due to some sort of unexpected input value.

   See the @c NSUnderlyingError value in the @c NSError.userInfo dictionary for details.
   */
  case RPCRequestEncodingError = 1

  /** @var FIRAuthInternalErrorCodeJSONSerializationError
   @brief Indicates an error serializing an RPC request.
   @remarks This is typically due to some sort of unexpected input value.

   If an @c NSJSONSerialization.isValidJSONObject: check fails, the error will contain no
   @c NSUnderlyingError key in the @c NSError.userInfo dictionary. If an error was
   encountered calling @c NSJSONSerialization.dataWithJSONObject:options:error:, the
   resulting error will be associated with the @c NSUnderlyingError key in the
   @c NSError.userInfo dictionary.
   */
  case JSONSerializationError = 2

  /** @var FIRAuthInternalErrorCodeUnexpectedErrorResponse
   @brief Indicates an HTTP error occurred and the data returned either couldn't be deserialized
   or couldn't be decoded.
   @remarks See the @c NSUnderlyingError value in the @c NSError.userInfo dictionary for details
   about the HTTP error which occurred.

   If the response could be deserialized as JSON then the @c NSError.userInfo dictionary will
   contain a value for the key @c FIRAuthErrorUserInfoDeserializedResponseKey which is the
   deserialized response value.

   If the response could not be deserialized as JSON then the @c NSError.userInfo dictionary
   will contain values for the @c NSUnderlyingErrorKey and @c FIRAuthErrorUserInfoDataKey
   keys.
   */
  case unexpectedErrorResponse = 3

  /** @var FIRAuthInternalErrorCodeUnexpectedResponse
   @brief Indicates the HTTP response indicated the request was a successes, but the response
   contains something other than a JSON-encoded dictionary, or the data type of the response
   indicated it is different from the type of response we expected.
   @remarks See the @c NSUnderlyingError value in the @c NSError.userInfo dictionary.
   If this key is present in the dictionary, it may contain an error from
   @c NSJSONSerialization error (indicating the response received was of the wrong data
   type).

   See the @c FIRAuthErrorUserInfoDeserializedResponseKey value in the @c NSError.userInfo
   dictionary. If the response could be deserialized, it's deserialized representation will
   be associated with this key. If the @c NSUnderlyingError value in the @c NSError.userInfo
   dictionary is @c nil, this indicates the JSON didn't represent a dictionary.
   */
  case unexpectedResponse = 4

  /** @var FIRAuthInternalErrorCodeRPCResponseDecodingError
   @brief Indicates an error decoding the RPC response.
   This is typically due to some sort of unexpected response value from the server.
   @remarks See the @c NSUnderlyingError value in the @c NSError.userInfo dictionary for details.

   See the @c FIRErrorUserInfoDecodedResponseKey value in the @c NSError.userInfo dictionary.
   The deserialized representation of the response will be associated with this key.
   */
  case RPCResponseDecodingError = 5
}
