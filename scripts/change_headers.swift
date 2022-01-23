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
let findHeaders = ["FirebaseMessaging"]

// Update with directories in which to change imports.
let changeImports = ["GoogleUtilities", "FirebaseAuth", "FirebaseCore", "Firebase",
                     "FirebaseDatabase", "GoogleDataTransport",
                     "FirebaseDynamicLinks", "FirebaseInAppMessaging", "FirebaseMessaging",
                     "FirebaseRemoteConfig", "FirebaseInstallations", "FirebaseFunctions",
                     "FirebaseABTesting",
                     "FirebaseAppDistribution", "Example", "Crashlytics", "FirebaseStorage"]

// Skip these directories. Imports should only be repo-relative in libraries
// and unit tests.
let skipDirPatterns = ["/Sample/", "/Pods/", "FirebaseStorage/Tests/Integration",
                       "FirebaseInAppMessaging/Tests/Integration/",
                       ".build/"]

// Get a Dictionary mapping a simple header name to a repo-relative path.

func getHeaderMap(_ url: URL) -> [String: String] {
  var headerMap = [String: String]()
  for root in findHeaders {
    let rootURL = url.appendingPathComponent(root)
    let enumerator = FileManager.default.enumerator(atPath: rootURL.path)
    while let file = enumerator?.nextObject() as? String {
      if let fType = enumerator?.fileAttributes?[FileAttributeKey.type] as? FileAttributeType,
         fType == .typeRegular {
        if let url = URL(string: file) {
          let filename = url.lastPathComponent
          if filename.hasSuffix(".h") {
            headerMap[filename] = root + "/" + file
          }
        }
      }
    }
  }
  return headerMap
}

func getImportFile(_ line: String) -> String? {
  return line.components(separatedBy: " ")[1]
    .replacingOccurrences(of: "\"", with: "")
    .replacingOccurrences(of: "<", with: "")
    .replacingOccurrences(of: ">", with: "")
    .components(separatedBy: "/").last
}

func transformFile(_ file: String) {
  var fileContents = ""
  do {
    fileContents = try String(contentsOfFile: file, encoding: .utf8)
  } catch {
    print("Could not read \(file). \(error)")
    // Not a source file, give up and return.
    return
  }
  var outBuffer = ""
  var inSwiftPackage = false
  let lines = fileContents.components(separatedBy: .newlines)
  for line in lines {
    if line.starts(with: "#if SWIFT_PACKAGE") {
      inSwiftPackage = true
    } else if inSwiftPackage, line.starts(with: "#else") {
      inSwiftPackage = false
    } else if line.starts(with: "@import") {
      if !inSwiftPackage {
        fatalError("@import should not be used in CocoaPods library code: \(file):\(line)")
      }
    }
    if line.starts(with: "#import"),
       let importFile = getImportFile(line),
       let path = headerMap[importFile] {
      outBuffer += "#import \"\(path)\"\n"
    } else if line.starts(with: "#include"),
              let importFile = getImportFile(line),
              let path = headerMap[importFile] {
      outBuffer += "#include \"\(path)\"\n"
    } else {
      outBuffer += line + "\n"
    }
  }
  // Write out the changed file.
  do {
    try outBuffer.dropLast()
      .write(toFile: file, atomically: false, encoding: String.Encoding.utf8)
  } catch {
    fatalError("Failed to write \(file). \(error)")
  }
}

// Search the path upwards to find the root of the firebase-ios-sdk repo.
var url = URL(fileURLWithPath: FileManager().currentDirectoryPath)
while url.path != "/", url.lastPathComponent != "firebase-ios-sdk" {
  url = url.deletingLastPathComponent()
}

print(url)

// Build map of all headers.

let headerMap = getHeaderMap(url)

// print(headerMap)

for root in changeImports {
  let rootURL = url.appendingPathComponent(root)
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
      let fullTransformPath = root + "/" + file
      for dirPattern in skipDirPatterns {
        if fullTransformPath.range(of: dirPattern) != nil {
          continue whileLoop
        }
      }
      transformFile(fullTransformPath)
    }
  }
}
