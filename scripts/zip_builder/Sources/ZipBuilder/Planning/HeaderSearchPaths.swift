/*
 * Copyright 2026 Google LLC
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

@preconcurrency import Basics
import Foundation
@preconcurrency import PackageGraph
@preconcurrency import PackageModel

// The directories a framework searches for headers besides its declared ones.
// See docs/how-it-works.md#header-search-paths.

/// The module's own directory and public headers directory, so its sources find their own
/// headers without header maps, as SwiftPM does. Dependencies' headers come from their
/// frameworks, not their sources: finding a header through both would define everything twice.
func ownHeaderSearchPaths(of module: ResolvedModule) -> [AbsolutePath] {
  var paths = [module.sources.root]
  // Mixed-language Swift modules have one too. One that doesn't exist is skipped, and one that is
  // the module's directory is already listed.
  if let includeDir = clangInfo(of: module)?.includeDir, localFileSystem.isDirectory(includeDir),
     includeDir != module.sources.root {
    paths.append(includeDir)
  }
  return paths
}

/// For a module with C++ sources: the include directories of the C and C++ libraries it depends
/// on, directly or not, that hold headers their frameworks can't serve; sorted. `frameworkNames`
/// maps each target to the framework it ends up in.
///
/// SwiftPM searches the include directory of every C-family dependency, and C and C++ sources
/// include by the paths that gives them. Here a dependency's headers come from its framework
/// instead (see `ownHeaderSearchPaths`), but a framework's `Headers/` is flat: it only serves
/// `<Framework/Header.h>`, so `<absl/strings/str_cat.h>`, `<openssl/ssl.h>` or a top-level
/// `"pb.h"` can only be found through the include directory. The exception stays narrow, so
/// Objective-C keeps the usual rule that avoids its modules' duplicate declarations: it covers
/// modules that compile C++, whose sources include by these paths (Xcode compiles C++ without
/// modules, so they include headers as text), and libraries without Objective-C.
func dependencyIncludeDirectories(of module: ResolvedModule,
                                  frameworkNames: [String: String]) throws -> [AbsolutePath] {
  guard compilesCXX(module) else { return [] }
  let directories = try module.recursiveModuleDependencies().compactMap { dependency
    -> AbsolutePath? in
    guard let library = dependency.underlying as? ClangModule,
          !library.sources.containsObjcFiles else { return nil }
    let framework = frameworkNames[dependency.name] ?? dependency.name
    let publicHeaders = library.headers.filter { $0.isDescendant(of: library.includeDir) }
    let needsSearching = publicHeaders.contains {
      !hasFrameworkSpelling($0, includeDir: library.includeDir, framework: framework)
    }
    return needsSearching ? library.includeDir : nil
  }
  return Set(directories).sorted { $0.pathString < $1.pathString }
}

/// Whether the module compiles C++ sources (`.cc`, `.cpp`, `.cxx`). Objective-C++ (`.mm`) alone
/// doesn't count, so an Objective-C module with a few `.mm` files keeps the usual rule.
private func compilesCXX(_ module: ResolvedModule) -> Bool {
  let extensions = SupportedLanguageExtension.cppExtensions
    .subtracting([SupportedLanguageExtension.mm.rawValue])
  return module.sources.paths.contains { $0.extension.map(extensions.contains) ?? false }
}

/// Whether `framework`'s flat `Headers/` serves `header`, one of its public headers, under the
/// path its include directory does: only a header directly in a directory named after the
/// framework, as `<Framework/Header.h>`.
private func hasFrameworkSpelling(_ header: AbsolutePath, includeDir: AbsolutePath,
                                  framework: String) -> Bool {
  let components = header.relative(to: includeDir).components
  return components.count == 2 && components[0] == framework
}
