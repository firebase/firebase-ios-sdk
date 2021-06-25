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

/// Struct describing Firebase pods to release.
public struct Pod {
  public let name: String
  public let isClosedSource: Bool
  public let isBeta: Bool
  public let allowWarnings: Bool // Allow validation warnings. Ideally these should all be false
  public let platforms: Set<String> // Set of platforms to build this pod for
  public let releasing: Bool // Non-Firebase pods may not release
  public let zip: Bool // Top level pod in Zip Distribution

  init(_ name: String,
       isClosedSource: Bool = false,
       isBeta: Bool = false,
       allowWarnings: Bool = false,
       platforms: Set<String> = ["ios", "macos", "tvos"],
       podVersion: String? = nil,
       releasing: Bool = true,
       zip: Bool = false) {
    self.name = name
    self.isClosedSource = isClosedSource
    self.isBeta = isBeta
    self.allowWarnings = allowWarnings
    self.platforms = platforms
    self.releasing = releasing
    self.zip = zip
  }

  public func podspecName() -> String {
    return isClosedSource ? "\(name).podspec.json" : "\(name).podspec"
  }

  /// The Firebase pod does not support import validation with Xcode 12 because of the deprecated
  /// ML pods not supporting the ARM Mac slice.
  public func skipImportValidation() -> String {
    if name == "Firebase" {
      return "--skip-import-validation"
    } else {
      return ""
    }
  }
}
