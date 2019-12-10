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
enum CarthageUtils {}

extension CarthageUtils {
  /// Generates all required files for a Carthage release.
  ///
  /// - Parameters:
  ///   - packagedDir: The packaged directory assembled for Carthage and Zip distribution.
  ///   - templateDir: The template project directory, contains the dummy Firebase library.
  ///   - jsonDir: Location of directory containing all JSON Carthage manifests.
  ///   - firebaseVersion: The version of the Firebase pod.
  ///   - coreDiagnosticsPath: The path to the Core Diagnostics framework built for Carthage.
  ///   - outputDir: The directory where all artifacts should be created.
  static func generateCarthageRelease(fromPackagedDir packagedDir: URL,
                                      templateDir: URL,
                                      jsonDir: URL,
                                      firebaseVersion: String,
                                      coreDiagnosticsPath: URL,
                                      outputDir: URL) {
    let directories: [String]
    do {
      directories = try FileManager.default.contentsOfDirectory(atPath: packagedDir.path)
    } catch {
      fatalError("Could not get contents of Firebase directory to package Carthage build. \(error)")
    }

    // Loop through each directory available and package it as a separate Zip file.
    for product in directories {
      let fullPath = packagedDir.appendingPathComponent(product)
      guard FileManager.default.isDirectory(at: fullPath) else { continue }

      // Parse the JSON file, ensure that we're not trying to overwrite a release.
      var jsonManifest = parseJSONFile(fromDir: jsonDir, product: product)
      guard jsonManifest[firebaseVersion] == nil else {
        print("Carthage release for \(product) \(firebaseVersion) already exists - skipping.")
        continue
      }

      // Find all the .frameworks in this directory.
      let allContents: [String]
      do {
        allContents = try FileManager.default.contentsOfDirectory(atPath: fullPath.path)
      } catch {
        fatalError("Could not get contents of \(product) for Carthage build in order to add " +
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
      if product == "FirebaseAnalytics" {
        createFirebaseFramework(inDir: fullPath, rootDir: packagedDir, templateDir: templateDir)

        // Copy the NOTICES file from FirebaseCore.
        let noticesName = "NOTICES"
        let coreNotices = fullPath.appendingPathComponents(["FirebaseCore.framework", noticesName])
        let noticesPath = packagedDir.appendingPathComponent(noticesName)
        do {
          try FileManager.default.copyItem(at: noticesPath, to: coreNotices)
        } catch {
          fatalError("Could not copy \(noticesName) to FirebaseCore for Carthage build. \(error)")
        }

        // Override the Core Diagnostics framework with one that includes the proper bit flipped.
        let coreDiagnosticsFramework = Constants.coreDiagnosticsName + ".framework"
        let destination = fullPath.appendingPathComponent(coreDiagnosticsFramework)
        do {
          // Remove the existing framework and replace it with the newly compiled one.
          try FileManager.default.removeItem(at: destination)
          try FileManager.default.copyItem(at: coreDiagnosticsPath, to: destination)
        } catch {
          fatalError("Could not replace \(coreDiagnosticsFramework) during Carthage build. \(error)")
        }
      }

      // Hash the contents of the directory to get a unique name for Carthage.
      let hash: String
      do {
        // Only use the first 16 characters, that's what we did before.
        let fullHash = try HashCalculator.sha256Contents(ofDir: fullPath)
        hash = String(fullHash.prefix(16))
      } catch {
        fatalError("Could not hash contents of \(product) for Carthage build. \(error)")
      }

      // Generate the zip name to write to the manifest as well as the actual zip file.
      let zipName = "\(product)-\(hash).zip"
      let productZip = outputDir.appendingPathComponent(zipName)
      let zipped = Zip.zipContents(ofDir: fullPath, name: zipName)

      do {
        try FileManager.default.moveItem(at: zipped, to: productZip)
      } catch {
        fatalError("Could not move packaged zip file for \(product) during Carthage build. " +
          "\(error)")
      }

      // Force unwrapping because this can't fail at this point.
      let url =
        URL(string: "https://dl.google.com/dl/firebase/ios/carthage/\(firebaseVersion)/\(zipName)")!
      jsonManifest[firebaseVersion] = url

      // Write the updated manifest.
      let manifestPath = outputDir.appendingPathComponent("Firebase" + product + "Binary.json")

      // Unfortunate workaround: There's a strange issue when serializing to JSON on macOS: URLs
      // will have the `/` escaped leading to an odd JSON output. Instead, let's output the
      // dictionary to a String and write that to disk. When Xcode 11 can be used, use a JSON
      // encoder with the `.withoutEscapingSlashes` option on `outputFormatting` like this:
//      do {
//        let encoder = JSONEncoder()
//        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
//        let encodedManifest = try encoder.encode(jsonManifest)
//      catch { /* handle error */ }

      // Sort the manifest based on the key, $0 and $1 are the parameters and 0 is the first item in
      // the tuple (key).
      let sortedManifest = jsonManifest.sorted { $0.0 < $1.0 }

      // Generate the JSON format and combine all the lines afterwards.
      let manifestLines = sortedManifest.map { (version, url) -> String in
        // Two spaces at the beginning of the String are intentional.
        "  \"\(version)\": \"\(url.absoluteString)\""
      }

      // Join all the lines with a comma and newline to make things easier to read.
      let contents = "{\n" + manifestLines.joined(separator: ",\n") + "\n}\n"
      guard let encodedManifest = contents.data(using: .utf8) else {
        fatalError("Could not encode Carthage JSON manifest for \(product) - UTF8 encoding failed.")
      }

      do {
        try encodedManifest.write(to: manifestPath)
        print("Successfully written Carthage JSON manifest for \(product).")
      } catch {
        fatalError("Could not write new Carthage JSON manifest to disk for \(product). \(error)")
      }
    }
  }

  /// Creates a fake Firebase.framework to use the module for `import Firebase` compatibility.
  ///
  /// - Parameters:
  ///   - destination: The destination directory for the Firebase framework.
  ///   - rootDir: The root directory that contains other required files (like the Firebase header).
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
    do {
      try fm.copyItem(at: header, to: headersDir.appendingPathComponent(header.lastPathComponent))

      // Generate the new modulemap since it differs from the Zip modulemap.
      let carthageModulemap = """
      framework module Firebase {
        header "Firebase.h"
        export *
      }
      """
      let modulemapPath = modulesDir.appendingPathComponent("module.modulemap")
      try carthageModulemap.write(to: modulemapPath, atomically: true, encoding: .utf8)
    } catch {
      fatalError("Couldn't write required files for Firebase framework in Carthage. \(error)")
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

  /// Parses the JSON manifest for the particular product.
  ///
  /// - Parameters:
  ///   - dir: The directory containing all JSON manifests.
  ///   - product: The name of the Firebase product.
  /// - Returns: A dictionary with versions as keys and URLs as values.
  private static func parseJSONFile(fromDir dir: URL, product: String) -> [String: URL] {
    // Parse the JSON manifest.
    let jsonFileName = "Firebase\(product)Binary.json"
    let jsonFile = dir.appendingPathComponent(jsonFileName)
    guard FileManager.default.fileExists(atPath: jsonFile.path) else {
      fatalError("Could not find JSON manifest for \(product) during Carthage build. " +
        "Location: \(jsonFile)")
    }

    let jsonData: Data
    do {
      jsonData = try Data(contentsOf: jsonFile)
    } catch {
      fatalError("Could not read JSON manifest for \(product) during Carthage build. " +
        "Location: \(jsonFile). \(error)")
    }

    // Get a dictionary out of the file.
    let decoder = JSONDecoder()
    do {
      let productReleases = try decoder.decode([String: URL].self, from: jsonData)
      return productReleases
    } catch {
      fatalError("Could not parse JSON manifest for \(product) during Carthage build. " +
        "Location: \(jsonFile). \(error)")
    }
  }
}
