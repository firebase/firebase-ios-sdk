import Foundation

import ShellUtils

class CocoapodsReader: PackageReader {
  func packagesInDirectory(_ dirURL: URL) throws -> [PackageData] {

    return try podspecURLs(at: dirURL)
      .compactMap { (podspecURL) -> PackageData? in
      print("podspecURL: \(podspecURL)")
        return try parsePodspec(at: podspecURL).packageData()
    }
  }

  private func podspecURLs(at dirURL: URL) throws -> [URL] {
    return try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [])
      .filter { (itemURL) -> Bool in
        return itemURL.pathExtension == "podspec"
    }
  }

  private func parsePodspec(at podspecURL: URL) throws -> PodspecData {
    let workingDir = podspecURL.deletingLastPathComponent()
    let podspecFileName = podspecURL.lastPathComponent

    let command = "pod ipc spec \(podspecFileName)"
    let result = Shell.executeCommandFromScript(command, outputToConsole: false, workingDir: workingDir)

    switch result {
    case .error(let code, let output):
      throw ParseError.podspecToJSONFailure(code: code, output: output)
    case .success(let jsonString):
      return try parse(jsonPodspec: jsonString)
    }
  }

  private func parse(jsonPodspec: String) throws -> PodspecData {
    let decoder = JSONDecoder()
    return try decoder.decode(PodspecData.self, from: jsonPodspec.data(using: .utf8) ?? Data())
  }
  
}

extension CocoapodsReader {
  enum ParseError: Error {
    case podspecToJSONFailure(code: Int32, output: String)
  }
}

struct PodspecData: Decodable {
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

  func packageData() -> PackageData? {
    return PackageData(podspec: self)
  }
}

extension PackageData {
  init?(podspec: PodspecData) {
    type = .cocoapods

    name = podspec.name
    version = podspec.version

    // TODO:
    publicHeaderPaths = podspec.publicHeaderPaths
    sourceFilePaths = podspec.sourceFilePaths
  }
}
