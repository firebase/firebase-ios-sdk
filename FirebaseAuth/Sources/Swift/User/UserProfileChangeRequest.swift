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

/// Represents an object capable of updating a user's profile data.
///
/// Properties are marked as being part of a profile update when they are set. Setting a
/// property value to nil is not the same as leaving the property unassigned.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRUserProfileChangeRequest) open class UserProfileChangeRequest: NSObject {
  /// The name of the user.
  @objc open var displayName: String? {
    get { return _displayName }
    set(newDisplayName) {
      if consumed {
        fatalError("Internal Auth Error: Invalid call to setDisplayName after commitChanges.")
      }
      displayNameWasSet = true
      _displayName = newDisplayName
    }
  }

  private var _displayName: String?

  /// The URL of the user's profile photo.
  @objc open var photoURL: URL? {
    get { return _photoURL }
    set(newPhotoURL) {
      if consumed {
        fatalError("Internal Auth Error: Invalid call to setPhotoURL after commitChanges.")
      }
      photoURLWasSet = true
      _photoURL = newPhotoURL
    }
  }

  private var _photoURL: URL?

  /// Commits any pending changes.
  ///
  /// Invoked asynchronously on the main thread in the future.
  ///
  /// This method should only be called once. Once called, property values should not be changed.
  /// - Parameter completion: Optionally; the block invoked when the user profile change has been
  /// applied.
  @objc open func commitChanges(completion: ((Error?) -> Void)? = nil) {
    Task {
      do {
        try await self.commitChanges()
        await MainActor.run {
          completion?(nil)
        }
      } catch {
        await MainActor.run {
          completion?(error)
        }
      }
    }
  }

  /// Commits any pending changes.
  ///
  /// This method should only be called once. Once called, property values should not be changed.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func commitChanges() async throws {
    try await user.auth.authWorker.commitChanges(changeRequest: self)
  }

  init(_ user: User) {
    self.user = user
  }

  let user: User
  var consumed = false
  var displayNameWasSet = false
  var photoURLWasSet = false
}
