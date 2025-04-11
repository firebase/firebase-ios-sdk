// Copyright 2025 Google LLC
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

import FirebaseAuth
import FirebaseCore

enum TestHelpers {
  static func getUserID() async throws -> String {
    if let user = Auth.auth().currentUser {
      return user.uid
    } else {
      let authResult = try await Auth.auth().signIn(
        withEmail: Credentials.emailAddress1,
        password: Credentials.emailPassword1
      )
      return authResult.user.uid
    }
  }
}
