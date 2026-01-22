import Foundation

/// A generic circular queue structure.
struct RingBuffer<Element>: Sequence {
  private var circularQueue: [Element?]
  private var tailIndex: Array<Element?>.Index

  enum Error: Swift.Error {
    case outOfBoundsPush
  }

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
