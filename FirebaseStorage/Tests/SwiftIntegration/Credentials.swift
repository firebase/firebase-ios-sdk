/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

/*
 Some of the Credentials needs to be populated for the Swift Tests to work.
 Please follow the following steps to populate the valid Credentials
 and copy it to Credentials.swift file:

 You will need to replace the following values:
 $KUSER_NAME
 The name of the user for Auth SignIn
 $KPASSWORD
 The password.

 */

class Credentials {
  static let kUserName = KUSER_NAME
  static let kPassword = KPASSWORD
}
