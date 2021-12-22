/*
 * Copyright 2021 Google LLC
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

import ArgumentParser
import FirebaseManifest
import Foundation
import Utils

struct PodspecsTester: ParsableCommand {
  /// The root of the Firebase git repo.
  @Option(help: "The root of the firebase-ios-sdk checked out git repo.",
          transform: URL.init(fileURLWithPath:))
  var gitRoot: URL

  // Read a temp file with testing podspecs. An example of a temp file:
  // ```
  // FirebaseAuth.podspec
  // FirebaseCrashlytics.podspec
  // ```
  @Option(help: "A temp file containing podspecs that will be tested.",
          transform: { str in
            let url = URL(fileURLWithPath: str)
            let temp = try String(contentsOf: url)
            return temp.trimmingCharacters(in: CharacterSet(charactersIn: "\n "))
              .components(separatedBy: "\n")
          })
  var podspecs: [String]

  mutating func validate() throws {
    guard FileManager.default.fileExists(atPath: gitRoot.path) else {
      throw ValidationError("git-root does not exist: \(gitRoot.path)")
    }
  }

  func specTest(spec: String, workingDir: URL) -> (code: Int32, output: String){
    var exitCode:Int32 = 0
    var logOutput:String = ""
    let result = Shell.executeCommandFromScript(
      "pod spec lint \(spec)",
      outputToConsole: false,
      workingDir: workingDir
    )
    switch result {
    case let .error(code, output):
      print("Start ---- Failed Spec Testing: \(spec) ----")
      print("\(output)")
      print("End ---- Failed Spec Testing: \(spec) ----")

      do {
        try output.write(
          to: gitRoot.appendingPathComponent("specTestingLogs/\(spec).txt"),
          atomically: true,
          encoding: String.Encoding.utf8
        )
      } catch {
        print(error)
      }
      exitCode = code
      logOutput = output
    case let .success(output):
      print("\(spec) passed validation.")
      exitCode = 0
      logOutput = output
    }
    return (exitCode, logOutput)
  }

  func run() throws {
    let startDate = Date()
    let queue = OperationQueue()
    var exitCode:Int32 = 0
    print("Started at: \(startDate.dateTimeString())")
    // InitializeSpecTesting.setupRepo(sdkRepoURL: gitRoot)
    let manifest = FirebaseManifest.shared
    for podspec in podspecs {
      let testingPod = podspec.components(separatedBy: ".")[0]
      for pod in manifest.pods {
        if testingPod == pod.name {
          queue.addOperation {
            let code = specTest(spec: podspec, workingDir: gitRoot).code
            exitCode += code
          }
        }
      }
    }
    queue.waitUntilAllOperationsAreFinished()
    let finishDate = Date()
    print("Finished at: \(finishDate.dateTimeString()). " +
      "Duration: \(startDate.formattedDurationSince(finishDate))")
    Foundation.exit(exitCode)
  }
}

// Start the parsing and run the tool.
PodspecsTester.main()
