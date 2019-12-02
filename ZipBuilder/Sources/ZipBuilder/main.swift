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

if args.zipPods != nil {
  // Do a Firebase build.
  FirebaseBuilder(zipBuilder: builder).build(in: projectDir)
} else {
  _ = builder.buildAndAssembleZip(podsToInstall: LaunchArgs.shared.zipPods!)
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
