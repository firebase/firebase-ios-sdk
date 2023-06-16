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

public protocol AuthRPCResponse {
  /// Bare initializer for a response.
  init()

  /** @fn setFieldsWithDictionary:error:
      @brief Sets the response instance from the decoded JSON response.
      @param dictionary The dictionary decoded from HTTP JSON response.
      @param error An out field for an error which occurred constructing the request.
      @return Whether the operation was successful or not.
   */
  func setFields(dictionary: [String: AnyHashable]) throws

  /** @fn clientErrorWithshortErrorMessage:detailErrorMessage
      @brief This optional method allows response classes to create client errors given a short error
          message and a detail error message from the server.
      @param shortErrorMessage The short error message from the server.
      @param detailErrorMessage The detailed error message from the server.
      @return A client error, if any.
   */
  func clientError(shortErrorMessage: String, detailedErrorMessage: String?) -> Error?
}

public extension AuthRPCResponse {
  // Default implementation.
  func clientError(shortErrorMessage: String, detailedErrorMessage: String? = nil) -> Error? {
    return nil
  }
}
