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

/// A struct to build a .modulemap in a given framework directory.
///
struct ModuleMapBuilder {
  /// Information associated with a framework
  private class FrameworkInfo {
    let isSourcePod: Bool
    let versionedPod: CocoaPodUtils.VersionedPod
    var transitiveFrameworks: Set<String>?
    var transitiveLibraries: Set<String>?

    init(isSourcePod: Bool, versionedPod: CocoaPodUtils.VersionedPod) {
      self.isSourcePod = isSourcePod
      self.versionedPod = versionedPod
    }
  }

  /// The directory containing the Xcode project and Pods folder.
  private let projectDir: URL

  /// Custom CocoaPods spec repos to be used. If not provided, the tool will only use the CocoaPods
  /// master repo.
  private let customSpecRepos: [URL]?

  /// Dictionary of all installed pods. Update moduleMapContents here.
  private var allPods: [String: CocoaPodUtils.PodInfo]

  /// Dictionary of installed pods required for this module.
  private var installedPods: [String: FrameworkInfo]

  /// Default initializer.
  init(customSpecRepos: [URL]?, selectedPods: [String: CocoaPodUtils.PodInfo]) {
    projectDir = FileManager.default.temporaryDirectory(withName: "module")
    CocoaPodUtils.podInstallPrepare(inProjectDir: projectDir)

    self.customSpecRepos = customSpecRepos
    allPods = selectedPods

    var installedPods: [String: FrameworkInfo] = [:]
    for pod in selectedPods {
      let frameworkName = pod.key
      let isSourcePod = pod.value.isSourcePod
      let version = pod.value.version
      let versionedPod = CocoaPodUtils.VersionedPod(name: frameworkName, version: version)
      installedPods[frameworkName] = FrameworkInfo(isSourcePod: isSourcePod, versionedPod: versionedPod)
    }
    self.installedPods = installedPods
  }

  // MARK: - Public Functions

  /// Build the module map files for the source frameworks.
  ///
  func build() {
    for (_, info) in installedPods {
      if info.isSourcePod == false || info.transitiveFrameworks != nil {
        continue
      }
      generate(framework: info)
    }
  }

  // MARK: - Internal Functions

  /// Build a module map for a single framework. A CocoaPod install is run to extract the required frameworks
  /// and libraries from the generated xcconfig. All previously installed dependent pods are put into the Podfile
  /// to make sure we install the right version and from the right location.
  private func generate(framework: FrameworkInfo) {
    let podName = framework.versionedPod.name
    let deps = CocoaPodUtils.transitiveVersionedPodDependencies(for: podName, in: allPods)
    _ = CocoaPodUtils.installPods([framework.versionedPod] + deps,
                                  inDir: projectDir,
                                  customSpecRepos: customSpecRepos)
    let xcconfigFile = projectDir.appendingPathComponents(["Pods", "Target Support Files",
                                                           "Pods-FrameworkMaker",
                                                           "Pods-FrameworkMaker.release.xcconfig"])
    allPods[podName]?.moduleMapContents = makeModuleMap(forFramework: framework, withXcconfigFile: xcconfigFile)
  }

  // Extract the framework and library dependencies for a framework from
  // the xcconfig file from an app generated from a Podfile only with that
  // CocoaPod and removing the frameworks and libraries from its transitive dependencies.
  private func getModuleDependencies(withXcconfigFile xcconfigFile: URL) ->
    (frameworks: [String], libraries: [String]) {
    do {
      let text = try String(contentsOf: xcconfigFile)
      let lines = text.components(separatedBy: .newlines)
      for line in lines {
        if line.hasPrefix("OTHER_LDFLAGS =") {
          var dependencyFrameworks: [String] = []
          var dependencyLibraries: [String] = []
          let tokens = line.components(separatedBy: " ")
          var addNext = false
          for token in tokens {
            if addNext {
              dependencyFrameworks.append(token)
              addNext = false
            } else if token == "-framework" {
              addNext = true
            } else if token.hasPrefix("-l") {
              let index = token.index(token.startIndex, offsetBy: 2)
              dependencyLibraries.append(String(token[index...]))
            }
          }
          return (dependencyFrameworks, dependencyLibraries)
        }
      }
    } catch {
      fatalError("Failed to open \(xcconfigFile): \(error)")
    }
    return ([], [])
  }

  private func makeModuleMap(forFramework framework: FrameworkInfo,
                             withXcconfigFile xcconfigFile: URL) -> String {
    let name = framework.versionedPod.name
    let dependencies = getModuleDependencies(withXcconfigFile: xcconfigFile)
    let frameworkDeps = Set(dependencies.frameworks)
    let libraryDeps = Set(dependencies.libraries)
    var transitiveFrameworkDeps = frameworkDeps
    var transitiveLibraryDeps = libraryDeps
    var myFrameworkDeps = frameworkDeps
    var myLibraryDeps = libraryDeps

    // Iterate through the deps looking for pods. At time of authoring, TensorFlowLiteObjC is the
    // only pod in frameworkDeps instead of libraryDeps.
    for library in libraryDeps.union(frameworkDeps) {
      let lib = library.replacingOccurrences(of: "\"", with: "")
      if let dependencyPod = installedPods[lib] {
        myLibraryDeps.remove(library)
        myFrameworkDeps.remove(library)
        if lib == name {
          continue
        }
        var podFrameworkDeps = dependencyPod.transitiveFrameworks
        var podLibraryDeps = dependencyPod.transitiveLibraries
        if podFrameworkDeps == nil {
          generate(framework: dependencyPod)
          podFrameworkDeps = dependencyPod.transitiveFrameworks
          podLibraryDeps = dependencyPod.transitiveLibraries
        }
        if let fdeps = podFrameworkDeps {
          myFrameworkDeps.subtract(fdeps)
          transitiveFrameworkDeps.formUnion(fdeps)
        }
        if let ldeps = podLibraryDeps {
          myLibraryDeps.subtract(ldeps)
          transitiveLibraryDeps.formUnion(ldeps)
        }
      }
    }
    installedPods[name]?.transitiveFrameworks = transitiveFrameworkDeps
    installedPods[name]?.transitiveLibraries = transitiveLibraryDeps

    // The base of the module map. The empty line at the end is intentional, do not remove it.
    var content = """
    framework module \(name) {
    umbrella header "\(name).h"
    export *
    module * { export * }

    """
    for framework in myFrameworkDeps.sorted() {
      content += "  link framework " + framework + "\n"
    }
    for library in myLibraryDeps.sorted() {
      content += "  link " + library + "\n"
    }
    content += "}\n"
    return content
  }
}
