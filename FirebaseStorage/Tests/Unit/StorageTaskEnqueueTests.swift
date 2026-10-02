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
    let responseLatch = FetcherResponseLatch()
    let requestCount = FetcherRequestCounter()
    let progressCount = FetcherRequestCounter()
    let progressObserved = expectation(description: "Resume from download progress")
    let completed = expectation(description: "Download completes")
    let testBlock: GTMSessionFetcherTestBlock = { fetcher, response in
      requestCount.increment()
      guard let url = fetcher.request?.url else {
        XCTFail("Fetcher request should have a URL")
        return
      }
      responseLatch.install {
        response(
          HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil),
          Data("download".utf8),
          nil
        )
      }
      guard let receivedProgress = fetcher.receivedProgressBlock else {
        XCTFail("Download should install its received-progress callback")
        responseLatch.release()
        return
      }
      receivedProgress(1, 1)
    }
    await StorageFetcherService.shared.updateTestBlock(testBlock)
    await StorageFetcherService.shared.updateServiceWaiterForTesting {
      await serviceGate.waitForFirstCall()
    }
    addTeardownBlock {
      responseLatch.release()
      await serviceGate.releaseFirstCall()
      await StorageFetcherService.shared.updateTestBlock(nil)
      await StorageFetcherService.shared.updateServiceWaiterForTesting(nil)
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
      XCTAssertTrue(task.hasFetcherForTesting)
      progressObserved.fulfill()
      responseLatch.release()
    }
    await fulfillment(of: [firstCallEntered], timeout: 10)
    await serviceGate.releaseFirstCall()
    await fulfillment(of: [progressObserved, completed], timeout: 10)
    XCTAssertEqual(requestCount.value, 1)
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
        Data("download".utf8),
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

    let task = rootReference().child("object").getData(maxSize: 1024) { _, _ in }
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

private final class FetcherResponseLatch: @unchecked Sendable {
  private let lock = NSLock()
  private var response: (() -> Void)?
  private var isReleased = false

  func install(_ response: @escaping () -> Void) {
    let shouldRun = lock.withLock {
      if isReleased { return true }
      self.response = response
      return false
    }
    if shouldRun { response() }
  }

  func release() {
    let response = lock.withLock {
      isReleased = true
      let response = self.response
      self.response = nil
      return response
    }
    response?()
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
