// Copyright 2025 Google LLC
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

import Foundation

/// Error types for `RingBuffer` operations.
enum RingBufferError: Swift.Error {
    case outOfBoundsPush
}

/// A generic circular queue structure.
struct RingBuffer<Element>: Sequence {
  private var circularQueue: [Element?]
  private var tailIndex: Array<Element?>.Index

  init(capacity: Int) {
    circularQueue = Array(repeating: nil, count: capacity)
    tailIndex = circularQueue.startIndex
  }

  @discardableResult
  mutating func push(_ element: Element) throws -> Element? {
    guard circularQueue.count > 0 else { return nil }

    let replaced = circularQueue[tailIndex]
    circularQueue[tailIndex] = element

    tailIndex += 1
    if tailIndex >= circularQueue.endIndex {
      tailIndex = circularQueue.startIndex
    }

    return replaced
  }

  @discardableResult
  mutating func pop() -> Element? {
    guard circularQueue.count > 0 else { return nil }

    tailIndex -= 1
    if tailIndex < circularQueue.startIndex {
      tailIndex = circularQueue.endIndex - 1
    }

    guard let popped = circularQueue[tailIndex] else {
      return nil
    }

    circularQueue[tailIndex] = nil

    return popped
  }

  func makeIterator() -> IndexingIterator<[Element]> {
    circularQueue
      .compactMap { $0 }
      .makeIterator()
  }
}

extension RingBuffer: Codable where Element: Codable {}
