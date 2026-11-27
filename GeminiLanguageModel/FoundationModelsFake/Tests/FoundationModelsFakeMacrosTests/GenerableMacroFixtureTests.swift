// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing

/// Snapshot tests for the `@Generable` expansions of the fixture types in `FixtureSource`.
@Suite
struct GenerableMacroFixtureTests {
  /// The expansion of each fixture type matches its recorded snapshot exactly.
  @Test(arguments: FixtureSource.names)
  func expansionMatchesSnapshot(name: String) throws {
    let source = try #require(FixtureSource.all[name])

    try assertExpansion(source, matchesSnapshot: "Fixtures/\(name)")
  }
}
