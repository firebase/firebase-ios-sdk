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

// Utility script for updating to repo-relative headers.

import Foundation

// Update with directories in which to find headers.
let findHeaders = ["FirebaseInstallations"]

// Update with directories in which to change imports.
let changeImports = ["GoogleUtilities", "FirebaseAuth", "FirebaseCore", "Firebase",
                     "FirebaseDynamicLinks", "FirebaseInAppMessaging", "FirebaseMessaging",
                     "FirebaseRemoteConfig", "FirebaseInstallations",
                     "FirebaseAppDistribution", "Example", "Crashlytics"]

// Skip these directories. Imports should only be repo-relative in libraries
// and unit tests.
let skipDirPatterns = ["/Sample/", "/Pods/", "FirebaseABTesting/Tests/Integration",
                       "FirebaseInAppMessaging/Tests/Integration/", "Example/Database/App",
                       "Example/InstanceID/App", "SymbolCollisionTest/", "/gen/",
                       "CocoapodsIntegrationTest/"] +

  // The following are temporary skips pending working through a first pass of the repo:
  [
    "FirebaseAppDistribution",
    "FirebaseDynamicLinks",
    "Firebase/CoreDiagnostics",
    "Firebase/Database",
    "Example",
    "FirebaseInAppMessaging",
    "FirebaseInstallations/Source/Tests/Unit/",
    "Firebase/InstanceID",
    "FirebaseMessaging",
    "FirebaseRemoteConfig/Tests/",
    "FirebaseStorage",
    "Crashlytics",
    "Firestore",
    "Functions",
    "GoogleDataTransport",
    "GoogleUtilitiesComponents",
  ]

// Skip existence test for patterns that start with the following:
let skipImportPatterns = ["FBLPromise"]

func getImportFile(_ line: String) -> String? {
  return line.components(separatedBy: " ")[1]
    .replacingOccurrences(of: "\"", with: "")
    .replacingOccurrences(of: "<", with: "")
    .replacingOccurrences(of: ">", with: "")
    .components(separatedBy: "/").last
}

var foundError = false

func genError(_ message: String) {
  print(message)
  foundError = true
}

func checkFile(_ file: String) {
  var fileContents = ""
  do {
    fileContents = try String(contentsOfFile: file, encoding: .utf8)
  } catch {
    print("Could not read \(file). \(error)")
    // Not a source file, give up and return.
    return
  }
  var inSwiftPackage = false
  var inSwiftPackageElse = false
  let lines = fileContents.components(separatedBy: .newlines)
  var lineNum = 0
  nextLine: for line in lines {
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
    } else if line.starts(with: "@import") {
      genError("@import should not be used in CocoaPods library code: \(file):\(lineNum)")
    }
    if line.starts(with: "#import") || line.starts(with: "#include") {
      let importFile = line.components(separatedBy: " ")[1]
      if inSwiftPackageElse {
        if importFile.first != "<" {
          genError("Import error: \(file):\(lineNum) Import in SWIFT_PACKAGE #else should start with \"<\".")
        }
        continue
      }
      let importFileRaw = importFile.replacingOccurrences(of: "\"", with: "")
        .replacingOccurrences(of: "<", with: "")
        .replacingOccurrences(of: ">", with: "")
      if importFile.first == "\"" {
        if !FileManager.default.fileExists(atPath: repoURL.path + "/" + importFileRaw) {
          for skip in skipImportPatterns {
            if importFileRaw.starts(with: skip) {
              continue nextLine
            }
          }
          genError("Import error: \(file):\(lineNum) Import \(importFileRaw) does not exist.")
        }
      }
    }
  }
}

// Search the path upwards to find the root of the firebase-ios-sdk repo.
var url = URL(fileURLWithPath: FileManager().currentDirectoryPath)
while url.path != "/", url.lastPathComponent != "firebase-ios-sdk" {
  url = url.deletingLastPathComponent()
}

let repoURL = url

let contents =
  try FileManager.default.contentsOfDirectory(at: repoURL,
                                              includingPropertiesForKeys: nil,
                                              options: [.skipsHiddenFiles])

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
      if file.range(of: "/Public/") != nil {
        continue
      }
      let fullTransformPath = rootURL.path + "/" + file
      for dirPattern in skipDirPatterns {
        if fullTransformPath.range(of: dirPattern) != nil {
          continue whileLoop
        }
      }
      checkFile(fullTransformPath)
    }
  }
}

if foundError {
  exit(1)
} else {
  exit(0)
}
