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

import FirebaseCoreInternal
@testable import FirebaseStorage
import Foundation
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif
import XCTest

class StorageTaskEnqueueTests: StorageTestHelpers {
  func testDownloadResumeDuringProgressDoesNotStartAnotherRequest() async throws {
    let firstCallEntered = expectation(description: "Download setup enters service")
    let serviceGate = FirstCallServiceGate(firstCallEntered: firstCallEntered)
    let responseLatch = AsyncLatch()
    let requestCount = FetcherRequestCounter()
    let progressCount = FetcherRequestCounter()
    let progressObserved = expectation(description: "Resume from download progress")
    let completed = expectation(description: "Download completes")
    let transport = StorageTestTransport(reportingProgress: { request, progress in
      requestCount.increment()
      progress(HTTPTransferProgress(completedBytes: 1, expectedBytes: 1))
      await responseLatch.wait()
      return try (
        Data("download".utf8),
        StorageTestTransport.response(to: request, statusCode: 200)
      )
    })
    await StorageHTTPService.shared.updateTestTransport(transport)
    await StorageHTTPService.shared.updateSetupWaiterForTesting {
      await serviceGate.waitForFirstCall()
    }
    addTeardownBlock {
      responseLatch.release()
      await serviceGate.releaseFirstCall()
      await StorageHTTPService.shared.updateSetupWaiterForTesting(nil)
    }
    let task = rootReference().child("object").getData(maxSize: 1024) { data, error in
      XCTAssertNil(error)
      XCTAssertEqual(data, Data("download".utf8))
      completed.fulfill()
    }
    task.observe(.progress) { _ in
      guard progressCount.increment() == 1 else { return }
      // Make the transient progress phase deterministic before completion is released.
      task.stateLock.withLock { task.state = .progress }
      task.resume()
      XCTAssertTrue(task.hasTransferForTesting)
      progressObserved.fulfill()
      responseLatch.release()
    }
    await fulfillment(of: [firstCallEntered], timeout: 10)
    await serviceGate.releaseFirstCall()
    await fulfillment(of: [progressObserved, completed], timeout: 10)
    XCTAssertEqual(requestCount.value, 1)
  }

  func testUploadResumeDuringProgressDoesNotFireResumeEvent() async throws {
    let resumeInverted = expectation(description: "Resume event should not fire during progress")
    resumeInverted.isInverted = true
    let task = StorageUploadTask(
      reference: rootReference().child("object"),
      queue: DispatchQueue(label: "test"),
      data: Data("upload".utf8),
      metadata: StorageMetadata()
    )
    task.stateLock.withLock {
      task.state = .progress
    }
    task.observe(.resume) { _ in
      resumeInverted.fulfill()
    }
    task.resume()
    await fulfillment(of: [resumeInverted], timeout: 0.2)
    XCTAssertEqual(task.stateLock.withLock { task.state }, .progress)
  }

  func testUploadResumeDiscardsEarlierSetup() async throws {
    try await uploadResumeDiscardsEarlierSetup(pauseFirst: true)
  }

  func testImmediateUploadResumeDiscardsEarlierSetup() async throws {
    try await uploadResumeDiscardsEarlierSetup(pauseFirst: false)
  }

  private func uploadResumeDiscardsEarlierSetup(pauseFirst: Bool) async throws {
    let firstCallEntered = expectation(description: "Initial upload setup enters service")
    let serviceGate = FirstCallServiceGate(firstCallEntered: firstCallEntered)
    let discardedSetup = expectation(description: "Initial upload setup discarded")
    let requestCount = FetcherRequestCounter()
    let requestStarted = expectation(description: "Resumed upload starts one request")
    let testBlock: GTMSessionFetcherTestBlock = { fetcher, response in
      if requestCount.increment() == 1 {
        requestStarted.fulfill()
      }
      guard let responseURL = fetcher.request?.url else {
        XCTFail("Fetcher request should have a URL")
        return
      }
      response(
        HTTPURLResponse(
          url: responseURL,
          statusCode: 200,
          httpVersion: "HTTP/1.1",
          headerFields: nil
        ),
        Data("{}".utf8),
        nil
      )
    }
    await StorageFetcherService.shared.updateTestBlock(testBlock)
    await StorageFetcherService.shared.updateServiceWaiterForTesting {
      await serviceGate.waitForFirstCall()
    }
    addTeardownBlock {
      await serviceGate.releaseFirstCall()
      await StorageFetcherService.shared.updateTestBlock(nil)
      await StorageFetcherService.shared.updateServiceWaiterForTesting(nil)
    }

    let task = rootReference().child("object").putData(Data("upload".utf8))
    task.setupDiscardedHandlerForTesting = {
      discardedSetup.fulfill()
    }
    await fulfillment(of: [firstCallEntered], timeout: 10)

    if pauseFirst { task.pause() }
    task.resume()
    await fulfillment(of: [requestStarted], timeout: 10)
    XCTAssertTrue(task.hasFetcherForTesting)

    await serviceGate.releaseFirstCall()
    await fulfillment(of: [discardedSetup], timeout: 10)
    XCTAssertEqual(requestCount.value, 1)
  }

  func testDownloadResumeDiscardsEarlierSetup() async throws {
    try await downloadResumeDiscardsEarlierSetup(pauseFirst: true)
  }

  func testImmediateDownloadResumeDiscardsEarlierSetup() async throws {
    try await downloadResumeDiscardsEarlierSetup(pauseFirst: false)
  }

  private func downloadResumeDiscardsEarlierSetup(pauseFirst: Bool) async throws {
    let firstCallEntered = expectation(description: "Initial download setup enters service")
    let serviceGate = FirstCallServiceGate(firstCallEntered: firstCallEntered)
    let discardedSetup = expectation(description: "Initial download setup discarded")
    let requestCount = FetcherRequestCounter()
    let requestStarted = expectation(description: "Resumed download starts one request")
    let transport = StorageTestTransport { request in
      if requestCount.increment() == 1 {
        requestStarted.fulfill()
      }
      return try (
        Data("download".utf8),
        StorageTestTransport.response(to: request, statusCode: 200)
      )
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    await StorageHTTPService.shared.updateSetupWaiterForTesting {
      await serviceGate.waitForFirstCall()
    }
    addTeardownBlock {
      await serviceGate.releaseFirstCall()
      await StorageHTTPService.shared.updateSetupWaiterForTesting(nil)
    }

    let task = rootReference().child("object").getData(maxSize: 1024) { _, _ in }
    task.setupDiscardedHandlerForTesting = {
      discardedSetup.fulfill()
    }
    await fulfillment(of: [firstCallEntered], timeout: 10)

    if pauseFirst { task.pause() }
    task.resume()
    await fulfillment(of: [requestStarted], timeout: 10)

    await serviceGate.releaseFirstCall()
    await fulfillment(of: [discardedSetup], timeout: 10)
    XCTAssertEqual(requestCount.value, 1)
  }
}

private actor FirstCallServiceGate {
  let firstCallEntered: XCTestExpectation
  private var callCount = 0
  private var isReleased = false
  private var releaseContinuation: CheckedContinuation<Void, Never>?

  init(firstCallEntered: XCTestExpectation) {
    self.firstCallEntered = firstCallEntered
  }

  func waitForFirstCall() async {
    callCount += 1
    guard callCount == 1, !isReleased else { return }
    await withCheckedContinuation { continuation in
      releaseContinuation = continuation
      firstCallEntered.fulfill()
    }
  }

  func releaseFirstCall() {
    isReleased = true
    releaseContinuation?.resume()
    releaseContinuation = nil
  }
}

/// Suspends callers of `wait()` until `release()` is called.
private final class AsyncLatch: @unchecked Sendable {
  private let lock = NSLock()
  private var isReleased = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    await withCheckedContinuation { continuation in
      let isReleased = lock.withLock { () -> Bool in
        if !self.isReleased {
          waiters.append(continuation)
        }
        return self.isReleased
      }
      if isReleased {
        continuation.resume()
      }
    }
  }

  func release() {
    let waiters = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
      isReleased = true
      defer { self.waiters = [] }
      return self.waiters
    }
    waiters.forEach { $0.resume() }
  }
}

private final class FetcherRequestCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  @discardableResult
  func increment() -> Int {
    lock.withLock {
      count += 1
      return count
    }
  }

  var value: Int {
    lock.withLock { count }
  }
}
