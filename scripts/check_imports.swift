#!/usr/bin/swift
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

// Utility script for verifying `import` and `include` syntax. This ensures a
// consistent style as well as functionality across multiple package managers.

// For more context, see https://github.com/firebase/firebase-ios-sdk/blob/master/HeadersImports.md.

import Foundation

// Skip these directories. Imports should only be repo-relative in libraries
// and unit tests.
let skipDirPatterns = ["/Sample/", "/Pods/", "FirebaseStorage/Tests/Integration",
                       "FirebaseDynamicLinks/Tests/Integration",
                       "FirebaseInAppMessaging/Tests/Integration/",
                       "SymbolCollisionTest/", "/gen/",
                       "CocoapodsIntegrationTest/", "FirebasePerformance/Tests/TestApp/",
                       "cmake-build-debug/", "build/",
                       "FirebasePerformance/Tests/FIRPerfE2E/"] +
  [
    "CoreOnly/Sources", // Skip Firebase.h.
    "SwiftPMTests", // The SwiftPM imports test module imports.
  ] +

  // The following are temporary skips pending working through a first pass of the repo:
  [
    "FirebaseAppDistribution",
    "FirebaseCore/Sources/Private", // TODO: work through adding this back.
    "Firebase/CoreDiagnostics",
    "FirebaseDatabase/Sources/third_party/Wrap-leveldb", // Pending SwiftPM for leveldb.
    "Example",
    "FirebaseInstallations/Source/Tests/Unit/",
    "Firestore",
    "GoogleUtilitiesComponents",
    "FirebasePerformance/ProtoSupport/",
  ]

// Skip existence test for patterns that start with the following:
let skipImportPatterns = [
  "FBLPromise",
  "OCMock",
  "OCMStubRecorder",
]

private class ErrorLogger {
  var foundError = false
  func log(_ message: String) {
    print(message)
    foundError = true
  }

  func importLog(_ message: String, _ file: String, _ line: Int) {
    log("Import Error: \(file):\(line) \(message)")
  }
}

private func checkFile(_ file: String, logger: ErrorLogger, inRepo repoURL: URL) {
  var fileContents = ""
  do {
    fileContents = try String(contentsOfFile: file, encoding: .utf8)
  } catch {
    logger.log("Could not read \(file). \(error)")
    // Not a source file, give up and return.
    return
  }
  let isPublic = file.range(of: "/Public/") != nil &&
    // TODO: Skip legacy GDTCCTLibrary file that isn't Public and should be moved.
    file.range(of: "GDTCCTLibrary/Public/GDTCOREvent+GDTCCTSupport.h") == nil
  let isPrivate = file.range(of: "/Sources/Private/") != nil ||
    // Delete when FirebaseInstallations fixes directory structure.
    file.range(of: "Source/Library/Private/FirebaseInstallationsInternal.h") != nil ||
    file.range(of: "GDTCORLibrary/Internal/GoogleDataTransportInternal.h") != nil

  // Treat all files with names finishing on "Test" or "Tests" as files with tests.
  let isTestFile = file.contains("Test.m") || file.contains("Tests.m") ||
    file.contains("Test.swift") || file.contains("Tests.swift")
  let isBridgingHeader = file.contains("Bridging-Header.h")
  var inSwiftPackage = false
  var inSwiftPackageElse = false
  let lines = fileContents.components(separatedBy: .newlines)
  var lineNum = 0
  nextLine: for rawLine in lines {
    let line = rawLine.trimmingCharacters(in: .whitespaces)
    lineNum += 1
    if line.starts(with: "#if SWIFT_PACKAGE") {
      inSwiftPackage = true
    } else if inSwiftPackage, line.starts(with: "#else") {
      inSwiftPackage = false
      inSwiftPackageElse = true
    } else if inSwiftPackageElse, line.starts(with: "#endif") {
      inSwiftPackageElse = false
    } else if inSwiftPackage {
      continue
    } else if file.contains("FirebaseTestingSupport") {
      // Module imports ok in SPM only test infrastructure.
      continue
    } else if line.starts(with: "@import") {
      // "@import" is only allowed for Swift Package Manager.
      logger.importLog("@import should not be used in CocoaPods library code", file, lineNum)
    }

    // "The #else of a SWIFT_PACKAGE check should only do CocoaPods module-style imports."
    if line.starts(with: "#import") || line.starts(with: "#include") {
      let importFile = line.components(separatedBy: " ")[1]
      if inSwiftPackageElse {
        if importFile.first != "<" {
          logger
            .importLog("Import in SWIFT_PACKAGE #else should start with \"<\".", file, lineNum)
        }
        continue
      }
      let importFileRaw = importFile.replacingOccurrences(of: "\"", with: "")
        .replacingOccurrences(of: "<", with: "")
        .replacingOccurrences(of: ">", with: "")

      if importFile.first == "\"" {
        // Public Headers should only use simple file names without paths.
        if isPublic {
          if importFile.contains("/") {
            logger.importLog("Public header import should not include \"/\"", file, lineNum)
          }

        } else if !FileManager.default.fileExists(atPath: repoURL.path + "/" + importFileRaw) {
          // Non-public header imports should be repo-relative paths. Unqualified imports are
          // allowed in private headers.
          if !isPrivate || importFile.contains("/") {
            for skip in skipImportPatterns {
              if importFileRaw.starts(with: skip) {
                continue nextLine
              }
            }
            logger.importLog("Import \(importFileRaw) does not exist.", file, lineNum)
          }
        }
      } else if importFile.first == "<", !isPrivate, !isTestFile, !isBridgingHeader, !isPublic {
        // Verify that double quotes are always used for intra-module imports.
        if importFileRaw.starts(with: "Firebase") {
          logger
            .importLog("Imports internal to the repo should use double quotes not \"<\"", file,
                       lineNum)
        }
      }
    }
  }
}

private func main() -> Int32 {
  let logger = ErrorLogger()
  // Search the path upwards to find the root of the firebase-ios-sdk repo.
  var url = URL(fileURLWithPath: FileManager().currentDirectoryPath)
  while url.path != "/" {
    let script = url.appendingPathComponent("scripts/check_imports.swift")
    if FileManager.default.fileExists(atPath: script.path) {
      break
    }
    url = url.deletingLastPathComponent()
  }
  let repoURL = url
  guard let contents = try? FileManager.default.contentsOfDirectory(at: repoURL,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles])
  else {
    logger.log("Failed to get repo contents \(repoURL)")
    return 1
  }

  for rootURL in contents {
    if !rootURL.hasDirectoryPath {
      continue
    }
    let enumerator = FileManager.default.enumerator(atPath: rootURL.path)
    whileLoop: while let file = enumerator?.nextObject() as? String {
      if let fType = enumerator?.fileAttributes?[FileAttributeKey.type] as? FileAttributeType,
         fType == .typeRegular {
        if file.starts(with: ".") {
          continue
        }
        if !(file.hasSuffix(".h") ||
          file.hasSuffix(".m") ||
          file.hasSuffix(".mm") ||
          file.hasSuffix(".c")) {
          continue
        }
        let fullTransformPath = rootURL.path + "/" + file
        for dirPattern in skipDirPatterns {
          if fullTransformPath.range(of: dirPattern) != nil {
            continue whileLoop
          }
        }
        checkFile(fullTransformPath, logger: logger, inRepo: repoURL)
      }
    }
  }
  return logger.foundError ? 1 : 0
}

exit(main())
