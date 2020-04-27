import Foundation

protocol PackageReader {
  /// Returns package data in a specified directory with specified types.
  /// - Parameters:
  ///   - dirURL: A URL for directory in the local file system to scan for package definitions.
  /// - Returns: An array of package data objects.
  func packagesInDirectory(_ dirURL: URL) throws -> [PackageData]
}
