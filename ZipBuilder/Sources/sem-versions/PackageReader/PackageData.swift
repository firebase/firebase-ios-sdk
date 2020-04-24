import Foundation

enum PackageType {
  case cocoapods
  case swiftPM
}

// TODO: Consider using a specific type to represent semantic version
// like https://github.com/mxcl/Version
typealias PackageVersion = String

// TODO: Use something like https://github.com/kylef/PathKit
typealias Path = String

struct PackageData {
  var name: String
  var type: PackageType
  var version: PackageVersion

  var publicHeaderPaths: [Path]
  var sourceFilePaths: [Path]

  // TODO: Add necessary fields.
}
