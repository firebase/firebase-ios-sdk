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
  /// A recorded sequence of entries representing a conversation with a language model.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Transcript`](https://developer.apple.com/documentation/foundationmodels/transcript).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct Transcript: Sendable, Equatable {
    /// The entries of the transcript, in order.
    var entries: [Entry]

    /// Creates a transcript containing the given entries.
    ///
    /// - Parameter entries: The initial entries of the transcript.
    public init(entries: some Sequence<Entry> = []) {
      self.entries = Array(entries)
    }

    /// Returns a Boolean value indicating whether two transcripts are equal.
    ///
    /// - Parameters:
    ///   - a: The first transcript to compare.
    ///   - b: The second transcript to compare.
    /// - Returns: `true` if both transcripts contain equal entries.
    public static func == (a: Transcript, b: Transcript) -> Bool {
      a.entries == b.entries
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript: RandomAccessCollection {
    /// The index type for transcript entries.
    public typealias Index = Int

    /// A type representing valid indices into a transcript.
    public typealias Indices = Range<Transcript.Index>

    /// An iterator over the entries in a transcript.
    public typealias Iterator = IndexingIterator<Transcript>

    /// Accesses the entry at the specified position.
    ///
    /// - Parameter index: The position of the entry to access.
    /// - Returns: The entry at the specified index.
    public subscript(index: Transcript.Index) -> Transcript.Entry {
      get {
        entries[index]
      }
      set {
        entries[index] = newValue
      }
    }

    /// The position of the first entry in a non-empty transcript.
    public var startIndex: Int {
      entries.startIndex
    }

    /// A position one greater than the last valid subscript argument.
    public var endIndex: Int {
      entries.endIndex
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript: MutableCollection {
    /// The element type of a transcript collection.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias Element = Transcript.Entry

    /// A slice of transcript entries.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias SubSequence = Slice<Transcript>
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript: RangeReplaceableCollection {
    /// Creates an empty transcript.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init() {
      self.entries = []
    }

    /// Replaces the specified subrange of entries with the given elements.
    ///
    /// - Parameters:
    ///   - subrange: The subrange of entries to replace.
    ///   - newElements: The new entries to insert into the transcript.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public mutating func replaceSubrange<C>(
      _ subrange: Range<Int>,
      with newElements: consuming C
    ) where C: Collection, C.Element == Transcript.Entry {
      entries.replaceSubrange(subrange, with: newElements)
    }
  }
#endif  // compiler(>=6.4)
