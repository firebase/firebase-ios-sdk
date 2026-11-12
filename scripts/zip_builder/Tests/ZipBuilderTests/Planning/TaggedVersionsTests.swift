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
import Testing
@testable import ZipBuilder

struct TaggedVersionsTests {
  @Test func releaseTagsAreThreeNumbersWithAnOptionalV() {
    #expect(releaseVersion(fromTag: "12.1.0") == [12, 1, 0])
    #expect(releaseVersion(fromTag: "v5.3.1") == [5, 3, 1])
    #expect(releaseVersion(fromTag: "1.2025051202.0") == [1, 2_025_051_202, 0])
    for tag in ["CocoaPods-12.1.0", "12.1.0-beta", "12.1", "12.1.0.1", "12..0", "v", "main",
                "12.1.0+build", "１.２.３"] {
      #expect(releaseVersion(fromTag: tag) == nil, "\(tag)")
    }
  }

  @Test func checkoutGetsTheHighestReleaseTagOnItsCommit() async throws {
    let repository = try await GitRepositoryFixture()
    try await repository.commit()
    try await repository.tag("1.0.0") // an older commit's tag doesn't count
    try await repository.commit()
    try await repository.tag("1.1.0")
    try await repository.tag("v1.2.0")
    try await repository.tag("CocoaPods-9.0.0") // not a release tag
    try await repository.tag("2.0.0-beta") // nor is a pre-release
    #expect(taggedVersion(ofCheckoutAt: repository.path) == "1.2.0")
  }

  /// SwiftPM fetches new tags into its mirror in `.build/repositories`, which the checkout was
  /// cloned from, and not into the checkout.
  @Test func releaseTagInTheMirrorTheCheckoutWasClonedFromCounts() async throws {
    let source = try await GitRepositoryFixture()
    try await source.commit()
    let mirror = try await GitRepositoryFixture(cloning: source.path, bare: true)
    let checkout = try await GitRepositoryFixture(cloning: mirror.path, bare: false)
    try await mirror.tag("3.1.0") // tagged after the checkout was cloned
    #expect(taggedVersion(ofCheckoutAt: checkout.path) == "3.1.0")
  }

  @Test func checkoutWithoutAReleaseTagOnItsCommitHasNoVersion() async throws {
    let repository = try await GitRepositoryFixture()
    try await repository.commit()
    try await repository.tag("1.0.0")
    try await repository.commit()
    try await repository.tag("CocoaPods-1.1.0")
    #expect(taggedVersion(ofCheckoutAt: repository.path) == nil)
  }

  @Test func directoryThatIsNotACheckoutHasNoVersion() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/tagged-versions/\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    #expect(try taggedVersion(ofCheckoutAt: AbsolutePath(validating: directory.path)) == nil)
  }
}

/// A new git repository in a temporary directory, to commit and tag in.
private struct GitRepositoryFixture {
  let path: AbsolutePath

  init() async throws {
    path = try Self.newDirectory()
    try await git("init", "--quiet")
  }

  /// A clone of `source`: bare like SwiftPM's mirrors, or a working copy like its checkouts.
  init(cloning source: AbsolutePath, bare: Bool) async throws {
    path = try Self.newDirectory()
    try await shell("git", ["clone", "--quiet"] + (bare ? ["--bare"] : ["--shared"])
      + [source.pathString, path.pathString])
  }

  private static func newDirectory() throws -> AbsolutePath {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/tagged-versions/\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return try AbsolutePath(validating: directory.standardizedFileURL.path)
  }

  /// An empty commit, so each one is a new revision.
  func commit() async throws {
    try await git("-c", "user.name=Test", "-c", "user.email=test@example.com",
                  "commit", "--quiet", "--allow-empty", "-m", "Commit")
  }

  /// An annotated tag, like releases use, on the current commit.
  func tag(_ name: String) async throws {
    try await git("-c", "user.name=Test", "-c", "user.email=test@example.com",
                  "tag", "-a", name, "-m", name)
  }

  private func git(_ arguments: String...) async throws {
    try await shell("git", arguments, in: path.pathString)
  }
}
