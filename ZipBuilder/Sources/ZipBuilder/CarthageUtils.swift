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

import CommonCrypto
import Foundation

/// Carthage related utility functions. The enum type is used as a namespace here instead of having
/// root functions, and no cases should be added to it.
public enum CarthageUtils {}

public extension CarthageUtils {
  /// Generates all required files for a Carthage release.
  ///
  /// - Parameters:
  ///   - packagedDir: The packaged directory assembled for Carthage and Zip distribution.
  ///   - templateDir: The template project directory, contains the dummy Firebase library.
  ///   - outputDir: The directory where all artifacts should be created.
  static func generateCarthageRelease(fromPackagedDir packagedDir: URL,
                                      templateDir: URL,
                                      outputDir: URL) {
    // TODO: Get Firebase version (either parse readme or pass it in, likely pass it in)

    let directories: [String]
    do {
      directories = try FileManager.default.contentsOfDirectory(atPath: packagedDir.path)
    } catch {
      fatalError("Could not get contents of Firebase directory to package Carthage build. \(error)")
    }

    // Loop through each directory available and package it as a separate Zip file.
    for productDir in directories {
      let fullPath = packagedDir.appendingPathComponent(productDir)
      guard FileManager.default.isDirectory(at: fullPath) else { continue }

      // TODO: Get JSON file and parse it.
      // TODO: Skip this directory if it's already been published.

      // Find all the .frameworks in this directory.
      let allContents: [String]
      do {
        allContents = try FileManager.default.contentsOfDirectory(atPath: fullPath.path)
      } catch {
        fatalError("Could not get contents of \(productDir) for Carthage build in order to add " +
          "an Info.plist in each framework. \(error)")
      }

      // Carthage will fail to install a framework if it doesn't have an Info.plist, even though
      // they're not used for static frameworks. Generate one and write it to each framework.
      let frameworks = allContents.filter { $0.hasSuffix(".framework") }
      for framework in frameworks {
        let plistPath = fullPath.appendingPathComponents([framework, "Info.plist"])
        // Drop the extension of the framework name.
        let plist = generatePlistContents(forName: framework.components(separatedBy: ".").first!)
        do {
          try plist.write(to: plistPath)
        } catch {
          fatalError("Could not copy plist for \(framework) for Carthage release. \(error)")
        }
      }

      // Analytics includes all the Core frameworks and Firebase module, do extra work to package
      // it.
      if productDir == "Analytics" {
        createFirebaseFramework(inDir: fullPath, rootDir: packagedDir, templateDir: templateDir)

        // TODO: Rebuild CoreDiagnostics to include the correct compiler flag.
        //    let builder = FrameworkBuilder(projectDir: <#T##URL#>, carthageBuild: true)

        // Copy the NOTICES file from FirebaseCore.
        let noticesName = "NOTICES"
        let coreNotices = fullPath.appendingPathComponents(["FirebaseCore.framework", noticesName])
        let noticesPath = packagedDir.appendingPathComponent(noticesName)
        do {
          try FileManager.default.copyItem(at: noticesPath, to: coreNotices)
        } catch {
          fatalError("Could not copy \(noticesName) to FirebaseCore for Carthage build. \(error)")
        }
      }

      // Hash the contents of the directory to get a unique name for Carthage.
      let hash: String
      do {
        // Only use the first 16 characters, that's what we did before.
        let fullHash = try HashCalculator.sha256Contents(ofDir: fullPath)
        hash = String(fullHash.prefix(16))
      } catch {
        fatalError("Could not hash contents of \(productDir) for Carthage build. \(error)")
      }

      let zipName = "\(productDir)-\(hash).zip"
      let productZip = outputDir.appendingPathComponent(zipName)
      let zipped = Zip.zipContents(ofDir: fullPath, name: zipName)
      do {
        try FileManager.default.moveItem(at: zipped, to: productZip)
      } catch {
        fatalError("Could not move packaged zip file for \(productDir) during Carthage build. " +
          "\(error)")
      }
    }
  }

  /// Creates a fake Firebase.framework to use the module for `import Firebase` compatibility.
  ///
  /// - Parameters:
  ///   - destination: The destination directory for the Firebase framework.
  ///   - rootDir: The root directory that contains other required files (like the modulemap and
  ///       Firebase header).
  ///   - templateDir: The template directory containing the dummy Firebase library.
  private static func createFirebaseFramework(inDir destination: URL,
                                              rootDir: URL,
                                              templateDir: URL) {
    // Local FileManager for better readability.
    let fm = FileManager.default

    let frameworkDir = destination.appendingPathComponent("Firebase.framework")
    let headersDir = frameworkDir.appendingPathComponent("Headers")
    let modulesDir = frameworkDir.appendingPathComponent("Modules")

    // Create all the required directories.
    do {
      try fm.createDirectory(at: headersDir, withIntermediateDirectories: true)
      try fm.createDirectory(at: modulesDir, withIntermediateDirectories: true)
    } catch {
      fatalError("Could not create directories for Firebase framework in Carthage. \(error)")
    }

    // Copy the Firebase header and modulemap that was created in the Zip file.
    let header = rootDir.appendingPathComponent(Constants.ProjectPath.firebaseHeader)
    let modulemap = rootDir.appendingPathComponent(Constants.ProjectPath.modulemap)
    do {
      try fm.copyItem(at: header, to: headersDir.appendingPathComponent(header.lastPathComponent))
      try fm.copyItem(at: modulemap,
                      to: modulesDir.appendingPathComponent(modulemap.lastPathComponent))
    } catch {
      fatalError("Couldn't copy required files for Firebase framework in Carthage. \(error)")
    }

    // Copy the dummy Firebase library.
    let dummyLib = templateDir.appendingPathComponent(Constants.ProjectPath.dummyFirebaseLib)
    do {
      try fm.copyItem(at: dummyLib, to: frameworkDir.appendingPathComponent("Firebase"))
    } catch {
      fatalError("Couldn't copy dummy library for Firebase framework in Carthage. \(error)")
    }

    // Write the Info.plist.
    let data = generatePlistContents(forName: "Firebase")
    do { try data.write(to: frameworkDir.appendingPathComponent("Info.plist")) }
    catch {
      fatalError("Could not write the Info.plist for Firebase framework in Carthage. \(error)")
    }
  }

  private static func generatePlistContents(forName name: String) -> Data {
    let plist: [String: String] = ["CFBundleIdentifier": "com.firebase.Firebase",
                                   "CFBundleInfoDictionaryVersion": "6.0",
                                   "CFBundlePackageType": "FMWK",
                                   "CFBundleVersion": "1",
                                   "DTSDKName": "iphonesimulator11.2",
                                   "CFBundleExecutable": name,
                                   "CFBundleName": name]

    // Generate the data for an XML based plist.
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .xml
    do {
      return try encoder.encode(plist)
    } catch {
      fatalError("Failed to create Info.plist for \(name) during Carthage build: \(error)")
    }
  }
}
