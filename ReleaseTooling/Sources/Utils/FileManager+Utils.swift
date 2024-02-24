/*
 * Copyright 2019 Google
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

// Extensions to FileManager that make scripting easier or cleaner for error reporting.
public extension FileManager {
  // MARK: - Helper Enum Declarations

  /// Describes a type of file to be searched for.
  enum SearchFileType {
    /// All files, not including folders.
    case allFiles

    /// All folders with a `.bundle` extension.
    case bundles

    /// A directory with an optional name. If name is `nil`, all directories will be matched.
    case directories(name: String?)

    /// All folders with a `.framework` extension.
    case frameworks

    /// All headers with a `.h` extension.
    case headers

    /// All files with the `.storyboard` extension.
    case storyboards
  }

  // MARK: - Error Declarations

  /// Errors that can be used to propagate up through the script related to files.
  enum FileError: Error {
    case directoryNotFound(path: String)
    case failedToCreateDirectory(path: String, error: Error)
    case writeToFileFailed(file: String, error: Error)
  }

  /// Errors that can occur during a recursive search operation.
  enum RecursiveSearchError: Error {
    case failedToCreateEnumerator(forDirectory: URL)
  }

  // MARK: - Directory Management

  /// Convenience function to determine if there's a directory at the given file URL using existing
  /// FileManager calls.
  func directoryExists(at url: URL) -> Bool {
    var isDir: ObjCBool = false
    let exists = fileExists(atPath: url.path, isDirectory: &isDir)
    return exists && isDir.boolValue
  }

  /// Convenience function to determine if a given file URL is a directory.
  func isDirectory(at url: URL) -> Bool {
    return directoryExists(at: url)
  }

  /// Returns the URL to the source Pod cache directory, and creates it if it doesn't exist.
  func sourcePodCacheDirectory(withSubdir subdir: String = "") throws -> URL {
    let cacheDir = FileManager.default.temporaryDirectory(withName: "cache")
    let cacheRoot = cacheDir.appendingPathComponents([subdir])
    if directoryExists(at: cacheRoot) {
      return cacheRoot
    }

    // The cache root folder doesn't exist yet, create it.
    try createDirectory(at: cacheRoot, withIntermediateDirectories: true)

    return cacheRoot
  }

  /// Removes a directory or file if it exists. This is helpful to clean up error handling for
  /// checks that
  /// shouldn't fail. The only situation this could potentially fail is permission errors or if a
  /// folder is open in Finder, and in either state the user needs to close the window or fix the
  /// permissions. A fatal error will be thrown in those situations.
  func removeIfExists(at url: URL) {
    guard directoryExists(at: url) || fileExists(atPath: url.path) else { return }

    do {
      try removeItem(at: url)
    } catch {
      fatalError("""
      Tried to remove directory \(url) but it failed - close any Finder windows and try again.
      Error: \(error)
      """)
    }
  }

  /// Enable a single unique temporary workspace per execution with a sortable and readable
  /// timestamp.
  private static func timeStamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
    return formatter.string(from: Date())
  }

  static let unique: String = timeStamp()

  /// Allow clients to override default location for temporary directory creation
  static var buildRoot: URL?
  static func registerBuildRoot(buildRoot: URL) {
    FileManager.buildRoot = buildRoot
  }

  /// Returns a deterministic path of a temporary directory for the given name. Note: This does
  /// *not* create the directory if it doesn't exist, merely generates the name for creation.
  func temporaryDirectory(withName name: String) -> URL {
    // Get access to the temporary directory. This could be passed in via `LaunchArgs`, or use the
    // default temporary directory.
    let tempDir: URL
    if let root = FileManager.buildRoot {
      tempDir = root
    } else
    if #available(OSX 10.12, *) {
      tempDir = temporaryDirectory
    } else {
      tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
    }

    // Organize all temporary directories into a "ZipRelease" directory.
    let unique = FileManager.unique
    let zipDir = tempDir.appendingPathComponent("ZipRelease/" + unique, isDirectory: true)
    return zipDir.appendingPathComponent(name, isDirectory: true)
  }

  // MARK: Searching

  /// Recursively search for a set of items in a particular directory.
  func recursivelySearch(for type: SearchFileType, in dir: URL) throws -> [URL] {
    // Throw an error so an appropriate error can be logged from the caller.

    guard directoryExists(at: dir) else {
      throw FileError.directoryNotFound(path: dir.path)
    }

    // We have a directory, create an enumerator to do a recursive search.
    let keys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
    guard let dirEnumerator = enumerator(at: dir, includingPropertiesForKeys: keys) else {
      // Throw an error so an appropriate error can be logged from the caller.
      throw RecursiveSearchError.failedToCreateEnumerator(forDirectory: dir)
    }

    // Recursively search using the enumerator, adding any matches to the array.
    var matches: [URL] = []
    var foundXcframework = false // Ignore .frameworks after finding an xcframework.
    for case let fileURL as URL in dirEnumerator {
      // Never mess with Privacy.bundles
      if fileURL.lastPathComponent.hasSuffix("_Privacy.bundle") {
        dirEnumerator.skipDescendants()
        continue
      }

      switch type {
      case .allFiles:
        // Skip directories, include everything else.
        guard !isDirectory(at: fileURL) else { continue }

        matches.append(fileURL)
      case let .directories(name):
        // Skip any non-directories.
        guard directoryExists(at: fileURL) else { continue }

        // Get the name of the directory we're searching for. If there's not a specific name
        // being searched for, add it as a match and move on.
        guard let name = name else {
          matches.append(fileURL)
          continue
        }

        // If the last path component is a match, it's a directory we're looking for!
        if fileURL.lastPathComponent == name {
          matches.append(fileURL)
        }
      case .bundles:
        // The only thing of interest is the path extension being ".bundle".
        if fileURL.pathExtension == "bundle" {
          matches.append(fileURL)
        }
      case .headers:
        if fileURL.pathExtension == "h" {
          matches.append(fileURL)
        }
      case .storyboards:
        // The only thing of interest is the path extension being ".storyboard".
        if fileURL.pathExtension == "storyboard" {
          matches.append(fileURL)
        }
      case .frameworks:
        // We care if it's a directory and has a .xcframework or .framework extension.
        if directoryExists(at: fileURL) {
          if fileURL.pathExtension == "xcframework" {
            matches.append(fileURL)
            foundXcframework = true
          } else if !foundXcframework, fileURL.pathExtension == "framework" {
            matches.append(fileURL)
          }
        }
      }
    }
    return matches
  }
}
