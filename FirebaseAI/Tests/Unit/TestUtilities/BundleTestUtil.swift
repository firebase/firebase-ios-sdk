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

import Foundation

/// `Bundle` test utilities.
final class BundleTestUtil {
  /// Returns the `Bundle` for the test module or target containing the file.
  ///
  /// This abstracts away the `Bundle` differences between SPM and CocoaPods tests.
  static func bundle() -> Bundle {
    #if SWIFT_PACKAGE
      return Bundle.module
    #else // SWIFT_PACKAGE
      return Bundle(for: Self.self)
    #endif // SWIFT_PACKAGE
  }

  private init() {}
}
