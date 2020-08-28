#!/usr/bin/swift

/*
 * Copyright 2020 Google LLC
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

let _DEPENDENCY_LABEL_IN_SPEC = "dependency"
let _SKIP_LINES_WITH_WORDS = ["unit_tests", "test_spec"]
let _DEPENDENCY_LINE_SEPARATORS = [" ", ",", "/"] as CharacterSet
let _POD_SOURCES = [
  "https://${BOT_TOKEN}@github.com/FirebasePrivate/SpecsTesting",
  "https://cdn.cocoapods.org/",
]
let _FLAGS = ["--skip-tests", "--allow-warnings"]
let _FIREBASE_FLAGS = _FLAGS + ["--skip-import-validation", "--use-json"]
let _FIREBASEFIRESTORE_FLAGS = _FLAGS + []
let _EXCLUSIVE_PODS: [String] = ["GoogleAppMeasurement", "FirebaseAnalytics"]

class SpecFiles {
  private var specFilesDict: [String: URL]
  var depInstallOrder: [String]
  init(_ specDict: [String: URL]) {
    specFilesDict = specDict
    depInstallOrder = []
  }

  func removeValue(forKey key: String) {
    specFilesDict.removeValue(forKey: key)
  }

  func get(_ key: String) -> URL! {
    return specFilesDict[key]
  }

  func contains(_ key: String) -> Bool {
    return specFilesDict[key] != nil
  }

  func isEmpty() -> Bool {
    return specFilesDict.isEmpty
  }
}

struct Shell {
  static let shared = Shell()
  @discardableResult
  func run(_ command: String, displayCommand: Bool = true,
           displayFailureResult: Bool = true) -> Int32 {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]
    task.launch()
    if displayCommand {
      print("[SpecRepoBuilder] Command:\(command)\n")
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

enum SpecRepoBuilderError: Error {
  case circularDependencies(pods: Set<String>)
  case failedToPush(pods: [String])
}

struct FirebasePodUpdater: ParsableCommand {
  @Option(help: "The root of the firebase-ios-sdk checked out git repo.")
  var sdk_repo: String = FileManager().currentDirectoryPath
  @Option(help: "A list of podspec sources in Podfiles.")
  var pod_sources: [String] = _POD_SOURCES
  @Option(help: "Podspecs that will not be pushed to repo.")
  var exclude_pods: [String] = _EXCLUSIVE_PODS
  @Option(help: "Github Account Name.")
  var github_account: String = "FirebasePrivate"
  @Option(help: "Github Repo Name.")
  var sdk_repo_name: String = "SpecsTesting"
  @Option(help: "Local Podspec Repo Name.")
  var local_spec_repo_name: String
  @Flag(help: "Raise error while circular dependency detected.")
  var raise_circular_dep_error: Bool = false
  func generateOrderOfInstallation(pods: [String], podSpecDict: SpecFiles,
                                   parentDeps: inout Set<String>) {
    if podSpecDict.isEmpty() {
      return
    }

    for pod in pods {
      if !podSpecDict.contains(pod) {
        continue
      }
      let deps = getTargetedDeps(of: pod, from: podSpecDict)
      if parentDeps.contains(pod) {
        print("Circular dependency is detected in \(pod) and \(parentDeps)")
        if raise_circular_dep_error {
          Self
            .exit(withError: SpecRepoBuilderError
              .circularDependencies(pods: parentDeps))
        }
        continue
      }
      parentDeps.insert(pod)
      generateOrderOfInstallation(
        pods: deps,
        podSpecDict: podSpecDict,
        parentDeps: &parentDeps
      )
      print("\(pod) depends on \(deps).")
      podSpecDict.depInstallOrder.append(pod)
      parentDeps.remove(pod)
      podSpecDict.removeValue(forKey: pod)
    }
  }

  func searchDeps(of pod: String, from podSpecFilesObj: SpecFiles) -> [String] {
    var deps: [String] = []
    var fileContents = ""
    guard let podSpecURL = podSpecFilesObj.get(pod) else {
      return deps
    }
    do {
      fileContents = try String(contentsOfFile: podSpecURL.path, encoding: .utf8)
    } catch {
      fatalError("Could not read \(pod) podspec from \(podSpecURL.path).")
    }
    for line in fileContents.components(separatedBy: .newlines) {
      if line.contains(_DEPENDENCY_LABEL_IN_SPEC) {
        if _SKIP_LINES_WITH_WORDS.contains(where: line.contains) {
          continue
        }
        let newLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = newLine.components(separatedBy: _DEPENDENCY_LINE_SEPARATORS)
        if let depPrefix = tokens.first {
          if depPrefix.hasSuffix(_DEPENDENCY_LABEL_IN_SPEC) {
            let podNameRaw = String(tokens[1]).replacingOccurrences(of: "'", with: "")
            if podNameRaw != pod { deps.append(podNameRaw) }
          }
        }
      }
    }
    return deps
  }

  func filterTargetDeps(_ deps: [String], with targets: SpecFiles) -> [String] {
    var targetedDeps: [String] = []
    for dep in deps {
      if targets.contains(dep) {
        targetedDeps.append(dep)
      }
    }
    return targetedDeps
  }

  func getTargetedDeps(of pod: String, from podSpecDict: SpecFiles) -> [String] {
    let deps = searchDeps(of: pod, from: podSpecDict)
    return filterTargetDeps(deps, with: podSpecDict)
  }

  func push_podspec(_ pod: String, from sdk_repo: String, sources: [String],
                    flags: [String], shell_cmd: Shell = Shell.shared) -> Int32 {
    let pod_path = sdk_repo + "/" + pod + ".podspec"
    let sources_arg = sources.joined(separator: ",")
    let flags_arg = flags.joined(separator: " ")

    let outcome =
      shell_cmd
        .run(
          "pod repo push \(local_spec_repo_name) \(pod_path) --sources=\(sources_arg) \(flags_arg)"
        )
    shell_cmd.run("pod repo update")

    return outcome
  }

  func erase_remote_repo(repo_path: String, from github_account: String, _ sdk_repo_name: String,
                         shell_cmd: Shell = Shell.shared) {
    shell_cmd
      .run(
        "git clone --quiet https://${BOT_TOKEN}@github.com/\(github_account)/\(sdk_repo_name).git"
      )
    let fileManager = FileManager.default
    do {
      let dirs = try fileManager.contentsOfDirectory(atPath: "\(repo_path)/\(sdk_repo_name)")
      for dir in dirs {
        if !_EXCLUSIVE_PODS.contains(dir), dir != ".git" {
          shell_cmd.run("cd \(sdk_repo_name); git rm -r \(dir)")
        }
      }
      shell_cmd.run("cd \(sdk_repo_name); git commit -m 'Empty repo'; git push")
    } catch {
      print("Error while enumerating files \(repo_path): \(error.localizedDescription)")
    }
    do {
      try fileManager.removeItem(at: URL(fileURLWithPath: "\(repo_path)/\(sdk_repo_name)"))
    } catch {
      print("Error occurred while removing \(repo_path)/\(sdk_repo_name): \(error)")
    }
  }

  mutating func run() throws {
    let fileManager = FileManager.default
    let cur_dir = FileManager().currentDirectoryPath
    var podSpecFiles: [String: URL] = [:]

    let documentsURL = URL(fileURLWithPath: sdk_repo)
    do {
      let fileURLs = try fileManager.contentsOfDirectory(
        at: documentsURL,
        includingPropertiesForKeys: nil
      )
      let podspecURLs = fileURLs.filter { $0.pathExtension == "podspec" }
      for podspecURL in podspecURLs {
        let podName = podspecURL.deletingPathExtension().lastPathComponent
        if !_EXCLUSIVE_PODS.contains(podName) {
          podSpecFiles[podName] = podspecURL
        }
      }
    } catch {
      print(
        "Error while enumerating files \(documentsURL.path): \(error.localizedDescription)"
      )
    }

    var tmpSet: Set<String> = []
    print("Detect podspecs: \(podSpecFiles.keys)")
    let specFile = SpecFiles(podSpecFiles)
    generateOrderOfInstallation(
      pods: Array(podSpecFiles.keys),
      podSpecDict: specFile,
      parentDeps: &tmpSet
    )
    print(specFile.depInstallOrder.joined(separator: "\n"))

    do {
      if fileManager.fileExists(atPath: "\(cur_dir)/\(sdk_repo_name)") {
        print("remove \(sdk_repo_name) dir.")
        try fileManager.removeItem(at: URL(fileURLWithPath: "\(cur_dir)/\(sdk_repo_name)"))
      }
      erase_remote_repo(repo_path: "\(cur_dir)", from: github_account, sdk_repo_name)

    } catch {
      print("error occurred. \(error)")
    }

    var exitCode: Int32 = 0
    var failedPods: [String] = []
    for pod in specFile.depInstallOrder {
      var podExitCode: Int32 = 0
      print("----------\(pod)-----------")
      switch pod {
      case "Firebase":
        podExitCode = push_podspec(
          pod,
          from: sdk_repo,
          sources: pod_sources,
          flags: _FIREBASE_FLAGS
        )
      case "FirebaseFirestore":
        podExitCode = push_podspec(
          pod,
          from: sdk_repo,
          sources: pod_sources,
          flags: _FIREBASEFIRESTORE_FLAGS
        )
      default:
        podExitCode = push_podspec(pod, from: sdk_repo, sources: pod_sources, flags: _FLAGS)
      }
      if podExitCode != 0 {
        exitCode = 1
        failedPods.append(pod)
      }
    }
    if exitCode != 0 {
      Self.exit(withError: SpecRepoBuilderError.failedToPush(pods: failedPods))
    }
  }
}

FirebasePodUpdater.main()
