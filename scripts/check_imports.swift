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

// For more context, see https://github.com/firebase/firebase-ios-sdk/blob/main/HeadersImports.md.

import Foundation

// Skip these directories. Imports should only be repo-relative in libraries
// and unit tests.
let skipDirPatterns = ["/Sample/", "/Pods/",
                       "FirebaseInAppMessaging/Tests/Integration/",
                       "FirebaseAuth/",
                       // TODO: Turn Combine back on without Auth includes.
                       "FirebaseCombineSwift/Tests/Unit/FirebaseCombine-unit-Bridging-Header.h",
                       "SymbolCollisionTest/", "/gen/",
                       "IntegrationTesting/CocoapodsIntegrationTest/",
                       "FirebasePerformance/Tests/TestApp/",
                       "cmake-build-debug/", "build/", "ObjCIntegration/",
                       "FirebasePerformance/Tests/FIRPerfE2E/",
                       "Carthage/"] +
  [
    "CoreOnly/Sources", // Skip Firebase.h.
    "SwiftPMTests", // The SwiftPM tests test module imports.
    "IntegrationTesting/ClientApp", // The ClientApp tests module imports.
    "FirebaseSessions/Protogen/", // Generated nanopb code with imports
  ] +

  // The following are temporary skips pending working through a first pass of the repo:
  [
    "FirebaseDatabase/Sources/third_party/Wrap-leveldb", // Pending SwiftPM for leveldb.
    "Example",
    "Firestore",
    "FirebasePerformance/ProtoSupport/",
  ]

// Skip existence test for patterns that start with the following:
let skipImportPatterns = [
  "FBLPromise",
  "OCMock",
  "OCMStubRecorder",
  "nanopb",
  "pb.h",
  "pb_",
  "leveldb/",
  "SRWebSocket",
  "unwind.h",
  "libunwind",
]

private class HeaderIndex {
  static let shared = HeaderIndex()

  private var productHeaders: [String: Set<String>] = [:]
  private var allHeaders: Set<String> = []
  private var initialized = false

  func initialize(repoURL: URL) {
    guard !initialized else { return }
    initialized = true

    let ignoredDirs = [".build", "Pods", ".git", "Carthage", "build", "DerivedData"]

    guard let contents = try? FileManager.default.contentsOfDirectory(
      at: repoURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    else { return }

    for rootURL in contents {
      guard rootURL.hasDirectoryPath else { continue }
      let dirName = rootURL.lastPathComponent
      if ignoredDirs.contains(dirName) { continue }

      var headerSet = Set<String>()
      let enumerator = FileManager.default.enumerator(atPath: rootURL.path)
      while let file = enumerator?.nextObject() as? String {
        if file.hasSuffix(".h") || file.hasSuffix(".hpp") {
          headerSet.insert(file)
          let filename = URL(fileURLWithPath: file).lastPathComponent
          headerSet.insert(filename)
          allHeaders.insert(filename)
        }
      }
      productHeaders[dirName] = headerSet
    }
  }

  func headerExists(_ importRaw: String, inProduct product: String, fileDir: URL,
                    repoURL: URL) -> Bool {
    // 1. Direct file existence relative to file directory
    if FileManager.default.fileExists(atPath: fileDir.appendingPathComponent(importRaw).path) {
      return true
    }

    // 2. Direct file existence relative to repo root
    if FileManager.default.fileExists(atPath: repoURL.appendingPathComponent(importRaw).path) {
      return true
    }

    // 3. Check inside the product's headers (and SharedTestUtilities)
    let headerName = URL(fileURLWithPath: importRaw).lastPathComponent
    for prod in [
      product,
      "SharedTestUtilities",
      "Crashlytics",
      "FirebaseCore",
      "FirebaseCoreExtension",
    ] {
      if let set = productHeaders[prod] {
        if set.contains(headerName) || set.contains(importRaw) {
          return true
        }
        for path in set {
          if path.hasSuffix(importRaw) || path.hasSuffix("/" + importRaw) {
            return true
          }
        }
      }
    }

    // 4. Check if it's anywhere in repo
    if allHeaders.contains(headerName) {
      return true
    }

    return false
  }
}

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

private func checkFile(_ file: String, logger: ErrorLogger, inRepo repoURL: URL,
                       isSwiftFile: Bool) {
  var fileContents = ""
  do {
    fileContents = try String(contentsOfFile: file, encoding: .utf8)
  } catch {
    logger.log("Could not read \(file). \(error)")
    // Not a source file, give up and return.
    return
  }

  guard !isSwiftFile else {
    // Swift specific checks.
    fileContents.components(separatedBy: .newlines)
      .enumerated() // [(lineNum, line), ...]
      .filter { $1.starts(with: "import FirebaseCoreExtension") }
      .forEach { lineNum, line in
        logger
          .importLog(
            "Use `internal import FirebaseCoreExtension` when importing `FirebaseCoreExtension`.",
            file, lineNum
          )
      }
    return
  }

  let isPublic = file.range(of: "/Public/") != nil &&
    // TODO: Skip legacy GDTCCTLibrary file that isn't Public and should be moved.
    // This test is used in the GoogleDataTransport's repo's CI clone of this repo.
    file.range(of: "GDTCCTLibrary/Public/GDTCOREvent+GDTCCTSupport.h") == nil
  let isPrivate = file.range(of: "/Sources/Private/") != nil ||
    // Delete when FirebaseInstallations fixes directory structure.
    file.range(of: "Source/Library/Private/FirebaseInstallationsInternal.h") != nil ||
    file.range(of: "FirebaseCore/Sources/FIROptionsInternal.h") != nil ||
    file.range(of: "FirebaseCore/Extension") != nil

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
    }

    // "The #else of a SWIFT_PACKAGE check should only do CocoaPods module-style imports."
    if line.starts(with: "#import") || line.starts(with: "#include") {
      let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
      guard components.count >= 2 else { continue }
      let importFile = components[1]
      if inSwiftPackageElse {
        if importFile.first != "<" {
          // SharedTestUtilities files are included directly in test targets and
          // use repo-relative imports.
          if !file.contains("SharedTestUtilities/") {
            logger
              .importLog("Import in SWIFT_PACKAGE #else should start with \"<\".", file, lineNum)
          }
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
        } else {
          // Verify header existence for internal imports.
          if importFileRaw.hasSuffix("-Swift.h") {
            continue nextLine
          }
          for skip in skipImportPatterns {
            if importFileRaw.starts(with: skip) {
              continue nextLine
            }
          }

          let fileURL = URL(fileURLWithPath: file)
          let fileDir = fileURL.deletingLastPathComponent()
          let relativePath = file.replacingOccurrences(of: repoURL.path + "/", with: "")
          let productDirName = relativePath.components(separatedBy: "/").first ?? ""

          let found = HeaderIndex.shared.headerExists(
            importFileRaw,
            inProduct: productDirName,
            fileDir: fileDir,
            repoURL: repoURL
          )

          if !found {
            if !isPrivate || importFile.contains("/") {
              logger.importLog("Import \(importFileRaw) does not exist.", file, lineNum)
            }
          }
        }
      } else if importFile.first == "<" {
        // Modular bracket imports should follow <ModuleName/Header.h> or system/third_party
        // headers.
        if !importFileRaw.contains("/"), !importFileRaw.hasSuffix(".h") {
          continue
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

  HeaderIndex.shared.initialize(repoURL: repoURL)

  guard let contents = try? FileManager.default.contentsOfDirectory(
    at: repoURL,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
  )
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
          file.hasSuffix(".c") ||
          file.hasSuffix(".swift")) {
          continue
        }
        let fullTransformPath = rootURL.path + "/" + file
        for dirPattern in skipDirPatterns {
          if fullTransformPath.range(of: dirPattern) != nil {
            continue whileLoop
          }
        }
        checkFile(
          fullTransformPath,
          logger: logger,
          inRepo: repoURL,
          isSwiftFile: file.hasSuffix(".swift")
        )
      }
    }
  }
  return logger.foundError ? 1 : 0
}

exit(main())
