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

/// How many tasks `concurrentMap` runs at once by default: one per core.
private let defaultConcurrency = ProcessInfo.processInfo.activeProcessorCount

/// Maps `items` in parallel, at most `limit` at a time, keeping their order.
func concurrentMap<T: Sendable, R: Sendable>(_ items: [T], limit: Int = defaultConcurrency,
                                             _ transform: @escaping @Sendable (T) async throws -> R)
  async throws -> [R] {
  try await withThrowingTaskGroup(of: (Int, R).self) { group in
    var results = [R?](repeating: nil, count: items.count)
    for (index, item) in items.enumerated() {
      // Once `limit` tasks are running, wait for one to finish before starting the next.
      if index >= limit, let (done, result) = try await group.next() {
        results[done] = result
      }
      group.addTask { try (index, await transform(item)) }
    }
    for try await (done, result) in group {
      results[done] = result
    }
    return results.map { $0! }
  }
}
