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

import ShellUtils

/// The  class reads package information from Pod Specs in the provided directory.
class CocoaPodsReader: PackageReader {
  func packagesInDirectory(_ dirURL: URL) throws -> [PackageData] {
    return try podSpecURLsInDirectory(dirURL)
      .compactMap { (podspecURL) -> PackageData? in
        print("podspecURL: \(podspecURL)")
        return try parsePodspec(at: podspecURL).packageData(baseDir: dirURL)
      }
  }

  private func podspecURLsInDirectory(dirURL: URL) throws -> [URL] {
    return try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [])
      .filter { (itemURL) -> Bool in
        itemURL.pathExtension == "podspec"
      }
  }

  private func parsePodspec(at podspecURL: URL) throws -> PodspecData {
    // Convert a .podspec file to JSON using CocoaPods `pod ipc` command.
    // See https://guides.cocoapods.org/terminal/commands.html#pod_ipc_spec for more details.
    let workingDir = podspecURL.deletingLastPathComponent()
    let podspecFileName = podspecURL.lastPathComponent

    let command = "pod ipc spec \(podspecFileName)"
    let result = Shell
      .executeCommandFromScript(command, outputToConsole: false, workingDir: workingDir)

    switch result {
    case let .error(code, output):
      throw ParseError.podspecToJSONFailure(code: code, output: output)
    case let .success(jsonString):
      return try parse(jsonPodspec: jsonString)
    }
  }

  private func parse(jsonPodspec: String) throws -> PodspecData {
    let decoder = JSONDecoder()
    return try decoder.decode(PodspecData.self, from: jsonPodspec.data(using: .utf8) ?? Data())
  }
}

extension CocoaPodsReader {
  enum ParseError: Error {
    case podspecToJSONFailure(code: Int32, output: String)
  }
}

/// The struct represents CocoaPods specific `PackageData`.
private struct PodspecData: Decodable {
  var name: String
  var version: PackageVersion

  var publicHeaderPaths: [Path]
  var privateHeaderPaths: [Path]
  var sourceFilePaths: [Path]

  enum CodingKeys: String, CodingKey {
    case name
    case version

    case publicHeaderPaths = "public_header_files"
    case privateHeaderPaths = "private_header_files"
    case sourceFilePaths = "source_files"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    name = try container.decode(String.self, forKey: .name)
    version = try container.decode(String.self, forKey: .version)

    let decodeStringOrArray = { (key: CodingKeys) throws -> [String] in
      if let string = try? container.decode(String.self, forKey: key) {
        return [string]
      } else {
        return try container.decode([String].self, forKey: key)
      }
    }

    publicHeaderPaths = try decodeStringOrArray(.publicHeaderPaths)
    privateHeaderPaths = try decodeStringOrArray(.privateHeaderPaths)
    sourceFilePaths = try decodeStringOrArray(.sourceFilePaths)
  }

  fileprivate func packageData(baseDir: URL) -> PackageData? {
    let basePath = baseDir.path

    let sourceFilePaths = glob(patterns: self.sourceFilePaths, basePath: basePath)
    let privateHeaderPaths = Set(glob(patterns: self.privateHeaderPaths, basePath: basePath))
    let publicAndPrivateHeadersPaths =
      Set(glob(patterns: self.publicHeaderPaths, basePath: basePath))
    let publicHeaderPaths = publicAndPrivateHeadersPaths.subtracting(privateHeaderPaths)

    return PackageData(name: name, type: .cocoaPods, version: version,
                       publicHeaderPaths: Array(publicHeaderPaths),
                       sourceFilePaths: sourceFilePaths)
  }

  private func glob(patterns: [String], basePath: String) -> [Path] {
    return patterns.flatMap { (pattern) -> [Path] in
      basePath.glob(pattern: pattern)
    }
    .map { path -> Path in
      var relativePath = path
      relativePath.removeFirst(basePath.count + 1) // +1 to remove "/"
      return relativePath
    }
  }
}
