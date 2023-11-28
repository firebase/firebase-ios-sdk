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

extension Questionnaire {
  /// Creates a questionnaire that, when complete, can be used to generate a Privacy Manifest.
  ///
  /// - Parameters:
  ///   - xcframework: The xcframework to generate the Privacy Manifest for.
  ///   - builder: The Privacy Manifest builder to mutate in each question's answer handler closure.
  /// - Returns: A questionnaire that can be used to generate a Privacy Manifest.
  static func makePrivacyQuestionnaire(for xcframework: URL,
                                       with builder: PrivacyManifest.Builder) -> Self {
    // TODO(ncooke3): Implement.
    Questionnaire()
  }
}
