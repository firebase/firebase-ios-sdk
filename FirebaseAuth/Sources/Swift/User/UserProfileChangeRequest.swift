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

/** @class UserProfileChangeRequest
    @brief Represents an object capable of updating a user's profile data.
    @remarks Properties are marked as being part of a profile update when they are set. Setting a
        property value to nil is not the same as leaving the property unassigned.
 */
@objc(FIRUserProfileChangeRequest) public class UserProfileChangeRequest: NSObject {
  /** @property displayName
   @brief The name of the user.
   */
  @objc public var displayName:String?

  /** @property photoURL
   @brief The URL of the user's profile photo.
   */
  @objc public var photoURL: URL?

  /** @fn commitChangesWithCompletion:
   @brief Commits any pending changes.
   @remarks This method should only be called once. Once called, property values should not be
   changed.

   @param completion Optionally; the block invoked when the user profile change has been applied.
   Invoked asynchronously on the main thread in the future.
   */
  @objc public func commitChanges(withCompletion completion: ((Error?) -> Void)?) {

  }

  init(_ user: User) {
    self.user = user
  }

  private let user: User
}
