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
    let subspecs: Set<String>
    var transitiveFrameworks: Set<String>?
    var transitiveLibraries: Set<String>?

    init(isSourcePod: Bool, versionedPod: CocoaPodUtils.VersionedPod, subspecs: Set<String>) {
      self.isSourcePod = isSourcePod
      self.versionedPod = versionedPod
      self.subspecs = subspecs
    }
  }

  struct ModuleMapContents {
    /// Placeholder to fill in umbrella header.
    static let umbrellaPlaceholder = "UMBRELLA_PLACEHOLDER"
    let contents: String
    init(module: String, frameworks: Set<String>, libraries: Set<String>) {
      var content = """
      framework module \(module) {
      umbrella header "\(ModuleMapBuilder.ModuleMapContents.umbrellaPlaceholder)"
      export *
      module * { export * }

      """
      for framework in frameworks.sorted() {
        content += "  link framework " + framework + "\n"
      }
      for library in libraries.sorted() {
        content += "  link " + library + "\n"
      }
      // The empty line at the end is intentional, do not remove it.
      content += "}\n"
      contents = content
    }

    func get(umbrellaHeader: String) -> String {
      return contents.replacingOccurrences(of:
        ModuleMapBuilder.ModuleMapContents.umbrellaPlaceholder, with: umbrellaHeader)
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

  /// The platform for this build.
  private let platform: Platform

  /// The path containing local podspec URLs, if specified.
  private let localPodspecPath: URL?

  /// Default initializer.
  init(customSpecRepos: [URL]?,
       selectedPods: [String: CocoaPodUtils.PodInfo],
       platform: Platform,
       paths: ZipBuilder.FilesystemPaths) {
    projectDir = FileManager.default.temporaryDirectory(withName: "module")
    CocoaPodUtils.podInstallPrepare(inProjectDir: projectDir, templateDir: paths.templateDir)

    self.customSpecRepos = customSpecRepos
    allPods = selectedPods

    var installedPods: [String: FrameworkInfo] = [:]
    for pod in selectedPods {
      let versionedPod = CocoaPodUtils.VersionedPod(name: pod.key, version: pod.value.version)
      installedPods[pod.key] = FrameworkInfo(isSourcePod: pod.value.isSourcePod,
                                             versionedPod: versionedPod,
                                             subspecs: pod.value.subspecs)
    }
    self.installedPods = installedPods

    self.platform = platform
    localPodspecPath = paths.localPodspecPath
  }

  // MARK: - Public Functions

  /// Build the module map files for the source frameworks.
  ///
  func build() {
    for (_, info) in installedPods {
      if info.isSourcePod == false ||
        info.transitiveFrameworks != nil ||
        info.versionedPod.name == "Firebase" {
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
    _ = CocoaPodUtils.installPods(allSubspecList(framework: framework) + deps,
                                  inDir: projectDir,
                                  platform: platform,
                                  customSpecRepos: customSpecRepos,
                                  localPodspecPath: localPodspecPath,
                                  linkage: .forcedStatic)
    let xcconfigFile = projectDir.appendingPathComponents(["Pods", "Target Support Files",
                                                           "Pods-FrameworkMaker",
                                                           "Pods-FrameworkMaker.release.xcconfig"])
    allPods[podName]?
      .moduleMapContents = makeModuleMap(forFramework: framework, withXcconfigFile: xcconfigFile)
  }

  /// Convert a list of versioned pods to a list of versioned pods specified with all needed subspecs.
  private func allSubspecList(framework: FrameworkInfo) -> [CocoaPodUtils.VersionedPod] {
    let name = framework.versionedPod.name
    let version = framework.versionedPod.version
    let subspecs = framework.subspecs
    if subspecs.count == 0 {
      return [CocoaPodUtils.VersionedPod(name: "\(name)", version: version)]
    }
    var list: [CocoaPodUtils.VersionedPod] = []
    for subspec in framework.subspecs {
      list.append(CocoaPodUtils.VersionedPod(name: "\(name)/\(subspec)", version: version))
    }
    return list
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
                             withXcconfigFile xcconfigFile: URL) -> ModuleMapContents {
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
          transitiveFrameworkDeps.formUnion(fdeps)
        }
        if let ldeps = podLibraryDeps {
          transitiveLibraryDeps.formUnion(ldeps)
        }
      }
    }
    installedPods[name]?.transitiveFrameworks = transitiveFrameworkDeps
    installedPods[name]?.transitiveLibraries = transitiveLibraryDeps

    return ModuleMapContents(module: name, frameworks: myFrameworkDeps, libraries: myLibraryDeps)
  }
}
