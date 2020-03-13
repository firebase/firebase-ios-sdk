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
let args = LaunchArgs.shared

// Keep timing for how long it takes to build the zip file for information purposes.
let buildStart = Date()
var cocoaPodsUpdateMessage: String = ""

// Do a Pod Update if requested.
if args.updatePodRepo {
  CocoaPodUtils.updateRepos()
  cocoaPodsUpdateMessage = "CocoaPods took \(-buildStart.timeIntervalSinceNow) seconds to update."
}

var paths = ZipBuilder.FilesystemPaths(templateDir: args.templateDir)
paths.allSDKsPath = args.allSDKsPath
paths.currentReleasePath = args.currentReleasePath
paths.logsOutputDir = args.outputDir?.appendingPathComponent("build_logs")
let builder = ZipBuilder(paths: paths, customSpecRepos: args.customSpecRepos)
let projectDir = FileManager.default.temporaryDirectory(withName: "project")

// If it exists, remove it before we re-create it. This is simpler than removing all objects.
if FileManager.default.directoryExists(at: projectDir) {
  try FileManager.default.removeItem(at: projectDir)
}

CocoaPodUtils.podInstallPrepare(inProjectDir: projectDir)

if let outputDir = args.outputDir {
  do {
    // Clear out the output directory if it exists.
    FileManager.default.removeIfExists(at: outputDir)
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
  }
}

var zipped: URL
if args.zipPods == nil {
  // Do a Firebase build.
  FirebaseBuilder(zipBuilder: builder).build(in: projectDir)
} else {
  let (installedPods, frameworks, _) = builder.buildAndAssembleZip(podsToInstall: LaunchArgs.shared.zipPods!)
  let staging = FileManager.default.temporaryDirectory(withName: "staging")
  try builder.copyFrameworks(fromPods: Array(installedPods.keys), toDirectory: staging,
                             frameworkLocations: frameworks)
  zipped = Zip.zipContents(ofDir: staging, name: "Frameworks.zip")
  print(zipped.absoluteString)
  if let outputDir = args.outputDir {
    try FileManager.default.copyItem(at: zipped, to: outputDir)
    print("Success! Zip file can be found at \(outputDir.path)")
  } else {
    // Move zip to parent directory so it doesn't get removed with other artifacts.
    let parentLocation =
      zipped.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(zipped.lastPathComponent)
    // Clear out the output file if it exists.
    FileManager.default.removeIfExists(at: parentLocation)
    do {
      try FileManager.default.moveItem(at: zipped, to: parentLocation)
    } catch {
      fatalError("Could not move Zip file to output directory: \(error)")
    }
    print("Success! Zip file can be found at \(parentLocation.path)")
  }
}

if !args.keepBuildArtifacts {
  FileManager.default.removeIfExists(at: projectDir.deletingLastPathComponent())
}

// Get the time since the start of the build to get the full time.
let secondsSinceStart = -Int(buildStart.timeIntervalSinceNow)
print("""
Time profile:
  It took \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m) to build the zip file.
  \(cocoaPodsUpdateMessage)
""")
