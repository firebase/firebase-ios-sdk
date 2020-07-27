#!/usr/bin/swift
import Foundation

let _DEPENDENCY_LABEL_IN_SPEC = "dependency"

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

func generateOrderOfInstallation(pods: [String], podSpecDict: SpecFiles, parentDeps: inout Set<String>) {
  if podSpecDict.isEmpty() {
    return
  }

  for pod in pods {
    if !podSpecDict.contains(pod) {
      continue
    }
    let deps = getTargetedDeps(of: pod, from: podSpecDict)
    if parentDeps.contains(pod) {
      print ("Circular dependency is detected in \(pod) and \(parentDeps)")
      continue
    }
    parentDeps.insert(pod)
    generateOrderOfInstallation(pods: deps, podSpecDict: podSpecDict, parentDeps: &parentDeps)
    print ("\(pod) depends on \(deps).")
    podSpecDict.depInstallOrder.append(pod)
    parentDeps.remove(pod)
    podSpecDict.removeValue(forKey: pod)
    print("\(pod) installed here and will be removed.")
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
      let newLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
      let tokens = newLine.components(separatedBy: [" ", ","] as CharacterSet)
      if let depPrefix = tokens.first {
        if depPrefix.hasSuffix(_DEPENDENCY_LABEL_IN_SPEC) {
          let podNameRaw = String(tokens[1]).replacingOccurrences(of: "'", with: "")
          deps.append(podNameRaw)
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
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return task.terminationStatus
}

let arg_cnts: Int = Int(CommandLine.argc)
var sdk_repo = FileManager().currentDirectoryPath

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
  var tmpSet: Set<String> = []
  print("Detect podspecs: \(podSpecFiles.keys)")
  let specFile = SpecFiles(podSpecFiles)
  generateOrderOfInstallation(
    pods: Array(podSpecFiles.keys),
    podSpecDict: specFile ,
    parentDeps: &tmpSet
  )
  print (specFile.depInstallOrder.joined(separator: ("\n")))
  for pod in specFile.depInstallOrder {
          var exitCode = shell("find \(sdk_repo) -name \(pod).podspec -print -exec pod repo push ${SPEC_REPO} {} --sources=https://github.com/firebase/SpecsStaging.git,https://cdn.cocoapods.org/ --skip-tests --local-only \\;")
          print("------------exit code : \(exitCode) \(pod)-----------------")
  }
} catch {
  print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
}
