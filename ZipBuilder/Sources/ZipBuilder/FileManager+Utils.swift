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
  public enum SearchFileType {
    /// All files with the `.storyboard` extension.
    case storyboards

    /// All folders with a `.bundle` extension.
    case bundles

    /// All folders with a `.framework` extension.
    case frameworks

    /// A directory with an optional name. If name is `nil`, all directories will be matched.
    case directories(name: String?)
  }

  // MARK: - Error Declarations

  /// Errors that can be used to propagate up through the script related to files.
  public enum FileError: Error {
    case directoryNotFound(path: String)
    case failedToCreateDirectory(path: String, error: Error)
    case writeToFileFailed(file: String, error: Error)
  }

  /// Errors that can occur during a recursive search operation.
  public enum RecursiveSearchError: Error {
    case failedToCreateEnumerator(forDirectory: URL)
  }

  // MARK: - Directory Management

  /// Convenience function to determine if there's a directory at the given file URL using existing
  /// FileManager calls.
  public func directoryExists(at url: URL) -> Bool {
    var isDir: ObjCBool = false
    let exists = fileExists(atPath: url.path, isDirectory: &isDir)
    return exists && isDir.boolValue
  }

  /// Convenience function to determine if a given file URL is a directory.
  public func isDirectory(at url: URL) -> Bool {
    return directoryExists(at: url)
  }

  /// Returns a deterministic path of a temporary directory for the given name. Note: This does
  /// *not* create the directory if it doesn't exist, merely generates the name for creation.
  public func temporaryDirectory(withName name: String) -> URL {
    // Get access to the temporary directory.
    let tempDir: URL
    if #available(OSX 10.12, *) {
      tempDir = temporaryDirectory
    } else {
      tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
    }

    // Organize all temporary directories into a "FirebaseZipRelease" directory.
    let firebaseDir = tempDir.appendingPathComponent("FirebaseZipRelease", isDirectory: true)
    return firebaseDir.appendingPathComponent(name, isDirectory: true)
  }

  /// Returns the URL to the Firebase cache directory, and creates it if it doesn't exist.
  public func firebaseCacheDirectory() throws -> URL {
    let cacheDir: URL
    do {
      // Get the URL for the cache directory.
      cacheDir = try url(for: .cachesDirectory,
                             in: .userDomainMask,
                             appropriateFor: nil,
                             create: true)
    } catch {
      throw error
    }

    // Get the cache root path, and if it already exists just return the URL.
    let cacheRoot = cacheDir.appendingPathComponent("firebase_oss_framework_cache")
    if directoryExists(at: cacheRoot) {
      return cacheRoot
    }

    // The cache root folder doesn't exist yet, create it!
    do {
      // Create the directory
      try createDirectory(at: cacheRoot, withIntermediateDirectories: false, attributes: nil)
    } catch {
      throw error
    }

    return cacheRoot
  }

  // MARK: Searching

  /// Recursively search for a set of items in a particular directory.
  public func recursivelySearch(for type: SearchFileType, in dir: URL) throws -> [URL] {
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
    while let fileURL = dirEnumerator.nextObject() as? URL {
      switch type {
      case .directories(let name):
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
      case .storyboards:
        // The only thing of interest is the path extension being ".storyboard".
        if fileURL.pathExtension == "storyboard" {
          matches.append(fileURL)
        }
      case .frameworks:
        // We care if it's a directory and has a .framework extension.
        if directoryExists(at: fileURL) && fileURL.pathExtension == "framework" {
          matches.append(fileURL)
        }
      }
    }

    return matches
  }
}
