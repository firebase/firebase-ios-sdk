// Copyright 2020 Google LLC
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

/// Namespace for performable actions on a Firebase User instance
enum UserAction: String {
  case signOut = "Sign Out"
  case link = "Link/Unlink Auth Providers"
  case requestVerifyEmail = "Request Verify Email"
  case tokenRefresh = "Token Refresh"
  case tokenRefreshAsync = "Token Refresh Async"
  case delete = "Delete"
  case updateEmail = "Email"
  case updatePhotoURL = "Photo URL"
  case updateDisplayName = "Display Name"
  case updatePhoneNumber = "Phone Number"
  case refreshUserInfo = "Refresh User Info"
  case updatePassword = "Update Password"
}
