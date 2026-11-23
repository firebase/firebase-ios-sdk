/*
 * Copyright 2026 Google LLC
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
import Testing
@testable import ZipBuilder

struct MetadataTests {
  @Test func metadataListsFoldersBaseFirstAndVersions() {
    var plan = SyntheticPackage.plan
    plan.folders = [
      Folder(name: ".", frameworks: [], files: ["CoreOnly/NOTICES"]),
      Folder(name: "Base", frameworks: ["Bin", "A"], files: []),
      Folder(name: "Other", frameworks: ["B"], files: ["Crashlytics/run"]),
      Folder(name: "Another", frameworks: ["C", "B"], files: []),
    ]
    #expect(metadata(plan, baseFolder: "Base") == """
    ## Dependency Graph

    "(~> X)" below means that the SDK requires all of the xcframeworks from X. You
    should make sure to include all of the xcframeworks from X when including the
    SDK.

    ## Base
    - A.xcframework
    - Bin.xcframework

    ## Other (~> Base)
    - B.xcframework

    ## Another (~> Base)
    - B.xcframework
    - C.xcframework

    ## Versions

    The xcframeworks in this directory map to these versions of the Firebase SDKs in
    CocoaPods.

    Framework | Version
    ----------|---------
    A         | 1.0.0
    B         | 1.0.0
    Bin       | 2.0
    C         | 1.0.0

    """)
    // Without a base folder (or one that isn't in the plan), no folder is marked.
    let unmarked = metadata(plan, baseFolder: "Nope")
    #expect(!unmarked.contains("(~> Nope)"))
    #expect(unmarked.contains("## Base\n- A.xcframework\n- Bin.xcframework\n\n## Other\n"))
  }

  /// The "Framework" heading is centered over the name column, which is one wider than the
  /// longest name; an odd extra space goes on the right.
  @Test func versionHeadingIsCenteredOverLongNames() {
    var plan = SyntheticPackage.plan
    plan.folders = []
    plan.binaries = []
    plan.frameworks = [SyntheticPackage.framework("FirebaseCore")]
    // 12 characters: a 13-wide column, 2 spaces on each side.
    #expect(metadata(plan, baseFolder: nil).hasSuffix("""
    CocoaPods.

      Framework  | Version
    -------------|---------
    FirebaseCore | 1.0.0

    """))

    plan.frameworks.append(SyntheticPackage.framework("FirebaseStorage"))
    plan.binaries = SyntheticPackage.plan.binaries
    // 15 characters: a 16-wide column, 3 spaces on the left and 4 on the right.
    #expect(metadata(plan, baseFolder: nil).hasSuffix("""
    CocoaPods.

       Framework    | Version
    ----------------|---------
    Bin             | 2.0
    FirebaseCore    | 1.0.0
    FirebaseStorage | 1.0.0

    """))
  }
}
