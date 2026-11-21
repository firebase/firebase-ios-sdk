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
@preconcurrency import SourceControl

// The version of a dependency SwiftPM resolved to a branch or a revision instead of a tag, so its
// manifest has no version. See docs/how-it-works.md#planning.

/// The version the checkout at `path` is tagged with: the highest release tag (see
/// `releaseVersion(fromTag:)`) on its checked-out commit. A package resolved to a branch is usually
/// at a released commit (a release is tagged on `main`), and that tag is its real version.
/// `nil` when no such tag points at the commit, or `path` isn't a git checkout.
func taggedVersion(ofCheckoutAt path: AbsolutePath) -> String? {
  let checkout = GitRepository(path: path)
  guard let head = try? checkout.getCurrentRevision() else { return nil }
  let versions = ([checkout] + [localOrigin(of: checkout)].compactMap { $0 })
    .flatMap { repository in
      ((try? repository.getTags()) ?? []).compactMap { tag -> [Int]? in
        // Parse first, so only release tags are resolved (a git call each).
        guard let version = releaseVersion(fromTag: tag),
              (try? repository.resolveRevision(tag: tag)) == head else { return nil }
        return version
      }
    }
  return versions.max { $0.lexicographicallyPrecedes($1) }?
    .map(String.init).joined(separator: ".")
}

/// The local repository `checkout` was cloned from, if its `origin` is a local path. SwiftPM clones
/// each checkout from its mirror in `.build/repositories` and fetches new tags into the mirror
/// only,
/// so a tag made after the checkout was created is only there.
private func localOrigin(of checkout: GitRepository) -> GitRepository? {
  guard let origin = try? checkout.remotes().first(where: { $0.name == "origin" })?.url,
        let path = try? AbsolutePath(validating: origin),
        FileManager.default.fileExists(atPath: origin) else { return nil }
  let isWorkingCopy = FileManager.default.fileExists(atPath: path.appending(".git").pathString)
  return GitRepository(path: path, isWorkingRepo: isWorkingCopy)
}

/// The version a tag names, as its three numbers, for a release tag: `X.Y.Z` or `vX.Y.Z`, nothing
/// before or after it. Pre-release and prefixed tags (`1.0.0-beta`, `CocoaPods-1.0.0`) don't
/// count: they aren't the package's SwiftPM release version.
func releaseVersion(fromTag tag: String) -> [Int]? {
  let text = tag.hasPrefix("v") ? tag.dropFirst() : Substring(tag)
  let numbers = text.split(separator: ".", omittingEmptySubsequences: false)
  guard numbers.count == 3,
        numbers.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) })
  else { return nil }
  return numbers.compactMap { Int($0) }
}
