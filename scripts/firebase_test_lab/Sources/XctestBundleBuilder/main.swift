/*
 * Copyright 2022 Google LLC
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
import Foundation

let _XCODEPROJ=".xcodeproj"
let _XCWORKSPACE=".xcworkspace"
let _XCODEBUILD_NO_SIGN_FLAG="CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
let _TESTBUNDLE_NAME="FTLXCTestBundle.zip"

struct Shell {
  static let shared = Shell()
  @discardableResult
  func run(_ command: String, displayCommand: Bool = true,
           displayFailureResult: Bool = true) throws -> Int32 {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.arguments = ["-c", command]

    try task.run()
    if displayCommand {
      print("[XctestBundleBuilder] Command:\(command)\n")
    }
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let log = String(data: data, encoding: .utf8)!
    if displayFailureResult, task.terminationStatus != 0 {
      print("-----Exit code: \(task.terminationStatus)")
      print("-----Log:\n \(log)")
    }
    return task.terminationStatus
  }
}
enum XctestBundleBuilderError:Error{
    case pathNotFound(path: String)
    case pathInvalid(path: String)
}
struct XctestBundleBuilder: ParsableCommand {
  @Option(help: "Project path, ending with either .workspace or .xcodeproj")
  var projectPath: String

  @Option(help: "Scheme of target project")
  var scheme: String

  @Option(help: "Folder with build output.", transform: URL.init(fileURLWithPath:))
  var derivedDataPath: URL = URL(fileURLWithPath:FileManager().currentDirectoryPath)

  func validateParams() throws {
      if !FileManager.default.fileExists(atPath: projectPath){
          print("\(projectPath) is not found.")
              throw XctestBundleBuilderError.pathNotFound(path: projectPath)
      }
      if !projectPath.hasSuffix(_XCODEPROJ) && !projectPath.hasSuffix(_XCWORKSPACE){
          print("The path \(projectPath) is invalid. A path should end with either \(_XCODEPROJ) or \(_XCWORKSPACE).")
              throw XctestBundleBuilderError.pathInvalid(path: projectPath)
      }
      let path = derivedDataPath.path
          if let v = try? derivedDataPath.resourceValues(forKeys: [.isDirectoryKey]) {
              if !v.isDirectory! {
                  print("The path \(path) is not a valid dir path.")
                      throw XctestBundleBuilderError.pathInvalid(path: path)
              }
          } else {
              print("\(path) is not found.")
                  throw XctestBundleBuilderError.pathNotFound(path: path)
          }
  }
  mutating func run() throws {
      try validateParams()
      // Create a test bundle for FTL
      // https://firebase.google.com/docs/test-lab/ios/run-xctest#package-app
      do {
      try Shell.shared.run("xcodebuild -project \(projectPath) -scheme \(scheme) -derivedDataPath \(derivedDataPath.path) -sdk iphoneos build-for-testing \(_XCODEBUILD_NO_SIGN_FLAG)")
      try Shell.shared.run("cd \(derivedDataPath.path)/Build/Products && zip -r \(derivedDataPath.path)/\(_TESTBUNDLE_NAME) Debug-iphoneos *.xctestrun && ")
      } catch {
          throw error
      }
      print (" \(_TESTBUNDLE_NAME) is saved under \(derivedDataPath.path)")
  }
}
XctestBundleBuilder.main()

