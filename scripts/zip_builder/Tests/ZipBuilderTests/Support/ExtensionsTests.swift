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

import Testing
@testable import ZipBuilder

struct ExtensionsTests {
  @Test func uniquedKeepsTheFirstOfEachInOrder() {
    #expect(["b", "a", "b", "c", "a"].uniqued() == ["b", "a", "c"])
    #expect([String]().uniqued() == [])
  }

  @Test func uniquedByKeepsTheFirstWithEachKey() {
    let pairs = [(name: "Core", folder: "A"), (name: "Auth", folder: "A"),
                 (name: "Core", folder: "B")]
    let unique = pairs.uniqued(by: \.name)
    #expect(unique.map(\.name) == ["Core", "Auth"])
    #expect(unique.map(\.folder) == ["A", "A"])
  }

  @Test func unionFlattensAndKeepsTheFirstOfEachInOrder() {
    #expect([["b", "a"], ["a", "c"], ["b"]].union() == ["b", "a", "c"])
  }
}
