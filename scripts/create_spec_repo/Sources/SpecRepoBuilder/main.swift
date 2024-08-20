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

private enum Constants {}

extension Constants {
  static let specDependencyLabel = "dependency"
  static let skipLinesWithWords = ["unit_tests", "test_spec"]
  static let dependencyLineSeparators = CharacterSet(charactersIn: " ,/")
  static let podSources = [
    "https://${BOT_TOKEN}@github.com/Firebase/SpecsTesting",
    "https://github.com/firebase/SpecsStaging.git",
    // https://cdn.cocoapods.org is not used here since `--update-sources`
    // will update spec repos before a spec is pushed, but cdn is not a spec
    // repo.
    "https://github.com/CocoaPods/Specs.git",
  ]
}

// flags for 'pod push'
extension Constants {
  static let flags = [
    "--skip-tests",
    "--skip-import-validation",
    "--update-sources",
  ]
  static let umbrellaPodFlags = Constants.flags + ["--use-json"]
}

public extension Date {
  func dateTimeString() -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter.string(from: self)
  }

  func formattedDurationSince(_ date: Date) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.hour, .minute, .second]
    let secondsSinceDate = date.timeIntervalSince(self)
    return formatter.string(from: secondsSinceDate) ?? "\(round(secondsSinceDate)) sec"
  }
}

// SpecFiles is a wrapper of dict mapping from required pods to their path. This
// will also contain a sequence of installing podspecs.
class SpecFiles {
  private var specFilesDict: [String: URL]
  var depInstallOrder: [String]
  var specSource: String
  init(_ specDict: [String: URL], from specSourcePath: String) {
    specFilesDict = specDict
    depInstallOrder = []
    specSource = specSourcePath
  }

  func removePod(_ key: String) {
    specFilesDict.removeValue(forKey: key)
  }

  subscript(key: String) -> URL? {
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
           displayFailureResult: Bool = true) throws -> Int32 {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.arguments = ["-c", command]

    try task.run()
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

// Error types
enum SpecRepoBuilderError: Error {
  // Error occurs when circular dependencies are detected and deps will be
  // displayed.
  case circularDependencies(pods: Set<String>)
  // Error occurs when there exist specs that failed to push to a spec repo. All
  // specs failed to push should be displayed.
  case failedToPush(pods: [String])
  // Error occurs when a podspec is not found in the repo.
  case podspecNotFound(_ podspec: String, from: String)
  // Error occurs when a directory path cannot be determined.
  case pathNotFound(_ path: String)
}

struct SpecRepoBuilder: ParsableCommand {
  @Option(help: "The root of the firebase-ios-sdk checked out git repo.")
  var sdkRepo: String = FileManager().currentDirectoryPath

  @Option(parsing: .upToNextOption, help: "A list of podspec sources in Podfiles.")
  var podSources: [String] = Constants.podSources

  @Option(parsing: .upToNextOption, help: "Podspecs that will not be pushed to repo.")
  var excludePods: [String] = []

  @Option(help: "GitHub Account Name.")
  var githubAccount: String = "Firebase"

  @Option(help: "GitHub Repo Name.")
  var sdkRepoName: String = "SpecsTesting"

  @Option(help: "Local Podspec Repo Name.")
  var localSpecRepoName: String

  @Option(parsing: .upToNextOption, help: "Push selected podspecs.")
  var includePods: [String] = []

  @Flag(help: "Keep or erase a repo before push.")
  var keepRepo: Bool = false

  @Flag(help: "Raise error while circular dependency detected.")
  var raiseCircularDepError: Bool = false

  @Flag(help: "Allow warnings when push a spec.")
  var allowWarnings: Bool = false

  // This will track down dependencies of pods and keep the sequence of
  // dependency installation in specFiles.depInstallOrder.
  func generateOrderOfInstallation(pods: [String], specFiles: SpecFiles,
                                   parentDeps: inout Set<String>) {
    // pods are dependencies will be tracked down.
    // specFiles includes required pods and their URLs.
    // parentDeps will record the path of tracking down dependencies to avoid
    // duplications and circular dependencies.
    // Stop tracking down when the parent pod does not have any required deps.
    if pods.isEmpty {
      return
    }

    for pod in pods {
      guard specFiles.contains(pod) else { continue }
      let deps = getTargetedDeps(of: pod, from: specFiles)
      // parentDeps will have all dependencies the current pod supports. If the
      // current pod were in the parent dependencies, that means it was tracked
      // before and it is circular dependency.
      if parentDeps.contains(pod) {
        print("Circular dependency is detected in \(pod) and \(parentDeps)")
        if raiseCircularDepError {
          Self
            .exit(withError: SpecRepoBuilderError
              .circularDependencies(pods: parentDeps))
        }
        continue
      }
      // Record the pod as a parent and use depth-first-search to track down
      // dependencies of this pod.
      parentDeps.insert(pod)
      generateOrderOfInstallation(
        pods: deps,
        specFiles: specFiles,
        parentDeps: &parentDeps
      )
      // When pod does not have required dep or its required deps are recorded,
      // the pod itself will be recorded into the depInstallOrder.
      if !specFiles.depInstallOrder.contains(pod) {
        print("\(pod) depends on \(deps).")
        specFiles.depInstallOrder.append(pod)
      }
      // When track back from a lower level, parentDep should track back by
      // removing one pod.
      parentDeps.remove(pod)
    }
  }

  // Scan a podspec file and find and return all dependencies in this podspec.
  func searchDeps(ofPod podName: String, from podSpecFiles: SpecFiles) -> [String] {
    var deps: [String] = []
    var fileContents = ""
    guard let podSpecURL = podSpecFiles[podName] else {
      Self
        .exit(withError: SpecRepoBuilderError
          .podspecNotFound(podName, from: podSpecFiles.specSource))
    }
    do {
      fileContents = try String(contentsOfFile: podSpecURL.path, encoding: .utf8)
    } catch {
      fatalError("Could not read \(podName) podspec from \(podSpecURL.path).")
    }
    // Get all the lines containing `dependency` but don't contain words we
    // want to ignore.
    let depLines: [String] = fileContents
      .components(separatedBy: .newlines)
      .filter { $0.contains("dependency") }
      // Skip lines with words in Constants.skipLinesWithWords
      .filter { !Constants.skipLinesWithWords.contains(where: $0.contains)
      }
    for line in depLines {
      let newLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
      // This is to avoid pushing umbrellapods like Firebase/Core.
      let tokens = newLine.components(separatedBy: Constants.dependencyLineSeparators)
      if let depPrefix = tokens.first {
        if depPrefix.hasSuffix(Constants.specDependencyLabel) {
          // e.g. In Firebase.podspec, Firebase/Core will not be considered a
          // dependency.
          // "ss.dependency 'Firebase/Core'" will be split in
          // ["ss.dependency", "'Firebase", "Core'"]
          let podNameRaw = String(tokens[1]).replacingOccurrences(of: "'", with: "")
          // In the example above, deps here will not include Firebase since
          // it is the same as the pod name.
          if podNameRaw != podName { deps.append(podNameRaw) }
        }
      }
    }
    return deps
  }

  // Filter and get a list of required dependencies found in the repo.
  func filterTargetDeps(_ deps: [String], with targets: SpecFiles) -> [String] {
    var targetedDeps: [String] = []
    for dep in deps {
      // Only get unique and required dep in the output list.
      if targets.contains(dep), !targetedDeps.contains(dep) {
        targetedDeps.append(dep)
      }
    }
    return targetedDeps
  }

  func getTargetedDeps(of pod: String, from specFiles: SpecFiles) -> [String] {
    let deps = searchDeps(ofPod: pod, from: specFiles)
    return filterTargetDeps(deps, with: specFiles)
  }

  func pushPodspec(forPod pod: URL, sdkRepo: String, sources: [String],
                   flags: [String], shell: Shell = Shell.shared) throws -> Int32 {
    let sourcesArg = sources.joined(separator: ",")
    let flagsArgArr = allowWarnings ? flags + ["--allow-warnings"] : flags
    let flagsArg = flagsArgArr.joined(separator: " ")

    do {
      // Update the repo
      try shell.run("pod repo update")
      var isDir: ObjCBool = true
      let podName = pod.deletingPathExtension().lastPathComponent
      let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
      let theProjectPath = "\(homeDirURL.path)/.cocoapods/repos/\(localSpecRepoName)/\(podName)"
      print("check project path \(theProjectPath)")
      if !FileManager.default.fileExists(atPath: theProjectPath, isDirectory: &isDir) {
        let outcome =
          try shell
            .run(
              "pod repo push \(localSpecRepoName) \(pod.path) --sources=\(sourcesArg) \(flagsArg)"
            )
        try shell.run("pod repo update")
        print("Outcome is \(outcome)")
        return outcome
      }
      print("`pod repo push` \(podName) will not run since the repo was uploaded already.")
      return 0

    } catch {
      throw error
    }
  }

  // This will commit and push to erase the entire remote spec repo.
  func eraseRemoteRepo(repoPath: String, from githubAccount: String, _ sdkRepoName: String,
                       shell: Shell = Shell.shared) throws {
    do {
      try shell
        .run(
          "git clone --quiet https://${BOT_TOKEN}@github.com/\(githubAccount)/\(sdkRepoName).git"
        )
    } catch {
      throw error
    }
    let fileManager = FileManager.default
    do {
      let sdk_repo_path = "\(repoPath)/\(sdkRepoName)"
      print("The repo path is  \(sdk_repo_path)")
      guard let repo_url = URL(string: sdk_repo_path) else {
        print("Error: cannot find \(sdk_repo_path).")
        Self
          .exit(withError: SpecRepoBuilderError
            .pathNotFound(sdk_repo_path))
      }
      // Skip hidden files, e.g. /.git
      let dirs = try fileManager.contentsOfDirectory(
        at: repo_url,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      print("Found following unhidden dirs: \(dirs)")
      for dir in dirs {
        guard let isDir = try (dir.resourceValues(forKeys: [.isDirectoryKey])).isDirectory else {
          print("Error: cannot determine if \(dir.path) is a directory or not.")
          Self
            .exit(withError: SpecRepoBuilderError
              .pathNotFound(dir.path))
        }
        if isDir {
          print("Removing \(dir.path)")
          try shell.run("cd \(sdkRepoName); git rm -r \(dir.path)")
        }
      }
      do {
        try shell.run("cd \(sdkRepoName); git commit -m 'Empty repo'; git push")
      } catch {
        throw error
      }
    } catch {
      print("Error while enumerating files \(repoPath): \(error.localizedDescription)")
    }
    do {
      try fileManager.removeItem(at: URL(fileURLWithPath: "\(repoPath)/\(sdkRepoName)"))
    } catch {
      print("Error occurred while removing \(repoPath)/\(sdkRepoName): \(error)")
    }
  }

  mutating func run() throws {
    let fileManager = FileManager.default
    let curDir = FileManager().currentDirectoryPath
    var podSpecFiles: [String: URL] = [:]

    let documentsURL = URL(fileURLWithPath: sdkRepo)
    do {
      let fileURLs = try fileManager.contentsOfDirectory(
        at: documentsURL,
        includingPropertiesForKeys: nil
      )
      let podspecURLs = fileURLs
        .filter { $0.pathExtension == "podspec" || $0.pathExtension == "json" }
      for podspecURL in podspecURLs {
        print(podspecURL)
        let podName = podspecURL.lastPathComponent.components(separatedBy: ".")[0]
        print("Podspec, \(podName), is detected.")
        if excludePods.contains(podName) {
          continue
        }
        podSpecFiles[podName] = podspecURL
      }
    } catch {
      print(
        "Error while enumerating files \(documentsURL.path): \(error.localizedDescription)"
      )
      throw error
    }

    // This set is used to keep parent dependencies and help detect circular
    // dependencies.
    var tmpSet: Set<String> = []
    print("Detect podspecs: \(podSpecFiles.keys)")
    let specFileDict = SpecFiles(podSpecFiles, from: sdkRepo)
    generateOrderOfInstallation(
      pods: includePods.isEmpty ? Array(podSpecFiles.keys) : includePods,
      specFiles: specFileDict,
      parentDeps: &tmpSet
    )
    print("Podspec push order:\n", specFileDict.depInstallOrder.joined(separator: "->\t"))

    if !keepRepo {
      do {
        if fileManager.fileExists(atPath: "\(curDir)/\(sdkRepoName)") {
          print("remove \(sdkRepoName) dir.")
          try fileManager.removeItem(at: URL(fileURLWithPath: "\(curDir)/\(sdkRepoName)"))
        }
        try eraseRemoteRepo(repoPath: "\(curDir)", from: githubAccount, sdkRepoName)

      } catch {
        print("error occurred. \(error)")
        throw error
      }
    }

    var exitCode: Int32 = 0
    var failedPods: [String] = []
    let startDate = Date()
    var minutes = 0
    for pod in specFileDict.depInstallOrder {
      print("----------\(pod)-----------")
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
      var podExitCode: Int32 = 0
      do {
        guard let podURL = specFileDict[pod] else {
          Self
            .exit(withError: SpecRepoBuilderError
              .podspecNotFound(pod, from: sdkRepo))
        }
        switch pod {
        case "Firebase":
          podExitCode = try pushPodspec(
            forPod: podURL,
            sdkRepo: sdkRepo,
            sources: podSources,
            flags: Constants.umbrellaPodFlags
          )
        default:
          podExitCode = try pushPodspec(
            forPod: podURL,
            sdkRepo: sdkRepo,
            sources: podSources,
            flags: Constants.flags
          )
        }
        if podExitCode != 0 {
          exitCode = 1
          failedPods.append(pod)
          print("Failed pod - \(pod)")
        }
      } catch {
        throw error
      }
      timer.cancel()
      let finishDate = Date()
      print("\(pod) is finished at: \(finishDate.dateTimeString()). " +
        "Duration: \(startDate.formattedDurationSince(finishDate))")
    }
    if exitCode != 0 {
      Self.exit(withError: SpecRepoBuilderError.failedToPush(pods: failedPods))
    }
  }
}

SpecRepoBuilder.main()
