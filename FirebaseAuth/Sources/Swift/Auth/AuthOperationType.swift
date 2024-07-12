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

/// Indicates the type of operation performed for RPCs that support the operation parameter.
enum AuthOperationType: Int {
  /// Indicates that the operation type is uspecified.
  case unspecified = 0

  /// Indicates that the operation type is sign in or sign up.
  case signUpOrSignIn = 1

  /// Indicates that the operation type is reauthentication.
  case reauth = 2

  /// Indicates that the operation type is update.
  case update = 3

  /// Indicates that the operation type is link.
  case link = 4
}
