// Copyright 2024 Google LLC
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

// MARK: This file is used to evaluate the AppCheckInterop API in Swift.

import Foundation

// MARK: Do not import `FirebaseAppCheck`, this file is for `FirebaseAppCheckInterop` only.

import FirebaseAppCheckInterop

final class AppCheckInteropAPITests {
  let appCheckInterop: AppCheckInterop! = nil

  func usage() {
    let _: Void = appCheckInterop.getToken(forcingRefresh: false) { result in
      let _: FIRAppCheckTokenResultInterop = result
      let _: String = result.token
      if let error = result.error {
        let _: String = error.localizedDescription
      }
    }

    let _: String = appCheckInterop.tokenDidChangeNotificationName()

    let _: String = appCheckInterop.notificationTokenKey()

    let _: String = appCheckInterop.notificationAppNameKey()

    guard let getLimitedUseToken: (@escaping AppCheckTokenHandlerInterop) -> Void =
      appCheckInterop.getLimitedUseToken else { return }
    let _: Void = getLimitedUseToken { result in
      let _: FIRAppCheckTokenResultInterop = result
      let _: String = result.token
      if let error = result.error {
        let _: String = error.localizedDescription
      }
    }
  }

  @available(iOS 13, macOS 10.15, macCatalyst 13, tvOS 13, *)
  func usage_async() async {
    let result: FIRAppCheckTokenResultInterop =
      await appCheckInterop.getToken(forcingRefresh: false)
    let _: String = result.token
    if let error = result.error {
      let _: String = error.localizedDescription
    }

    // The following fails to compile with "Command SwiftCompile failed with a nonzero exit code".
    // let _ = await appCheckInterop.getLimitedUseToken?()
  }
}
