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
import PrivacyKit

/// Provides an API to walk the client through the creation of a Privacy
/// Manifest via a series of questions.
final class PrivacyManifestWizard {
  private let xcframework: URL

  init(xcframework: URL) {
    self.xcframework = xcframework
  }

  func nextQuestion() -> String? {
    // TODO(ncooke3): Implement.
    nil
  }

  func processAnswer(_ answer: String) throws {
    // TODO(ncooke3): Implement.
  }

  func createManifest() throws -> PrivacyManifest {
    // TODO(ncooke3): Implement.
    return PrivacyManifest()
  }
}
