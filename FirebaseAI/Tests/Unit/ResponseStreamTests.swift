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

#if compiler(>=6.2)
  @testable import FirebaseAILogic
  import Foundation
  import XCTest

  #if canImport(FoundationModels)
    import FoundationModels
  #endif // canImport(FoundationModels)

  final class ResponseStreamTests: XCTestCase {
    // MARK: - Helpers

    private static func makeRawResult(text: String,
                                      isComplete: Bool = false) ->
      GenerativeModelSession.ResponseStream<String, String>.RawResult {
      let rawContent = FirebaseAI.GeneratedContent(
        kind: .string(text),
        id: nil,
        isComplete: isComplete
      )
      let rawResponse = GenerateContentResponse(candidates: [])
      return GenerativeModelSession.ResponseStream<String, String>.RawResult(
        rawContent: rawContent,
        rawResponse: rawResponse
      )
    }

    // MARK: - Tests

    func testResponseStream_yieldsSnapshotsSuccessfully() async throws {
      let stream = GenerativeModelSession.ResponseStream<String, String> { context in
        await context.yield(Self.makeRawResult(text: "Chunk 1"))
        await context.yield(Self.makeRawResult(text: "Chunk 1 & 2", isComplete: true))
        await context.finish()
      }

      var snapshots: [GenerativeModelSession.ResponseStream<String, String>.Snapshot] = []
      for try await snapshot in stream {
        snapshots.append(snapshot)
      }

      XCTAssertEqual(snapshots.count, 2)
      XCTAssertEqual(snapshots[0].content, "Chunk 1")
      XCTAssertFalse(snapshots[0].rawContent.isComplete)
      XCTAssertEqual(snapshots[1].content, "Chunk 1 & 2")
      XCTAssertTrue(snapshots[1].rawContent.isComplete)
    }

    func testResponseStream_recoversFromIntermediateDecodingError() async throws {
      let stream = GenerativeModelSession.ResponseStream<String, String> { context in
        // Yield a bad chunk that will fail to decode in `resolveContent`
        // We use a different kind that String doesn't support (e.g., .null)
        let badRawContent = FirebaseAI.GeneratedContent(kind: .null, id: nil, isComplete: false)
        let badRawResult = GenerativeModelSession.ResponseStream<String, String>.RawResult(
          rawContent: badRawContent,
          rawResponse: GenerateContentResponse(candidates: [])
        )
        await context.yield(badRawResult)

        // Yield a good chunk
        await context.yield(Self.makeRawResult(text: "Good chunk", isComplete: true))
        await context.finish()
      }

      var snapshots: [GenerativeModelSession.ResponseStream<String, String>.Snapshot] = []
      for try await snapshot in stream {
        snapshots.append(snapshot)
      }

      // The bad chunk should be skipped by the iterator's loop
      XCTAssertEqual(snapshots.count, 1)
      XCTAssertEqual(snapshots[0].content, "Good chunk")
    }

    func testResponseStream_throwsIfLastChunkFailsToDecode() async {
      let stream = GenerativeModelSession.ResponseStream<String, String> { context in
        let badRawContent = FirebaseAI.GeneratedContent(kind: .null, id: nil, isComplete: true)
        let badRawResult = GenerativeModelSession.ResponseStream<String, String>.RawResult(
          rawContent: badRawContent,
          rawResponse: GenerateContentResponse(candidates: [])
        )
        await context.yield(badRawResult)
        await context.finish()
      }

      do {
        for try await _ in stream {
          XCTFail("Stream should have thrown an error but yielded a value instead.")
        }
        XCTFail("Stream iteration completed without throwing an error.")
      } catch {
        // Assert that the error is one of the expected decoding failure types.
        let isExpectedError: Bool
        if let genError = error as? GenerativeModelSession.GenerationError,
           case .decodingFailure = genError {
          isExpectedError = true
        } else if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *),
                  let foundationError = error as? FoundationModels.LanguageModelSession
                  .GenerationError,
                  case .decodingFailure = foundationError {
          isExpectedError = true
        } else {
          isExpectedError = false
        }
        XCTAssertTrue(
          isExpectedError,
          "Expected a decoding failure error, but got \(error) instead."
        )
      }
    }

    func testResponseStream_collectReturnsLatestChunk() async throws {
      let stream = GenerativeModelSession.ResponseStream<String, String> { context in
        await context.yield(Self.makeRawResult(text: "Chunk 1"))
        await context.yield(Self.makeRawResult(text: "Final Chunk", isComplete: true))
        await context.finish()
      }

      let response = try await stream.collect()
      XCTAssertEqual(response.content, "Final Chunk")
      XCTAssertTrue(response.rawContent.isComplete)
    }

    func testResponseStream_collectRespectsTaskCancellation() async {
      let task = Task<Void, Error> {
        let stream = GenerativeModelSession.ResponseStream<String, String> { _ in
          // Purposefully do not yield or finish to suspend forever
        }
        _ = try await stream.collect()
      }

      // Give the task a chance to start and suspend
      await Task.yield()
      task.cancel()

      do {
        _ = try await task.value
        XCTFail("Task should have been cancelled")
      } catch {
        XCTAssert(
          error is CancellationError,
          "Expected CancellationError, but got \(error) instead."
        )
      }
    }

    func testResponseStream_emptyStreamBehavior() async throws {
      let stream = GenerativeModelSession.ResponseStream<String, String> { context in
        // Finish immediately without yielding any results
        await context.finish()
      }

      // 1. Test iteration over an empty stream (should yield nothing and not throw)
      var snapshots: [GenerativeModelSession.ResponseStream<String, String>.Snapshot] = []
      for try await snapshot in stream {
        snapshots.append(snapshot)
      }
      XCTAssertTrue(snapshots.isEmpty, "Empty stream should not yield any snapshots.")

      // 2. Test collect() on an empty stream (should throw a decoding failure)
      do {
        _ = try await stream.collect()
        XCTFail("Collect on an empty stream should have thrown an error.")
      } catch let error as GenerativeModelSession.GenerationError {
        guard case let .decodingFailure(context) = error else {
          XCTFail("Expected decodingFailure, but got \(error).")
          return
        }
        XCTAssertEqual(context.debugDescription, "No content generated in stream.")
      } catch {
        XCTFail("Expected GenerativeModelSession.GenerationError, but got \(error).")
      }
    }
  }
#endif // compiler(>=6.2)
