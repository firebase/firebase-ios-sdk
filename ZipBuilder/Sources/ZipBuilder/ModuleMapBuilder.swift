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
    let isOpenSource: Bool
    let location: URL
    var transitiveFrameworks: Set<String>?
    var transitiveLibraries: Set<String>?

    init(isOpenSource: Bool, location: URL) {
      self.isOpenSource = isOpenSource
      self.location = location
    }
  }

  /// The directory containing the Xcode project and Pods folder.
  private let projectDir: URL

  /// Custom CocoaPods spec repos to be used. If not provided, the tool will only use the CocoaPods
  /// master repo.
  private let customSpecRepos: [URL]?

  /// Dictionary of all installed pods.
  private var installedPods: [String: FrameworkInfo]

  /// Default initializer.
  init(fromFrameworks frameworks: [String: [URL]], customSpecRepos: [URL]?) {
    projectDir = FileManager.default.temporaryDirectory(withName: "module")
    CocoaPodUtils.podInstallPrepare(inProjectDir: projectDir)

    self.customSpecRepos = customSpecRepos

    var cacheDir: URL
    do {
      cacheDir = try FileManager.default.firebaseCacheDirectory(withSubdir: "")
    } catch {
      fatalError("Could not find framework cache directory: \(error)")
    }
    var installedPods: [String: FrameworkInfo] = [:]
    for framework in frameworks {
      for url in framework.value {
        let frameworkFullName = url.lastPathComponent
        let frameworkName = frameworkFullName.replacingOccurrences(of: ".framework", with: "")
        let isOpenSource = url.absoluteString.contains(cacheDir.absoluteString)
        installedPods[frameworkName] = FrameworkInfo(isOpenSource: isOpenSource, location: url)
      }
    }
    self.installedPods = installedPods
  }

  // MARK: - Public Functions

  /// Build the module map files for the source frameworks.
  ///
  public func build() {
    for (podName, info) in installedPods {
      if info.isOpenSource == false || info.transitiveFrameworks != nil {
        continue
      }
      generate(podName: podName, framework: info)
    }
  }

  // MARK: - Internal Functions

  /// Build a module map for a single framework.
  private func generate(podName: String, framework: FrameworkInfo) { // , inLocation location: URL) {
    _ = CocoaPodUtils.installPods([podName], inDir: projectDir, customSpecRepos: customSpecRepos)
    let xcconfigFile = projectDir.appendingPathComponents(["Pods", "Target Support Files",
                                                           "Pods-FrameworkMaker",
                                                           "Pods-FrameworkMaker.release.xcconfig"])
    makeModuleMap(forFrameworkNamed: podName, forFramework: framework, withXcconfigFile: xcconfigFile)
  }

  // Extract the framework and library dependencies for a framework from
  // by starting with the xcconfig file from an app generate from a Podfile only with that
  // framework and removing the frameworks and libraries from its transitive dependencies.
  private func getModuleDependencies(forFrameworkNamed name: String,
                                     withXcconfigFile xcconfigFile: URL) ->
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

  private func makeModuleMap(forFrameworkNamed name: String,
                             forFramework framework: FrameworkInfo,
                             withXcconfigFile xcconfigFile: URL) {
    let dependencies = getModuleDependencies(forFrameworkNamed: name, withXcconfigFile: xcconfigFile)

    let frameworkDeps = Set(dependencies.frameworks)
    let libraryDeps = Set(dependencies.libraries)
    var transitiveFrameworkDeps = frameworkDeps
    var transitiveLibraryDeps = libraryDeps
    var myFrameworkDeps = frameworkDeps
    var myLibraryDeps = libraryDeps

    // Remove
    for library in libraryDeps {
      let lib = library.replacingOccurrences(of: "\"", with: "")
      if let dependencyPod = installedPods[lib] {
        myLibraryDeps.remove(library)
        if lib == name {
          continue
        }
        var podFrameworkDeps = dependencyPod.transitiveFrameworks
        var podLibraryDeps = dependencyPod.transitiveLibraries
        if podFrameworkDeps == nil {
          generate(podName: lib, framework: dependencyPod)
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

    let moduleDir = framework.location.appendingPathComponent("Modules")
    do {
      try FileManager.default.createDirectory(at: moduleDir, withIntermediateDirectories: true)
    } catch {
      fatalError("Could not create Modules directory for framework: \(name). \(error)")
    }

    let modulemap = moduleDir.appendingPathComponent("module.modulemap")
    // The base of the module map. The empty line at the end is intentional, do not remove it.
    var content = """
    framework module \(name) {
    umbrella header "\(name).h"
    export *
    module * { export * }

    """
    for framework in myFrameworkDeps {
      content += "  link framework " + framework + "\n"
    }
    for library in myLibraryDeps {
      content += "  link " + library + "\n"
    }
    content += "}\n"

    do {
      try content.write(to: modulemap, atomically: true, encoding: .utf8)
    } catch {
      fatalError("Could not write modulemap to disk for \(name): \(error)")
    }
  }
}
