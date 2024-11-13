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
      kAuthGlobalWorkQueue.async {
        if self.consumed {
          fatalError("Internal Auth Error: Invalid call to setDisplayName after commitChanges.")
        }
        self.displayNameWasSet = true
        self._displayName = newDisplayName
      }
    }
  }

  private var _displayName: String?

  /// The URL of the user's profile photo.
  @objc open var photoURL: URL? {
    get { return _photoURL }
    set(newPhotoURL) {
      kAuthGlobalWorkQueue.async {
        if self.consumed {
          fatalError("Internal Auth Error: Invalid call to setPhotoURL after commitChanges.")
        }
        self.photoURLWasSet = true
        self._photoURL = newPhotoURL
      }
    }
  }

  private var _photoURL: URL?

  /// Commits any pending changes.
  ///
  /// Invoked asynchronously on the main thread in the future.
  ///
  /// This method should only be called once.Once called, property values should not be changed.
  /// - Parameter completion: Optionally; the block invoked when the user profile change has been
  /// applied.
  @objc open func commitChanges(completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      if self.consumed {
        fatalError("Internal Auth Error: commitChanges should only be called once.")
      }
      self.consumed = true
      // Return fast if there is nothing to update:
      if !self.photoURLWasSet, !self.displayNameWasSet {
        User.callInMainThreadWithError(callback: completion, error: nil)
        return
      }
      let displayName = self.displayName
      let displayNameWasSet = self.displayNameWasSet
      let photoURL = self.photoURL
      let photoURLWasSet = self.photoURLWasSet

      self.user.executeUserUpdateWithChanges(changeBlock: { user, request in
        if photoURLWasSet {
          request.photoURL = photoURL
        }
        if displayNameWasSet {
          request.displayName = displayName
        }
      }) { error in
        if let error {
          User.callInMainThreadWithError(callback: completion, error: error)
          return
        }
        if displayNameWasSet {
          self.user.displayName = displayName
        }
        if photoURLWasSet {
          self.user.photoURL = photoURL
        }
        if let error = self.user.updateKeychain() {
          User.callInMainThreadWithError(callback: completion, error: error)
        }
        User.callInMainThreadWithError(callback: completion, error: nil)
      }
    }
  }

  /// Commits any pending changes.
  ///
  /// This method should only be called once. Once called, property values should not be changed.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func commitChanges() async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.commitChanges { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  init(_ user: User) {
    self.user = user
  }

  private let user: User
  private var consumed = false
  private var displayNameWasSet = false
  private var photoURLWasSet = false
}
