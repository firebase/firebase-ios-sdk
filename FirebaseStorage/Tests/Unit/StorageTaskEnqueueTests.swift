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
  func testUploadResumeDiscardsEarlierSetup() async throws {
    let serviceGate = FirstCallServiceGate()
    let discardedSetup = AsyncSignal()
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
      await StorageFetcherService.shared.updateTestBlock(nil)
      await StorageFetcherService.shared.updateServiceWaiterForTesting(nil)
    }

    let task = rootReference().putData(Data("upload".utf8))
    task.setupDiscardedHandlerForTesting = {
      Task { await discardedSetup.signal() }
    }
    await serviceGate.waitUntilFirstCallEntered()

    task.pause()
    task.resume()
    await fulfillment(of: [requestStarted], timeout: 10)
    XCTAssertTrue(task.hasFetcherForTesting)

    await serviceGate.releaseFirstCall()
    await discardedSetup.wait()
    XCTAssertEqual(requestCount.value, 1)
  }

  func testDownloadResumeDiscardsEarlierSetup() async throws {
    let serviceGate = FirstCallServiceGate()
    let discardedSetup = AsyncSignal()
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
      await StorageFetcherService.shared.updateTestBlock(nil)
      await StorageFetcherService.shared.updateServiceWaiterForTesting(nil)
    }

    let reference = rootReference()
    let task = StorageDownloadTask(
      reference: reference,
      queue: reference.storage.dispatchQueue,
      file: nil
    )
    task.setupDiscardedHandlerForTesting = {
      Task { await discardedSetup.signal() }
    }
    task.enqueue()
    await serviceGate.waitUntilFirstCallEntered()

    task.pause()
    task.resume()
    await fulfillment(of: [requestStarted], timeout: 10)
    XCTAssertTrue(task.hasFetcherForTesting)

    await serviceGate.releaseFirstCall()
    await discardedSetup.wait()
    XCTAssertEqual(requestCount.value, 1)
  }
}

private actor FirstCallServiceGate {
  private var callCount = 0
  private var firstCallEntered = false
  private var entryContinuation: CheckedContinuation<Void, Never>?
  private var releaseContinuation: CheckedContinuation<Void, Never>?

  func waitForFirstCall() async {
    callCount += 1
    guard callCount == 1 else { return }
    await withCheckedContinuation { continuation in
      firstCallEntered = true
      releaseContinuation = continuation
      entryContinuation?.resume()
      entryContinuation = nil
    }
  }

  func waitUntilFirstCallEntered() async {
    guard !firstCallEntered else { return }
    await withCheckedContinuation { continuation in
      entryContinuation = continuation
    }
  }

  func releaseFirstCall() {
    releaseContinuation?.resume()
    releaseContinuation = nil
  }
}

private actor AsyncSignal {
  private var isSignaled = false
  private var continuation: CheckedContinuation<Void, Never>?

  func signal() {
    isSignaled = true
    continuation?.resume()
    continuation = nil
  }

  func wait() async {
    guard !isSignaled else { return }
    await withCheckedContinuation { continuation = $0 }
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
