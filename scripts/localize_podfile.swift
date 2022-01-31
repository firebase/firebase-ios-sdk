#!/usr/bin/swift

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

// Modify a Podfile to get any podspecs defined in the firebase-ios-sdk repo locally.

import Foundation

let arg_cnts: Int = .init(CommandLine.argc)

let podfile = CommandLine.arguments[1]

var releaseTesting = false

if arg_cnts > 2 {
  releaseTesting = CommandLine.arguments[1 ..< arg_cnts].contains("release_testing")
}

// Always add these, since they may not be in the Podfile, but we still want the local
// versions when they're dependencies of other requested local pods.
let implicitPods = [
  "FirebaseCore", "FirebaseInstallations", "Firebase",
  "FirebaseAuth", "FirebaseABTesting",
  "FirebaseCoreDiagnostics", "FirebaseRemoteConfig",
]
var didImplicits = false

var fileContents = ""
do {
  fileContents = try String(contentsOfFile: podfile, encoding: .utf8)
} catch {
  fatalError("Could not read \(podfile). \(error)")
}

// Search the path upwards to find the root of the firebase-ios-sdk repo.
var url = URL(fileURLWithPath: FileManager().currentDirectoryPath)
while url.path != "/", url.lastPathComponent != "firebase-ios-sdk" {
  url = url.deletingLastPathComponent()
}

let repo = url
let lines = fileContents.components(separatedBy: .newlines)
var outBuffer =
  "source 'https://github.com/firebase/SpecsDev.git'\n" +
  "source 'https://github.com/firebase/SpecsStaging.git'\n" +
  "source 'https://cdn.cocoapods.org/'\n"
for line in lines {
  var newLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
  let tokens = newLine.components(separatedBy: [" ", ","] as CharacterSet)
  if tokens.first == "pod", !releaseTesting {
    let podNameRaw = String(tokens[1]).replacingOccurrences(of: "'", with: "")
    var podName = podNameRaw

    // Firebase test Podfile's often use the Firebase subspec to access the
    // desired pod. We want to get the requested pod directly.
    if podNameRaw.starts(with: "Firebase/") {
      podName = podName.replacingOccurrences(of: "Firebase/", with: "Firebase")
    }
    let podspec = repo.appendingPathComponent(podName + ".podspec").path
    if FileManager().fileExists(atPath: podspec) {
      if didImplicits == false {
        didImplicits = true
        for implicit in implicitPods {
          let implicitPodspec = repo.appendingPathComponent(implicit + ".podspec").path
          outBuffer += "pod '\(implicit)', :path => '\(implicitPodspec)'\n"
        }
      }
      newLine = "pod '\(podName)', :path => '\(podspec)'"
    } else if podNameRaw.starts(with: "Firebase/") {
      // Update closed source pods referenced via a subspec from the Firebase pod.
      let firebasePodspec = repo.appendingPathComponent("Firebase.podspec").path
      newLine = "pod '\(podNameRaw)', :path => '\(firebasePodspec)'"
    }
  }
  outBuffer += newLine + "\n"
}

// Write out the changed file.
do {
  try outBuffer.write(toFile: podfile, atomically: false, encoding: String.Encoding.utf8)
} catch {
  fatalError("Failed to write \(podfile). \(error)")
}
