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

  /// A targeted testing pod, e.g. FirebaseAuth.podspec
  @Option(help: "A podspec that will be tested.")
  var podspec: String?

  /// The root of the Firebase git repo.
  @Option(help: "Spec testing log dir", transform: URL.init(fileURLWithPath:))
  var tempLogDir: URL?

  @Flag(help: "Skip unit tests.")
  var skipTests: Bool

  mutating func validate() throws {
    guard FileManager.default.fileExists(atPath: gitRoot.path) else {
      throw ValidationError("git-root does not exist: \(gitRoot.path)")
    }
  }

  /// Trigger spec test with `spec` under the `workingDir` and return an error
  /// code and log.
  ///
  /// - Parameters:
  ///   - spec: The podspec name, e.g. `FirebaseAnalytics.podspec`.
  ///   - workingDir: The dir of the testing spec.
  ///   - args: A dict including options with its value or/and flags with nil.
  /// - Returns: A tuple with an error code and log.
  func specTest(spec: String, workingDir: URL,
                args: [String: String?]) -> (code: Int32, output: String) {
    var exitCode: Int32 = 0
    var logOutput = ""
    // If value is nil, the key will be a flag.
    let arguments = args.map { key, value in
      if let v = value {
        return "--\(key)=\(v)"
      } else {
        return "--\(key)"
      }
    }.joined(separator: " ")
    let command =
      "pod spec lint \(spec) \(arguments) --sources=https://github.com/firebase/SpecsTesting,https://github.com/firebase/SpecsStaging.git,https://cdn.cocoapods.org/"
    print(command)
    let result = Shell.executeCommandFromScript(
      command,
      outputToConsole: false,
      workingDir: workingDir
    )
    switch result {
    case let .error(code, output):
      print("---- Failed Spec Testing: \(spec) Start ----")
      print("\(output)")
      print("---- Failed Spec Testing: \(spec) End ----")
      exitCode = code
      logOutput = output
    case let .success(output):
      print("\(spec) passed validation.")
      exitCode = 0
      logOutput = output
    }

    if let logDir = tempLogDir {
      do {
        try logOutput.write(
          to: logDir.appendingPathComponent("\(spec).txt"),
          atomically: true,
          encoding: String.Encoding.utf8
        )
      } catch {
        print(error)
      }
    }
    return (exitCode, logOutput)
  }

  func run() throws {
    let startDate = Date()
    var exitCode: Int32 = 0
    print("Started at: \(startDate.dateTimeString())")
    InitializeSpecTesting.setupRepo(sdkRepoURL: gitRoot)
    let manifest = FirebaseManifest.shared
    var minutes = 0
    let timer: DispatchSourceTimer = {
      let t = DispatchSource.makeTimerSource()
      t.schedule(deadline: .now(), repeating: 60)
      t.setEventHandler(handler: {
        print("Tests have run \(minutes) min(s).")
        minutes += 1
      })
      return t
    }()
    timer.resume()
    if let podspec = podspec {
      let testingPod = podspec.components(separatedBy: ".")[0]
      for pod in manifest.pods {
        if testingPod == pod.name {
          var args: [String: String?] = [:]
          args["platforms"] = pod.platforms.joined(separator: ",")
          if pod.allowWarnings {
            args.updateValue(nil, forKey: "allow-warnings")
          }
          if skipTests {
            args.updateValue(nil, forKey: "skip-tests")
          }
          let code = specTest(spec: podspec, workingDir: gitRoot, args: args).code
          exitCode = code
        }
      }
    } else {
      print("A local podspec repo for \(gitRoot) is generated, but no " +
        "podspec testing will be run since `--podspec` is not specified.")
    }
    timer.cancel()
    let finishDate = Date()
    print("Finished at: \(finishDate.dateTimeString()). " +
      "Duration: \(startDate.formattedDurationSince(finishDate))")
    Foundation.exit(exitCode)
  }
}

// Start the parsing and run the tool.
PodspecsTester.main()
