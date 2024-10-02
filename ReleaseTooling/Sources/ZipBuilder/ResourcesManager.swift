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
import Utils

/// Functions related to managing resources. Intentionally empty, this enum is used as a namespace.
enum ResourcesManager {}

extension ResourcesManager {
  /// Recursively searches a directory for any sign of resources: `.bundle` folders, or a non-empty
  /// directory called "Resources".
  ///
  /// - Parameter dir: The directory to search for any sign of resources.
  /// - Returns: True if any resources could be found, otherwise false.
  /// - Throws: A FileManager API that was thrown while searching.
  static func directoryContainsResources(_ dir: URL) throws -> Bool {
    // First search for any .bundle files.
    let fileManager = FileManager.default
    let bundles = try fileManager.recursivelySearch(for: .bundles, in: dir)

    // Stop searching if there were any bundles found.
    if !bundles.isEmpty { return true }

    // Next, search for any non-empty Resources directories.
    let existingResources = try fileManager.recursivelySearch(for: .directories(name: "Resources"),
                                                              in: dir)
    for resource in existingResources {
      let fileList = try fileManager.contentsOfDirectory(atPath: resource.path)
      if !fileList.isEmpty { return true }
    }

    // At this point: no bundles were found, and either there were no Resources directories or they
    // were all empty. Safe to say this directory doesn't contain any resources.
    return false
  }

  /// Packages all resources in a directory (recursively) - compiles them, puts them in a
  /// bundle, embeds them in the adjacent .framework file, and cleans up any empty Resources
  /// directories.
  ///
  /// - Parameters:
  ///   - fromDir: The directory to search for resources.
  ///   - toDir: The Resources directory to dump all resource bundles in.
  ///   - bundlesToRemove: Any bundles to remove (name of the bundle, not a full path).
  /// - Returns: True if any resources were moved and packaged, otherwise false.
  /// - Throws: Any file system errors that occur.
  @discardableResult
  static func packageAllResources(containedIn dir: URL,
                                  bundlesToIgnore: [String] = []) throws -> Bool {
    let resourcesFound = try directoryContainsResources(dir)

    // Quit early if there are no resources to deal with.
    if !resourcesFound { return false }

    let fileManager = FileManager.default

    // There are three possibilities for resources at this point:
    //   1. A `.bundle` could be packaged in a `Resources` directory inside of a framework.
    //      - We want to keep these where they are.
    //   2. A `.bundle` could be packaged in a `Resources` directory outside of a framework.
    //      - We want to move these into the framework adjacent to the `Resources` dir.
    //   3. A `Resources` directory that still needs to be compiled, outside of a framework.
    //      - These need to be compiled into `.bundles` and moved into the relevant framework
    //        directory.
    let allResourceDirs = try fileManager.recursivelySearch(for: .directories(name: "Resources"),
                                                            in: dir)
    for resourceDir in allResourceDirs {
      // Situation 1: Ignore any Resources directories that are already in the .framework.
      let parentDir = resourceDir.deletingLastPathComponent()
      guard parentDir.pathExtension != "framework" else {
        print("Found a Resources directory inside \(parentDir), no action necessary.")
        continue
      }

      // Store the paths to bundles that are found or newly assembled.
      var bundles: [URL] = []

      // Situation 2: Find any bundles that already exist but aren't included in the framework.
      bundles += try fileManager.recursivelySearch(for: .bundles, in: resourceDir)

      // Situation 3: Create any leftover bundles in this directory.
      bundles += try createBundles(fromDir: resourceDir)

      // Filter out any explicitly ignored bundles.
      bundles.removeAll(where: { bundlesToIgnore.contains($0.lastPathComponent) })

      // Find the right framework for these bundles to be embedded in - the folder structure is
      // likely:
      //   - ProductFoo
      //     - Frameworks
      //       - ProductFoo.framework
      //     - Resources
      //       - BundleFoo.bundle
      //       - BundleBar.bundle
      //       - etc.
      // If there are more than one frameworks in the "Frameworks" directory, we can try to match
      // the name of the bundle and the framework but if it doesn't match, fail because we don't
      // know what bundle the resources belong to. This isn't the case now for any Firebase products
      // but it's a good flag to raise in case that happens in the future.
      let frameworksDir = parentDir.appendingPathComponent("Frameworks")
      guard fileManager.directoryExists(at: frameworksDir) else {
        fatalError("Could not package resources in \(resourceDir): Frameworks directory doesn't " +
          "exist: \(frameworksDir)")
      }

      let contents = try fileManager.contentsOfDirectory(atPath: frameworksDir.path)
      switch contents.count {
      case 0:
        // No Frameworks exist.
        fatalError("Could not find framework file to package Resources in \(resourceDir). " +
          "\(frameworksDir) is empty.")
      case 1:
        // Force unwrap is fine here since we know the first one exists.
        let frameworkName = contents.first!
        let frameworkResources = frameworksDir.appendingPathComponents([frameworkName, "Resources"])

        // Move all the bundles into the Resources directory for that framework. This will create
        // the directory if it doesn't exist.
        try moveAllFiles(bundles, toDir: frameworkResources)
      default:
        // More than one framework is found. Try a last ditch effort of lining up the name, and if
        // that doesn't work fail out.
        for bundle in bundles {
          // Get the name of the bundle without any suffix.
          let name = bundle.lastPathComponent.replacingOccurrences(of: ".bundle", with: "")
          guard contents.contains(name) else {
            fatalError("Attempting to embed \(name).bundle into a framework but there are too " +
              "many frameworks to choose from in \(frameworksDir).")
          }

          // We somehow have a match, embed that bundle in the framework and try the next one!
          let frameworkResources = frameworksDir.appendingPathComponents([name, "Resources"])
          try moveAllFiles([bundle], toDir: frameworkResources)
        }
      }
    }

    // Let the caller know we've modified resources.
    return true
  }

  /// Recursively searches for bundles in `dir` and moves them to the Resources directory
  /// `resourceDir`.
  ///
  /// - Parameters:
  ///   - dir: The directory to search for Resource bundles.
  ///   - resourceDir: The destination Resources directory. This function will create the Resources
  ///                  directory if it doesn't exist.
  ///   - keepOriginal: Do a copy instead of a move.
  /// - Returns: An array of URLs pointing to the newly located bundles.
  /// - Throws: Any file system errors that occur.
  @discardableResult
  static func moveAllBundles(inDirectory dir: URL,
                             to resourceDir: URL,
                             keepOriginal: Bool = false) throws -> [URL] {
    let fileManager = FileManager.default
    let allBundles = try fileManager.recursivelySearch(for: .bundles, in: dir)

    // If no bundles are found, return an empty array since nothing was done (but there wasn't an
    // error).
    guard !allBundles.isEmpty else { return [] }

    // Move the found bundles into the Resources directory.
    let bundlesMoved = try moveAllFiles(allBundles, toDir: resourceDir, keepOriginal: keepOriginal)

    // Remove any empty Resources directories left over as part of the move.
    removeEmptyResourcesDirectories(in: dir)

    return bundlesMoved
  }

  /// Searches for and attempts to remove all empty "Resources" directories in a given directory.
  /// This is a recursive search.
  ///
  /// - Parameter dir: The directory to recursively search for Resources directories in.
  static func removeEmptyResourcesDirectories(in dir: URL) {
    // Find all the Resources directories to begin with.
    let fileManager = FileManager.default
    guard let resourceDirs = try? fileManager
      .recursivelySearch(for: .directories(name: "Resources"),
                         in: dir) else {
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
            "hierarchy: \(error)")
        }
      }
    }
  }

  // MARK: Private Helpers

  /// Creates bundles for all folders in the directory passed in, and will compile
  ///
  /// - Parameter dir: A directory containing folders to make into bundles.
  /// - Returns: An array of filepaths to bundles that were packaged.
  /// - Throws: Any file manager errors thrown.
  private static func createBundles(fromDir dir: URL) throws -> [URL] {
    // Get all the folders in the "Resources" directory and loop through them.
    let fileManager = FileManager.default
    var bundles: [URL] = []
    let contents = try fileManager.contentsOfDirectory(atPath: dir.path)
    for fileOrFolder in contents {
      let fullPath = dir.appendingPathComponent(fileOrFolder)

      // The dir itself may contain resource files at its root. If so, we may need to package these
      // in the future but print a warning for now.
      guard fileManager.isDirectory(at: fullPath) else {
        print("WARNING: Found a file in the Resources directory, this may need to be packaged: " +
          "\(fullPath)")
        continue
      }

      if fullPath.lastPathComponent.hasSuffix("bundle") {
        // It's already a bundle, so no need to create one.
        continue
      }

      // It's a folder. Generate the name and location based on the folder name.
      let name = fullPath.lastPathComponent + ".bundle"
      let location = dir.appendingPathComponent(name)

      // Copy the existing Resources folder to the new bundle location.
      try fileManager.copyItem(at: fullPath, to: location)

      // Compile any storyboards that exist in the new bundle.
      compileStoryboards(inDir: location)

      bundles.append(location)
    }

    return bundles
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
      case .success:
        // Remove the original storyboard file and continue.
        do {
          try fileManager.removeItem(at: storyboard)
        } catch {
          fatalError("Could not remove storyboard file \(storyboard) from bundle after " +
            "compilation: \(error)")
        }
      case let .error(code, output):
        fatalError("Failed to compile storyboard \(storyboard): error \(code) \(output)")
      }
    }
  }

  /// Moves all files passed in to the destination dir, keeping the same filename.
  ///
  /// - Parameters:
  ///   - files: URLs to files to move.
  ///   - destinationDir: Destination directory to move all the files. Creates the directory if it
  ///                     doesn't exist.
  ///   - keepOriginal: Do a copy instead of a move.
  /// - Throws: Any file system errors that occur.
  @discardableResult
  private static func moveAllFiles(_ files: [URL], toDir destinationDir: URL,
                                   keepOriginal: Bool = false) throws -> [URL] {
    let fileManager = FileManager.default
    if !fileManager.directoryExists(at: destinationDir) {
      try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
    }

    var filesMoved: [URL] = []
    for file in files {
      // Create the destination URL by using the filename of the file but prefix of the
      // destinationDir.
      let destination = destinationDir.appendingPathComponent(file.lastPathComponent)
      if keepOriginal {
        try fileManager.copyItem(at: file, to: destination)
      } else {
        try fileManager.moveItem(at: file, to: destination)
      }
      filesMoved.append(destination)
    }

    return filesMoved
  }
}
