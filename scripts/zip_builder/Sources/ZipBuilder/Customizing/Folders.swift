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

import Foundation

// The last customization: arranging the zip's folders.

extension Plan {
  /// `products` and `zip.files`: the zip layout. Folder names already follow `products.rename`,
  /// and the other keys use those names. Files for the zip root go in a folder named `"."`.
  /// With `products.withoutDependencies`, a folder keeps only its product's own frameworks; the
  /// dependencies it leaves out are still built. See docs/how-it-works.md#folders-and-extra-files.
  func arrangingFolders(_ products: Config.Products, files: [Config.Files]) -> Plan {
    let shipped = frameworkNames.union(binaries.map(\.name))
    let folderNames = Set(folders.map(\.name))
    warnAboutUnknown(products.withoutFolder, known: folderNames, key: "products.withoutFolder",
                     kind: "a shipped product")
    warnAboutUnknown(products.extraFrameworks.keys, known: folderNames,
                     key: "products.extraFrameworks", kind: "a shipped product")
    let kept = folders.filter { !products.withoutFolder.contains($0.name) }
    // Without the base folder (e.g. with `--product`), shared frameworks stay where they are.
    let base = products.base.flatMap { base in
      kept.contains { $0.name == base.product } ? base : nil
    }
    if let base {
      warnAboutUnknown(base.frameworks, known: shipped, key: "products.base.frameworks",
                       kind: "a framework or binary")
    }
    var plan = self
    // A new `Folder`, so `ownFrameworks` is back to `nil`: the final folders list what ships.
    plan.folders = kept.map { folder in
      var names = folder.frameworksToShip
      for extra in products.extraFrameworks[folder.name] ?? [] {
        if shipped.contains(extra) {
          names.insert(extra)
        } else {
          warnSkipped(extra, key: "products.extraFrameworks", kind: "a framework or binary")
        }
      }
      if let base, folder.name != base.product {
        names.subtract(base.frameworks)
      }
      return Folder(name: folder.name, frameworks: names.sorted(), files: folder.files)
    }.sorted { $0.name < $1.name }
    for entry in files {
      if let index = plan.folders.firstIndex(where: { $0.name == entry.to }) {
        plan.folders[index].files += entry.files
      } else if entry.to == zipRootFolder {
        plan.folders.insert(Folder(name: zipRootFolder, frameworks: [], files: entry.files), at: 0)
      } else {
        warnSkipped(entry.to, key: "zip.files", kind: "a folder")
      }
    }
    // Dependencies left out on purpose (`products.withoutDependencies`) aren't a mistake.
    let leftOut = Set(kept.flatMap(\.leftOutDependencies))
    let inFolders = Set(plan.folders.flatMap(\.frameworks))
    for name in shipped.sorted() where !inFolders.contains(name) && !leftOut.contains(name) {
      warn("\(name) is built but isn't in any folder.")
    }
    return plan
  }
}

private extension Folder {
  /// What the folder ships before the other `products` keys apply: its own frameworks when
  /// they're set, else everything it holds. Own frameworks are intersected with what it holds,
  /// so one that platform restriction dropped stays out.
  var frameworksToShip: Set<String> {
    let all = Set(frameworks)
    return ownFrameworks.map { all.intersection($0) } ?? all
  }

  /// The dependencies `ownFrameworks` leaves out of the folder; empty when it's not set.
  var leftOutDependencies: Set<String> {
    Set(frameworks).subtracting(frameworksToShip)
  }
}
