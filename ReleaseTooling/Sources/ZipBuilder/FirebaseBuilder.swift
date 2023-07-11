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

/// Wrapper for the Firebase zip build.  Unlike the generic zip builder, the Firebase build creates
/// a two-level
/// zip with the option to install different Firebase library subsets.
struct FirebaseBuilder {
  /// ZipBuilder instance.
  private let zipBuilder: ZipBuilder
  /// Default initializer.
  /// - Parameters:
  ///   - zipBuilder: The zipBuilder object for this Firebase build.
  init(zipBuilder: ZipBuilder) {
    self.zipBuilder = zipBuilder
  }

  /// Wrapper around a generic zip builder that adds in Firebase specific steps including a
  /// multi-level zip file, a README, and optionally Carthage artifacts.
  func build(templateDir: URL,
             carthageBuildOptions: CarthageBuildOptions) {
    // Build the zip file and get the path.
    do {
      let artifacts = try zipBuilder.buildAndAssembleFirebaseRelease(templateDir: templateDir)
      let firebaseVersion = artifacts.firebaseVersion
      let location = artifacts.zipDir
      print("Firebase \(firebaseVersion) directory is ready to be packaged: \(location)")

      // Package carthage if it's enabled.
      let carthageRoot = CarthageUtils.packageCarthageRelease(
        templateDir: zipBuilder.paths.templateDir,
        artifacts: artifacts,
        options: carthageBuildOptions
      )

      print("Attempting to Zip the directory...")
      let candidateName = "Firebase-\(firebaseVersion)-latest.zip"
      let zipped = Zip.zipContents(ofDir: location, name: candidateName)

      // If an output directory was specified, copy the Zip file to that directory. Otherwise just
      // print
      // the location for further use.
      if let outputDir = zipBuilder.paths.outputDir {
        do {
          // We want the output to be in the X_Y_Z directory.
          let underscoredVersion = firebaseVersion.replacingOccurrences(of: ".", with: "_")
          let versionedOutputDir = outputDir.appendingPathComponent(underscoredVersion)
          try FileManager.default.createDirectory(at: versionedOutputDir,
                                                  withIntermediateDirectories: true)
          let destination = versionedOutputDir.appendingPathComponent(zipped.lastPathComponent)
          try FileManager.default.copyItem(at: zipped, to: destination)
        } catch {
          fatalError("Could not copy Zip file to output directory: \(error)")
        }

        // Move the Carthage directory, if it exists.
        if let carthageOutput = carthageRoot {
          do {
            let carthageDir = outputDir.appendingPathComponent("carthage")
            try FileManager.default.copyItem(at: carthageOutput, to: carthageDir)
          } catch {
            fatalError("Could not copy Carthage output to directory: \(error)")
          }
        }
      } else {
        // Move zip to parent directory so it doesn't get removed with other artifacts.
        let parentLocation =
          zipped.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(zipped.lastPathComponent)
        // Clear out the output file if it exists.
        FileManager.default.removeIfExists(at: parentLocation)
        do {
          try FileManager.default.moveItem(at: zipped, to: parentLocation)
        } catch {
          fatalError("Could not move Zip file to output directory: \(error)")
        }
        print("Success! Zip file can be found at \(parentLocation.path)")
      }
    } catch {
      fatalError("Could not build the zip file: \(error)")
    }
  }
}
