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

// TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
#if compiler(>=6.2)
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  public extension GenerativeModel {
    struct ResponseStream<Content>: AsyncSequence, Sendable
      where Content: FirebaseGenerable & Sendable, Content.PartiallyGenerated: Sendable {
      public typealias Element = Snapshot
      public typealias AsyncIterator = AsyncThrowingStream<Snapshot, Error>.Iterator

      private let _stream: AsyncThrowingStream<Snapshot, Error>
      private let _context: StreamContext

      public struct Snapshot: Sendable {
        public let content: Content.PartiallyGenerated
        public let rawContent: FirebaseGeneratedContent
        public let rawResponse: GenerateContentResponse
      }

      init(_ builder: @escaping @Sendable (StreamContext) async -> Void) {
        var extractedContinuation: AsyncThrowingStream<Snapshot, Error>.Continuation!
        let stream = AsyncThrowingStream(Snapshot.self) { continuation in
          extractedContinuation = continuation
        }
        _stream = stream

        let context = StreamContext(continuation: extractedContinuation)
        _context = context

        Task {
          await builder(context)
        }
      }

      public func makeAsyncIterator() -> AsyncIterator {
        return _stream.makeAsyncIterator()
      }

      public nonisolated(nonsending) func collect()
        async throws -> sending GenerativeModel.Response<Content> {
        let finalResult = try await _context.value
        return try GenerativeModel.Response(
          content: Content(finalResult.rawContent),
          rawContent: finalResult.rawContent,
          rawResponse: finalResult.rawResponse
        )
      }
    }
  }

  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension GenerativeModel.ResponseStream {
    actor StreamContext {
      struct RawResult: Sendable {
        let rawContent: FirebaseGeneratedContent
        let rawResponse: GenerateContentResponse
      }

      private let continuation: AsyncThrowingStream<Snapshot, Error>.Continuation
      private var _finalResult: Result<RawResult, Error>?
      private var _waitingContinuations: [CheckedContinuation<RawResult, Error>] = []
      private var _latestRaw: RawResult?

      init(continuation: AsyncThrowingStream<Snapshot, Error>.Continuation) {
        self.continuation = continuation
      }

      func yield(_ snapshot: Snapshot) {
        _latestRaw = RawResult(rawContent: snapshot.rawContent, rawResponse: snapshot.rawResponse)
        continuation.yield(snapshot)
      }

      func finish() {
        continuation.finish()
        finalize(with: nil)
      }

      func finish(throwing error: Error) {
        continuation.finish(throwing: error)
        finalize(with: error)
      }

      var value: RawResult {
        get async throws {
          if let result = _finalResult {
            return try result.get()
          }
          return try await withCheckedThrowingContinuation { continuation in
            _waitingContinuations.append(continuation)
          }
        }
      }

      private func finalize(with error: Error?) {
        let result: Result<RawResult, Error>

        if let error = error {
          result = .failure(error)
        } else if let last = _latestRaw {
          result = .success(last)
        } else {
          result = .failure(ResponseStreamError.noContentGenerated)
        }

        _finalResult = result

        for continuation in _waitingContinuations {
          continuation.resume(with: result)
        }
        _waitingContinuations.removeAll()
      }
    }

    enum ResponseStreamError: Error {
      /// Thrown when `collect()` is called on a stream that finishes without producing any
      /// snapshots.
      case noContentGenerated
    }
  }
#endif // compiler(>=6.2)
