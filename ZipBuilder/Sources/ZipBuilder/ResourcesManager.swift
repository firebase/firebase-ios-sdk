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

/// Functions related to managing resources. Intentionally empty, this enum is used as a namespace.
enum ResourcesManager {}

extension ResourcesManager {
  /// Recursively searches for Resources directories in `dir`, creates a `.bundle` and moves them
  /// to the Resources directory `resourceDir`.
  ///
  /// - Parameters:
  ///   - dir: The directory to search for Resource directories.
  ///   - resourceDir: The destination Resources directory. This function will create the Resources
  ///                  directory if it doesn't exist.
  public static func createBundleFromResources(inDirectory dir: URL,
                                               to destinationDir: URL) throws {
    let fileManager = FileManager.default
    let existingResources = try fileManager.recursivelySearch(for: .directories(name: "Resources"),
                                                              in: dir)

    // Only continue if there are Resources to bundle.
    guard !existingResources.isEmpty else { return }

    // Create the umbrella Resources folder if it doesn't exist.
    if !fileManager.directoryExists(at: destinationDir) {
      // Create a Resources directory if there is at least one bundle and the directory doesn't
      // already exist.
      try fileManager.createDirectory(at: destinationDir,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
    }

    // Move each of the Resources directories into their own bundle, compiling any storyboards along
    // the way.
    for resourceDir in existingResources {
      // Get the name of the .bundle to create by using the parent directory of the Resources dir -
      // it's the second last path component. Use that name plus "Resources.bundle".
      let name = resourceDir.deletingLastPathComponent().lastPathComponent + "Resources.bundle"
      let location = destinationDir.appendingPathComponent(name)

      // Copy the existing Resources folder to the new bundle location.
      try fileManager.copyItem(at: resourceDir, to: location)

      // Compile any storyboards that exist in the new bundle.
      compileStoryboards(inDir: location)
    }
  }

  /// Searches for and attempts to remove all empty "Resources" directories in a given directory.
  /// This is a recrusive search.
  ///
  /// - Parameter dir: The directory to recursively search for Resources directories in.
  public static func removeEmptyResourcesDirectories(in dir: URL) {
    // Find all the Resources directories to begin with.
    let fileManager = FileManager.default
    guard let resourceDirs = try? fileManager.recursivelySearch(for: .directories(name: "Resources"), in: dir) else {
      print("Attempted to remove empty resource directories, but it failed. This shouldn't be " +
            "classified as an error, but something to look out for.")
      return
    }

    // Get the contents of each directory and if it's empty, remove it.
    for resourceDir in resourceDirs {
      guard let contents = try? fileManager.contentsOfDirectory(atPath: resourceDir.path) else {
        print("WARNING: Failed to get contents of apparent Resources directory at \(resourceDir)")
        continue
      }

      // Remove the directory if it's empty. Only warn if it's not successful, since it's not a
      // requirement but a nice to have.
      if contents.isEmpty {
        do {
          try fileManager.removeItem(at: resourceDir)
        } catch {
          print("WARNING: Failed to remove empty Resources directory while cleaning up folder " +
                "heirarchy: \(error)")
        }
      }
    }
  }

  /// Finds and compiles all `.storyboard` files in a directory, removing the original file.
  private static func compileStoryboards(inDir dir: URL) {
    let fileManager = FileManager.default
    let storyboards: [URL]
    do {
      storyboards = try fileManager.recursivelySearch(for: .storyboards, in: dir)
    } catch {
      fatalError("Failed to search for storyboards in directory: \(error)")
    }

    // Compile each storyboard, then remove it.
    for storyboard in storyboards {
      // Compiled storyboards have the extension `storyboardc`.
      let compiledPath = storyboard.deletingPathExtension().appendingPathExtension("storyboardc")

      // Run the command and throw an error if it fails.
      let command = "ibtool --compile \(compiledPath.path) \(storyboard.path)"
      let result = Shell.executeCommandFromScript(command)
      switch result {
      case .success(_):
        // Remove the original storyboard file and continue.
        do {
          try fileManager.removeItem(at: storyboard)
        } catch {
          fatalError("Could not remove storyboard file \(storyboard) from bundle after " +
                     "compilation: \(error)")
        }
      case .error(let code, let output):
        fatalError("Failed to compile storyboard \(storyboard): error \(code) \(output)")
      }
    }
  }
}
