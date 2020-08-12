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

import Foundation

let _DEPENDENCY_LABEL_IN_SPEC = "dependency"
let _SKIP_LINES_WITH_WORDS = ["unit_tests", "test_spec"]
let _DEPENDENCY_LINE_SEPARATORS = [" ", ",", "/"] as CharacterSet
let _POD_SOURCES = ["https://github.com/firebase/SpecsStaging.git", "https://cdn.cocoapods.org/"]
let _FLAGS = ["--skip-tests"]
let _FIREBASE_FLAGS = _FLAGS + ["--skip-import-validation", "--use-json"]
let _FIREBASEFIRESTORE_FLAGS = _FLAGS + ["--allow-warnings"]

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

func generateOrderOfInstallation(pods: [String], podSpecDict: SpecFiles,
                                 parentDeps: inout Set<String>)
{
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
      continue
    }
    parentDeps.insert(pod)
    generateOrderOfInstallation(pods: deps, podSpecDict: podSpecDict, parentDeps: &parentDeps)
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

@discardableResult
func shell(_ command: String) -> Int32 {
  let task = Process()
  let pipe = Pipe()

  task.standardOutput = pipe
  task.arguments = ["-c", command]
  task.launchPath = "/bin/bash"
  task.launch()
  print("-----Command:\(command)\n")
  task.waitUntilExit()

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: data, encoding: .utf8)!
  print(output)

  return task.terminationStatus
}

func push_podspec(_ pod: String, from sdk_repo: String, sources: [String],
                  flags: [String]) -> Int32?
{
  let pod_path = sdk_repo + "/" + pod + ".podspec"
  let sources_arg = sources.joined(separator: ",")
  let flags_arg = flags.joined(separator: " ")

  let exit_code =
    shell("pod repo push ${SPEC_REPO} \(pod_path) --sources=\(sources_arg) \(flags_arg)")
  shell("pod repo update")

  return exit_code
}

func erase_remote_branch() {
  shell("git clone --quiet https://${BOT_TOKEN}@github.com/firebase/SpecsStaging.git")
  shell("cd SpecsStaging; git rm -r *; git commit -m 'Empty repo'; git push")
  do {
    try fileManager.removeItem(at: URL(fileURLWithPath: "\(cur_dir)/SpecsStaging"))
    print("Specsstaging dir is removed.")
  } catch {
    print("error occurred. \(error)")
  }
}

let arg_cnts: Int = Int(CommandLine.argc)
let cur_dir = FileManager().currentDirectoryPath
var sdk_repo = cur_dir

if arg_cnts > 1 {
  sdk_repo = CommandLine.arguments[1]
} else if arg_cnts > 2 {
  fatalError("Too many arguments.")
}

let fileManager = FileManager.default
var podSpecFiles: [String: URL] = [:]

var documentsURL = URL(fileURLWithPath: sdk_repo)
do {
  let fileURLs = try fileManager.contentsOfDirectory(
    at: documentsURL,
    includingPropertiesForKeys: nil
  )
  let podspecURLs = fileURLs.filter { $0.pathExtension == "podspec" }
  for podspecURL in podspecURLs {
    let podName = podspecURL.deletingPathExtension().lastPathComponent
    podSpecFiles[podName] = podspecURL
  }
} catch {
  print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
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
  if fileManager.fileExists(atPath: "\(cur_dir)/SpecsStaging") {
    print("remove specsstaging dir.")
    try fileManager.removeItem(at: URL(fileURLWithPath: "\(cur_dir)/SpecsStaging"))
  } else {
    erase_remote_branch()
  }
} catch {
  print("error occurred. \(error)")
}

var exitCode: Int32?
for pod in specFile.depInstallOrder {
  print("----------\(pod)-----------")
  switch pod {
  case "Firebase":
    exitCode = push_podspec(pod, from: sdk_repo, sources: _POD_SOURCES, flags: _FIREBASE_FLAGS)
  case "FirebaseFirestore":
    exitCode = push_podspec(
      pod,
      from: sdk_repo,
      sources: _POD_SOURCES,
      flags: _FIREBASEFIRESTORE_FLAGS
    )
  default:
    exitCode = push_podspec(pod, from: sdk_repo, sources: _POD_SOURCES, flags: _FLAGS)
  }
  if let code = exitCode {
    print("------------exit code : \(code) \(pod)-----------------")
  } else {
    print(" Does not have a valid exitCode.")
  }
}
