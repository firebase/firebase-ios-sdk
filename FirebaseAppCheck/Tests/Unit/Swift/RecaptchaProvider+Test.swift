// Copyright 2026 Google LLC
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

import AppCheckCore
import FirebaseAppCheck

/// Internal Objective-C interface for test helper methods.
@objc protocol RecaptchaProviderTesting {
  @objc(initWithRecaptchaProvider:)
  func initWithRecaptchaProvider(_ recaptchaProvider: AppCheckCoreProvider) -> RecaptchaProvider
}

@objc extension RecaptchaProvider {
  /// Safe, compile-time checked test helper that bypasses production validation checks.
  class func testInstance(recaptchaProvider: AppCheckCoreProvider) -> RecaptchaProvider {
    let providerClass = RecaptchaProvider.self as AnyObject
    let allocated = providerClass.perform(NSSelectorFromString("alloc")).takeUnretainedValue()
    let uninitialized = unsafeBitCast(allocated, to: RecaptchaProviderTesting.self)
    return uninitialized.initWithRecaptchaProvider(recaptchaProvider)
  }
}
