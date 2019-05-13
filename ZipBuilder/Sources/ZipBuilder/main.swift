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

// Get the launch arguments, parsed by user defaults.
let args = LaunchArgs()

// Clear the cache if requested.
if args.deleteCache {
  do {
    let cacheDir = try FileManager.default.firebaseCacheDirectory()
    try FileManager.default.removeItem(at: cacheDir)
  } catch {
    fatalError("Could not empty the cache before building the zip file: \(error)")
  }
}

// Keep timing for how long it takes to build the zip file for information purposes.
let buildStart = Date()
var cocoaPodsUpdateMessage: String = ""

// Do a Pod Update if requested.
if args.updatePodRepo {
  CocoaPodUtils.updateRepos()
  cocoaPodsUpdateMessage = "CocoaPods took \(-buildStart.timeIntervalSinceNow) seconds to update."
}

var paths = ZipBuilder.FilesystemPaths(templateDir: args.templateDir,
                                       coreDiagnosticsDir: args.coreDiagnosticsDir)
paths.allSDKsPath = args.allSDKsPath
paths.currentReleasePath = args.currentReleasePath
paths.logsOutputDir = args.outputDir?.appendingPathComponent("build_logs")
let builder = ZipBuilder(paths: paths,
                         customSpecRepos: args.customSpecRepos,
                         useCache: args.cacheEnabled)

do {
  // Build the zip file and get the path.
  let location = try builder.buildAndAssembleReleaseDir()
  print("Location of directory to be packaged: \(location)")

  // TODO: Package the Carthage distribution with the current Zip structure.

  // Prepare the release directory for zip packaging.
  do {
    // Move the Resources out of each directory in order to maintain the existing Zip structure.
    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(atPath: location.path)
    for fileOrFolder in contents {
      let fullPath = location.appendingPathComponent(fileOrFolder)

      // Ignore any files.
      guard fileManager.isDirectory(at: fullPath) else { continue }

      // Move all the bundles in the frameworks out to a common "Resources" directory to match the
      // existing Zip structure.
      let resourcesDir = fullPath.appendingPathComponent("Resources")
      let bundles = try ResourcesManager.moveAllBundles(inDirectory: fullPath, to: resourcesDir)

      // Remove any extra bundles that were packaged, if possible, by using the folder name and
      // getting the CocoaPod selected.
      if let pod = CocoaPod(rawValue: fileOrFolder) {
        let duplicateResources = pod.duplicateResourcesToRemove()
        let toRemove = bundles.filter { duplicateResources.contains($0.lastPathComponent) }
        try toRemove.forEach(fileManager.removeItem(at:))
      }
    }
  }

  print("Attempting to Zip the directory...")
  let zipped = Zip.zipContents(ofDir: location)

  // If an output directory was specified, copy the Zip file to that directory. Otherwise just print
  // the location for further use.
  if let outputDir = args.outputDir {
    do {
      let destination = outputDir.appendingPathComponent(zipped.lastPathComponent)
      try FileManager.default.copyItem(at: zipped, to: destination)
    } catch {
      fatalError("Could not copy Zip file to output directory: \(error)")
    }
  } else {
    print("Success! Zip file can be found at \(zipped.path)")
  }

  // Get the time since the start of the build to get the full time.
  let secondsSinceStart = -Int(buildStart.timeIntervalSinceNow)
  print("""
  Time profile:
    It took \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m) to build the zip file.
    \(cocoaPodsUpdateMessage)
  """)
} catch {
  let secondsSinceStart = -buildStart.timeIntervalSinceNow
  print("""
  Time profile:
    The build failed in \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m).
    \(cocoaPodsUpdateMessage)
  """)
  fatalError("Could not build the zip file: \(error)")
}
