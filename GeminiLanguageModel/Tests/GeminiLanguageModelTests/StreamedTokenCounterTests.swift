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

@testable import GeminiLanguageModel

@Suite("StreamedTokenCounter Tests")
struct StreamedTokenCounterTests {
  @Test
  func nextTokenCountReportsGrowthOfRunningTotal() {
    var counter = StreamedTokenCounter()

    let tokenCounts = [10, 25, 40].map { counter.nextTokenCount(forRunningTotal: $0) }

    #expect(tokenCounts == [10, 15, 15])
    #expect(counter.reportedTokenCount == 40)
  }

  @Test
  func nextTokenCountIsOneWithoutRunningTotal() {
    var counter = StreamedTokenCounter()

    let tokenCounts = [nil, nil, nil].map { counter.nextTokenCount(forRunningTotal: $0) }

    #expect(tokenCounts == [1, 1, 1])
    #expect(counter.reportedTokenCount == 3)
  }

  @Test
  func nextTokenCountIsOneWhenRunningTotalDoesNotGrow() {
    var counter = StreamedTokenCounter()

    let tokenCounts = [12, 12, 12].map { counter.nextTokenCount(forRunningTotal: $0) }

    #expect(tokenCounts == [12, 1, 1])
    #expect(counter.reportedTokenCount == 14)
  }

  @Test
  func nextTokenCountIsOneWhenRunningTotalDecreases() {
    var counter = StreamedTokenCounter()

    let tokenCounts = [20, 10].map { counter.nextTokenCount(forRunningTotal: $0) }

    #expect(tokenCounts == [20, 1])
    #expect(counter.reportedTokenCount == 21)
  }

  @Test
  func nextTokenCountCatchesUpWhenRunningTotalAppears() {
    var counter = StreamedTokenCounter()

    let tokenCounts = [nil, nil, 20].map { counter.nextTokenCount(forRunningTotal: $0) }

    #expect(tokenCounts == [1, 1, 18])
    #expect(counter.reportedTokenCount == 20)
  }
}
