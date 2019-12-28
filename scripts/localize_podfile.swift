#!/usr/bin/swift

// Modify a Podfile to get any podspec's defined in the firebase-ios-sdk repo locally

import Foundation

let podfile = CommandLine.arguments[1]

// Always add these, since they may not be in the Podfile, but we still want the local
// versions when they're dependencies of other requested local pods.
let implicitPods = ["FirebaseCore", "FirebaseInstanceID", "FirebaseInstallations", "Firebase",
                    "GoogleDataTransport", "GoogleDataTransportCCTSupport", "GoogleUtilities",
                    "FirebaseCoreDiagnostics", "FirebaseRemoteConfig"]
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

var outBuffer = ""
for line in lines {
  var newLine = line
  let tokens = line.split(separator: " ")
  if tokens.count > 0, tokens[0] == "pod" {
    var podName = String(tokens[1])
    podName = podName.replacingOccurrences(of: "'", with: "")
    if podName.starts(with: "Firebase/") {
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
