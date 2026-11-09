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

#if compiler(>=6.4)
  extension Transcript {
    /// A mutable view over the conversation history in a transcript.
    ///
    /// - SeeAlso: [`Transcript.HistoryView`](https://developer.apple.com/documentation/foundationmodels/transcript/historyview)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct HistoryView: MutableCollection, RandomAccessCollection,
      RangeReplaceableCollection,
      Sendable
    {
      /// The element type of a history view.
      public typealias Element = Transcript.Entry

      /// A subrange slice of a history view.
      public typealias SubSequence = Transcript.HistoryView

      /// A collection of valid indices into a history view.
      public typealias Indices = Range<Transcript.HistoryView.Index>

      /// An iterator over the entries in a history view.
      public typealias Iterator = IndexingIterator<Transcript.HistoryView>

      /// The entries in the view.
      ///
      /// Its indices are the view's index offsets: a view read from a transcript with a leading
      /// instructions entry starts at offset 1, and slices keep their parent's offsets.
      var storage: ArraySlice<Transcript.Entry>

      /// Creates a view over `storage`, keeping its indices.
      init(storage: ArraySlice<Transcript.Entry>) {
        self.storage = storage
      }

      /// Creates an empty history view.
      public init() {
        self.storage = []
      }

      /// The position of the first entry in the history view.
      public var startIndex: Transcript.HistoryView.Index {
        Index(offset: storage.startIndex)
      }

      /// A position one past the last valid index in the history view.
      public var endIndex: Transcript.HistoryView.Index {
        Index(offset: storage.endIndex)
      }

      /// Accesses the entry at the specified index.
      ///
      /// - Parameter position: The index of the entry to access.
      /// - Returns: The entry at the given index.
      public subscript(position: Transcript.HistoryView.Index) -> Transcript.Entry {
        get {
          storage[position.offset]
        }
        set {
          storage[position.offset] = newValue
        }
      }

      /// Accesses a subview over the specified range of indices.
      ///
      /// - Parameter bounds: The range of indices to access.
      /// - Returns: A history view covering the specified range.
      public subscript(bounds: Range<Transcript.HistoryView.Index>) -> Transcript.HistoryView {
        get {
          HistoryView(storage: storage[Self.offsets(of: bounds)])
        }
        set {
          storage[Self.offsets(of: bounds)] = newValue.storage
        }
      }

      /// Replaces the specified subrange of entries with a new collection.
      ///
      /// - Parameters:
      ///   - subrange: The subrange of entries to replace.
      ///   - newElements: The new entries to insert.
      public mutating func replaceSubrange<C>(
        _ subrange: Range<Transcript.HistoryView.Index>,
        with newElements: C
      ) where C: Collection, C.Element == Transcript.Entry {
        storage.replaceSubrange(Self.offsets(of: subrange), with: newElements)
      }

      /// Appends a new entry to the end of the history view.
      ///
      /// - Parameter newElement: The entry to append.
      public mutating func append(_ newElement: Transcript.Entry) {
        storage.append(newElement)
      }

      /// Appends the elements of a sequence to the end of the history view.
      ///
      /// - Parameter newElements: The sequence of entries to append.
      public mutating func append(contentsOf newElements: some Sequence<Entry>) {
        storage.append(contentsOf: newElements)
      }

      /// Converts a range of view indices into the matching range of storage offsets.
      private static func offsets(of bounds: Range<Transcript.HistoryView.Index>) -> Range<Int> {
        bounds.lowerBound.offset..<bounds.upperBound.offset
      }
    }

    /// A view of the transcript's conversation history excluding any leading instructions.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var history: Transcript.HistoryView {
      get {
        HistoryView(storage: entries[leadingInstructionsCount...])
      }
      set {
        entries.replaceSubrange(leadingInstructionsCount..., with: newValue.storage)
      }
    }

    /// The number of leading instructions entries `history` excludes: 1 if the first entry is an
    /// instructions entry, otherwise 0.
    private var leadingInstructionsCount: Int {
      guard case .instructions = entries.first else { return 0 }
      return 1
    }
  }

  extension Transcript.HistoryView {
    /// A position in a transcript history view.
    ///
    /// - SeeAlso: [`Transcript.HistoryView.Index`](https://developer.apple.com/documentation/foundationmodels/transcript/historyview/index)
    public struct Index: Comparable, Hashable, Sendable, Strideable {
      /// The distance between two indices.
      public typealias Stride = Int

      /// The offset of the position in the view's storage.
      ///
      /// An index is an offset into the transcript the view was read from, so the first entry of a
      /// view that skips a leading instructions entry is at offset 1, and indices compare by offset
      /// even across different views.
      var offset: Int

      /// Returns a Boolean value indicating whether the first index precedes the second.
      ///
      /// - Parameters:
      ///   - lhs: The first index to compare.
      ///   - rhs: The second index to compare.
      /// - Returns: `true` if `lhs` precedes `rhs`.
      public static func < (
        lhs: Transcript.HistoryView.Index,
        rhs: Transcript.HistoryView.Index
      ) -> Bool {
        lhs.offset < rhs.offset
      }

      /// Returns the distance from this index to the given index.
      ///
      /// - Parameter other: The destination index.
      /// - Returns: The distance to `other`.
      public func distance(to other: Transcript.HistoryView.Index) -> Int {
        other.offset - offset
      }

      /// Returns an index offset by the specified distance.
      ///
      /// - Parameter n: The distance to advance.
      /// - Returns: An index advanced by `n`.
      public func advanced(by n: Int) -> Transcript.HistoryView.Index {
        Index(offset: offset + n)
      }

      /// Hashes the essential components of the index into the given hasher.
      ///
      /// - Parameter hasher: The hasher to use when combining components.
      public func hash(into hasher: inout Hasher) {
        hasher.combine(offset)
      }
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.HistoryView: ExpressibleByArrayLiteral {
    /// The type of elements in an array literal initializer.
    public typealias ArrayLiteralElement = Transcript.Entry

    /// Creates a history view containing the specified elements.
    ///
    /// - Parameter elements: A variadic list of entries.
    public init(arrayLiteral elements: Transcript.Entry...) {
      self.storage = ArraySlice(elements)
    }
  }
#endif  // compiler(>=6.4)
