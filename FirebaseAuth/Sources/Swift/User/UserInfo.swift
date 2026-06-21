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

/// Represents user data returned from an identity provider.
@objc(FIRUserInfo) public protocol UserInfo: NSObjectProtocol {
  /// The provider identifier.
  var providerID: String { get }

  /// The provider's user ID for the user.
  var uid: String { get }

  /// The name of the user.
  var displayName: String? { get }

  /// The URL of the user's profile photo.
  var photoURL: URL? { get }

  /// The user's email address.
  var email: String? { get }

  /// A phone number associated with the user.
  ///
  /// This property is only available for users authenticated via phone number auth.
  var phoneNumber: String? { get }
}
