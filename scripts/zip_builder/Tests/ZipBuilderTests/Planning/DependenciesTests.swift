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
import Testing
@testable import ZipBuilder

struct DependenciesTests {
  private func names(_ frameworks: [Framework]) -> [String] {
    frameworks.map(\.name)
  }

  @Test func dependenciesComeFirstAndTiesGoByName() {
    let frameworks = [
      SyntheticPackage.framework("A", dependencies: ["C"]),
      SyntheticPackage.framework("B"),
      SyntheticPackage.framework("C", dependencies: ["Outside"]), // not in the list: ignored
    ]
    #expect(names(sortedByDependencies(frameworks)) == ["B", "C", "A"])
  }

  /// A cycle doesn't hang: when nothing is ready, the first remaining framework by name goes
  /// next.
  @Test func cyclesAreBrokenByName() {
    let frameworks = [
      SyntheticPackage.framework("D", dependencies: ["A"]),
      SyntheticPackage.framework("B", dependencies: ["A"]),
      SyntheticPackage.framework("A", dependencies: ["B"]),
      SyntheticPackage.framework("C"),
    ]
    #expect(names(sortedByDependencies(frameworks)) == ["C", "A", "B", "D"])
    let selfCycle = [SyntheticPackage.framework("A", dependencies: ["A"])]
    #expect(names(sortedByDependencies(selfCycle)) == ["A"])
  }

  @Test func duplicatesWithoutPlatformsStayEverywhere() {
    #expect(mergingDuplicates([Dependency(name: "B"), Dependency(name: "A"), Dependency(name: "B")])
      == [Dependency(name: "A"), Dependency(name: "B")])
  }

  @Test func duplicatesGetTheUnionOfTheirPlatforms() {
    #expect(mergingDuplicates([Dependency(name: "A", platforms: [.ios]),
                               Dependency(name: "A", platforms: [.macos, .tvos])])
        == [Dependency(name: "A", platforms: [.ios, .macos, .tvos])])
  }

  /// `nil` means every platform, so it wins in either order.
  @Test func everyPlatformWins() {
    #expect(mergingDuplicates([Dependency(name: "A", platforms: [.ios]), Dependency(name: "A")])
      == [Dependency(name: "A")])
    #expect(mergingDuplicates([Dependency(name: "A"), Dependency(name: "A", platforms: [.ios])])
      == [Dependency(name: "A")])
  }

  @Test func aUnionOfEveryPlatformBecomesNil() {
    #expect(mergingDuplicates([Dependency(name: "A", platforms: [.ios, .catalyst, .macos]),
                               Dependency(name: "A", platforms: [.tvos, .watchos, .visionos])])
        == [Dependency(name: "A")])
  }

  /// An empty platform set applies nowhere, so it's dropped before merging.
  @Test func dependenciesThatApplyNowhereAreDropped() {
    #expect(mergingDuplicates([Dependency(name: "A", platforms: []),
                               Dependency(name: "B", platforms: [.ios]),
                               Dependency(name: "B", platforms: [])])
        == [Dependency(name: "B", platforms: [.ios])])
  }

  /// `nil` means every platform, for both the union and the intersection.
  @Test func platformSetAlgebra() {
    #expect(union([.ios], [.macos]) == [.ios, .macos])
    #expect(union([.ios], nil) == nil)
    #expect(union(nil, [.ios]) == nil)
    #expect(union([.ios, .catalyst, .macos], [.tvos, .watchos, .visionos]) == nil)
    #expect(union([], []) == [])
    #expect(intersection([.ios, .macos], [.macos]) == [.macos])
    #expect(intersection(nil, [.ios]) == [.ios])
    #expect(intersection(nil, nil) == nil)
  }

  /// A dependency's platforms are `nil` when they're all of its framework's own.
  @Test func ownPlatformsBecomeNil() {
    #expect(ownPlatformsAsNil([.ios, .macos], own: [.macos, .ios]) == nil)
    #expect(ownPlatformsAsNil([.ios], own: [.ios, .macos]) == [.ios])
    #expect(ownPlatformsAsNil([], own: [.ios]) == [])
  }
}
