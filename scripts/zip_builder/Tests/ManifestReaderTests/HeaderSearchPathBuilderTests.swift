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

@preconcurrency import Basics
import Common
import Foundation
@testable import ManifestReader
import Testing

struct HeaderSearchPathBuilderTests {
  // MARK: - Edge Case 1: Non-Standard Public Headers Directory

  @Test func exportedSearchPathsWithNanopbSpmHeaders() throws {
    let includeDir = "/repo/.build/checkouts/nanopb/spm_headers"
    let headerPaths = [
      "/repo/.build/checkouts/nanopb/spm_headers/pb.h",
      "/repo/.build/checkouts/nanopb/spm_headers/nanopb/pb.h",
    ]

    let exported = try HeaderSearchPathBuilder.exportedSearchPaths(
      includeDir: includeDir,
      headerPaths: headerPaths
    )

    #expect(exported.contains("/repo/.build/checkouts/nanopb/spm_headers"))
    #expect(exported.contains("/repo/.build/checkouts/nanopb/spm_headers/nanopb"))
  }

  @Test func exportedSearchPathsWithDotIncludeDir() throws {
    let includeDir = "/repo/FirebaseCore/Extension"
    let headerPaths = [
      "/repo/FirebaseCore/Extension/FIRAppInternal.h",
      "/repo/FirebaseCore/Extension/FIRHeartbeatLogger.h",
    ]

    let exported = try HeaderSearchPathBuilder.exportedSearchPaths(
      includeDir: includeDir,
      headerPaths: headerPaths
    )

    #expect(exported == ["/repo/FirebaseCore/Extension"])
  }

  // MARK: - Edge Case 2: Namespaced vs Flat Header Directories

  @Test func exportedSearchPathsWithNamespaceSubfolder() throws {
    let includeDir = "/repo/FirebaseCore/Sources/Public"
    let headerPaths = [
      "/repo/FirebaseCore/Sources/Public/FirebaseCore/FIRApp.h",
      "/repo/FirebaseCore/Sources/Public/FirebaseCore/FIRConfiguration.h",
      "/repo/FirebaseCore/Sources/Public/FirebaseCore/FirebaseCore.h",
    ]

    let exported = try HeaderSearchPathBuilder.exportedSearchPaths(
      includeDir: includeDir,
      headerPaths: headerPaths
    )

    #expect(exported == [
      "/repo/FirebaseCore/Sources/Public",
      "/repo/FirebaseCore/Sources/Public/FirebaseCore",
    ])
  }

  @Test func exportedSearchPathsFlatCHeaders() throws {
    let includeDir = "/repo/flatlib/include"
    let headerPaths = [
      "/repo/flatlib/include/lib.h",
      "/repo/flatlib/include/common.h",
    ]

    let exported = try HeaderSearchPathBuilder.exportedSearchPaths(
      includeDir: includeDir,
      headerPaths: headerPaths
    )

    #expect(exported == [
      "/repo/flatlib/include",
    ])
  }

  @Test func exportedSearchPathsDeepHierarchy() throws {
    let includeDir = "/repo/DeepModule/Sources/Public"
    let headerPaths = [
      "/repo/DeepModule/Sources/Public/DeepModule/Sub1/Sub2/DeepHeader.h",
    ]

    let exported = try HeaderSearchPathBuilder.exportedSearchPaths(
      includeDir: includeDir,
      headerPaths: headerPaths
    )

    #expect(exported.contains("/repo/DeepModule/Sources/Public"))
    #expect(exported.contains("/repo/DeepModule/Sources/Public/DeepModule/Sub1/Sub2"))
  }

  // MARK: - Edge Case 3: Sanitization and Exclusion

  @Test func sanitizationExcludesBuildAndCheckouts() throws {
    #expect(try HeaderSearchPathBuilder.validateSearchPath("/Users/dev/repo/.build") == nil)
    #expect(try HeaderSearchPathBuilder
      .validateSearchPath("/Users/dev/repo/.build/checkouts") == nil)
    #expect(try HeaderSearchPathBuilder.validateSearchPath("/Users/dev/repo/checkouts") == nil)
    #expect(try HeaderSearchPathBuilder.validateSearchPath("") == nil)
    #expect(try HeaderSearchPathBuilder.validateSearchPath("   ") == nil)

    #expect(
      try HeaderSearchPathBuilder.validateSearchPath("/Users/dev/repo/FirebaseCore/Sources/Public")
        == "/Users/dev/repo/FirebaseCore/Sources/Public"
    )
    #expect(
      try HeaderSearchPathBuilder.validateSearchPath("/Users/dev/repo/nanopb/spm_headers")
        == "/Users/dev/repo/nanopb/spm_headers"
    )

    let buildPath = try AbsolutePath(validating: "/Users/dev/repo/.build")
    let publicPath = try AbsolutePath(validating: "/Users/dev/repo/FirebaseCore/Sources/Public")
    #expect(HeaderSearchPathBuilder.validateSearchPath(buildPath) == nil)
    #expect(
      HeaderSearchPathBuilder.validateSearchPath(publicPath)
        == "/Users/dev/repo/FirebaseCore/Sources/Public"
    )
  }

  // MARK: - Edge Case 4: Private cSettings Not Leaked into Exported Search Paths

  @Test func targetLevelPrivateCSettingsNotLeakedToExportedPaths() throws {
    let moduleSources = [
      "/repo/FirebaseCore/Sources/FIRApp.m",
      "/repo/FirebaseCore/Sources/FIRBundleUtil.h",
      "/repo/FirebaseCore/Sources/Public/FirebaseCore/FIRApp.h",
    ]
    let includeDir = "/repo/FirebaseCore/Sources/Public"
    let explicitRepoRoot = "/repo" // from cSettings: [.headerSearchPath("../..")]

    let exportedPaths = try HeaderSearchPathBuilder.exportedSearchPaths(
      includeDir: includeDir,
      headerPaths: moduleSources.filter(\.isHeaderFile)
    )

    // Exported paths should ONLY contain public headers
    #expect(exportedPaths.contains("/repo/FirebaseCore/Sources/Public"))
    #expect(exportedPaths.contains("/repo/FirebaseCore/Sources/Public/FirebaseCore"))
    #expect(exportedPaths.contains("/repo") == false)
    #expect(exportedPaths.contains("/repo/FirebaseCore/Sources") == false)

    // Target's own build search paths MUST contain the explicit repo root and internal sources
    let targetBuildPaths = try HeaderSearchPathBuilder.buildTargetHeaderSearchPaths(
      ownHeaders: moduleSources.filter(\.isHeaderFile),
      explicitSearchPaths: [explicitRepoRoot],
      dependencySearchPaths: exportedPaths
    )

    #expect(targetBuildPaths.contains("/repo"))
    #expect(targetBuildPaths.contains("/repo/FirebaseCore/Sources"))
    #expect(targetBuildPaths.contains("/repo/FirebaseCore/Sources/Public"))
    #expect(targetBuildPaths.contains("/repo/FirebaseCore/Sources/Public/FirebaseCore"))
  }

  // MARK: - Edge Case 5: TargetDefinition Modeling and Aggregate Union

  @Test func targetDefinitionExportedHeaderSearchPaths() throws {
    let target = TargetDefinition(
      name: "FirebaseCore",
      c99name: "FirebaseCore",
      isBinary: false,
      sources: ["/repo/FirebaseCore/Sources/FIRApp.m"],
      headerSearchPaths: ["$(inherited)", "/repo/FirebaseCore/Sources/Public"],
      exportedHeaderSearchPaths: [
        "/repo/FirebaseCore/Sources/Public",
        "/repo/FirebaseCore/Sources/Public/FirebaseCore",
      ],
      publicHeadersPath: "/repo/FirebaseCore/Sources/Public"
    )

    #expect(target.exportedHeaderSearchPaths == [
      "/repo/FirebaseCore/Sources/Public",
      "/repo/FirebaseCore/Sources/Public/FirebaseCore",
    ])

    let data = try JSONEncoder().encode(target)
    let decoded = try JSONDecoder().decode(TargetDefinition.self, from: data)
    #expect(decoded.exportedHeaderSearchPaths == target.exportedHeaderSearchPaths)
  }

  @Test func targetDefinitionAggregateCombinesExportedSearchPaths() {
    let subtarget1 = TargetDefinition(
      name: "GoogleUtilities-Environment",
      c99name: "GoogleUtilities_Environment",
      isBinary: false,
      exportedHeaderSearchPaths: [
        "/repo/GoogleUtilities/Environment/Public",
        "/repo/GoogleUtilities/Environment/Public/GoogleUtilities",
      ]
    )
    let subtarget2 = TargetDefinition(
      name: "GoogleUtilities-Logger",
      c99name: "GoogleUtilities_Logger",
      isBinary: false,
      exportedHeaderSearchPaths: [
        "/repo/GoogleUtilities/Logger/Public",
        "/repo/GoogleUtilities/Logger/Public/GoogleUtilities",
      ]
    )

    let aggregate = TargetDefinition.aggregate(
      name: "GoogleUtilities",
      subtargets: [subtarget1, subtarget2]
    )

    #expect(aggregate.exportedHeaderSearchPaths == [
      "/repo/GoogleUtilities/Environment/Public",
      "/repo/GoogleUtilities/Environment/Public/GoogleUtilities",
      "/repo/GoogleUtilities/Logger/Public",
      "/repo/GoogleUtilities/Logger/Public/GoogleUtilities",
    ])
  }

  @Test func targetDefinitionUpdatingHeaderSearchPathsPreservesExportedPaths() {
    let original = TargetDefinition(
      name: "MyModule",
      c99name: "MyModule",
      isBinary: false,
      headerSearchPaths: ["/path/old"],
      exportedHeaderSearchPaths: ["/path/public"]
    )

    let updated = original.updatingHeaderSearchPaths(["/path/new"])
    #expect(updated.headerSearchPaths == ["/path/new"])
    #expect(updated.exportedHeaderSearchPaths == ["/path/public"])
  }

  // MARK: - Edge Case 6: Xcode Build Setting Macros

  @Test func validateSearchPathAllowsXcodeMacros() throws {
    #expect(try HeaderSearchPathBuilder.validateSearchPath("$(inherited)") == "$(inherited)")
    #expect(
      try HeaderSearchPathBuilder.validateSearchPath("$(PROJECT_DIR)/GeneratedModules")
        == "$(PROJECT_DIR)/GeneratedModules"
    )
    #expect(
      try HeaderSearchPathBuilder.validateSearchPath("$(PROJECT_DIR)/GeneratedModules/*")
        == "$(PROJECT_DIR)/GeneratedModules/*"
    )
    #expect(
      try HeaderSearchPathBuilder.validateSearchPath("$(BUILT_PRODUCTS_DIR)/CustomHeaders")
        == "$(BUILT_PRODUCTS_DIR)/CustomHeaders"
    )
    #expect(
      try HeaderSearchPathBuilder.validateSearchPath("${PODS_ROOT}/Headers/Public")
        == "${PODS_ROOT}/Headers/Public"
    )
  }

  @Test func buildTargetHeaderSearchPathsPreservesXcodeMacrosVerbatim() throws {
    let baseSearchPaths = [
      "$(inherited)",
      "$(PROJECT_DIR)/GeneratedModules",
      "$(PROJECT_DIR)/GeneratedModules/*",
    ]
    let explicitSearchPaths = [
      "$(BUILT_PRODUCTS_DIR)/SomeFramework/Headers",
      "/repo/CustomModule/include",
    ]
    let dependencySearchPaths = [
      "/repo/FirebaseCore/Sources/Public",
    ]
    let ownHeaders = [
      "/repo/MyTarget/Sources/PrivateHeader.h",
    ]

    let result = try HeaderSearchPathBuilder.buildTargetHeaderSearchPaths(
      ownHeaders: ownHeaders,
      explicitSearchPaths: explicitSearchPaths,
      dependencySearchPaths: dependencySearchPaths,
      baseSearchPaths: baseSearchPaths
    )

    // Macros MUST NOT be prefixed by file URL resolution or current working directory.
    #expect(result.contains("$(inherited)"))
    #expect(result.contains("$(PROJECT_DIR)/GeneratedModules"))
    #expect(result.contains("$(PROJECT_DIR)/GeneratedModules/*"))
    #expect(result.contains("$(BUILT_PRODUCTS_DIR)/SomeFramework/Headers"))

    // Concrete paths should be properly normalized and included.
    #expect(result.contains("/repo/CustomModule/include"))
    #expect(result.contains("/repo/FirebaseCore/Sources/Public"))
    #expect(result.contains("/repo/MyTarget/Sources"))

    // Verify none of the macro entries were prepended with working directory paths.
    for path in result {
      if path.contains("$(") {
        #expect(path.hasPrefix("$("), "Macro path should not have leading prefix: \(path)")
      }
    }
  }

  // MARK: - Edge Case 7: AbsolutePath Validation Failures Thrown

  @Test func exportedSearchPathsThrowsOnRelativeIncludeDir() {
    #expect(throws: (any Error).self) {
      try HeaderSearchPathBuilder.exportedSearchPaths(
        includeDir: "Sources/FirebaseCore/Public",
        headerPaths: []
      )
    }
  }

  @Test func exportedSearchPathsThrowsOnTildeIncludeDir() {
    #expect(throws: (any Error).self) {
      try HeaderSearchPathBuilder.exportedSearchPaths(
        includeDir: "~/Developer/repo/Public",
        headerPaths: []
      )
    }
  }

  @Test func exportedSearchPathsThrowsOnRelativeHeaderPath() {
    #expect(throws: (any Error).self) {
      try HeaderSearchPathBuilder.exportedSearchPaths(
        includeDir: "/repo/Sources/Public",
        headerPaths: ["relative/header.h"]
      )
    }
  }

  @Test func buildTargetHeaderSearchPathsThrowsOnRelativeExplicitPath() {
    #expect(throws: (any Error).self) {
      try HeaderSearchPathBuilder.buildTargetHeaderSearchPaths(
        explicitSearchPaths: ["relative/include/path"]
      )
    }
  }

  @Test func buildTargetHeaderSearchPathsThrowsOnTildeBasePath() {
    #expect(throws: (any Error).self) {
      try HeaderSearchPathBuilder.buildTargetHeaderSearchPaths(
        baseSearchPaths: ["~/Headers"]
      )
    }
  }

  @Test func buildTargetHeaderSearchPathsThrowsOnRelativeOwnHeader() {
    #expect(throws: (any Error).self) {
      try HeaderSearchPathBuilder.buildTargetHeaderSearchPaths(
        ownHeaders: ["relative/path/Header.h"]
      )
    }
  }

  @Test func validateSearchPathThrowsOnRelativeOrTildePath() {
    #expect(throws: (any Error).self) {
      try HeaderSearchPathBuilder.validateSearchPath("relative/path")
    }
    #expect(throws: (any Error).self) {
      try HeaderSearchPathBuilder.validateSearchPath("~/Developer/Headers")
    }
  }
}
