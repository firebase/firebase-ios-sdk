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

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public final class MockLogger: @unchecked Sendable {
  public let inMemoryExporter: TestLogRecordExporter
  public let loggerProvider: LoggerProviderSdk
  public let logger: Logger

  /// Initializes an isolated logger and exporter for a test run.
  public init(instrumentationScopeName: String = "MockLogTests") {
    let exporter = TestLogRecordExporter()
    let processor = SimpleLogRecordProcessor(logRecordExporter: exporter)
    let provider = LoggerProviderBuilder().with(processors: [processor]).build()

    inMemoryExporter = exporter
    loggerProvider = provider
    logger = provider.get(instrumentationScopeName: instrumentationScopeName)
  }

  // MARK: - Exporter Controls & Querying

  public func exportedLogs() -> [ReadableLogRecord] {
    return inMemoryExporter.getFinishedLogRecords()
  }

  public func reset() {
    inMemoryExporter.reset()
  }

  public func waitForLogCount(_ count: Int,
                              timeout: TimeInterval = 2.0) async throws -> [ReadableLogRecord] {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      let records = exportedLogs()
      if records.count >= count {
        return records
      }
      try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }

    let finalRecords = exportedLogs()
    if finalRecords.count >= count {
      return finalRecords
    }
    throw XCTTimeoutError()
  }
}

// MARK: - In-Memory Log Exporter using OTel SDK Protocol

public final class TestLogRecordExporter: LogRecordExporter, @unchecked Sendable {
  private let lock = NSLock()
  private var records: [ReadableLogRecord] = []

  public init() {}

  public func export(logRecords: [ReadableLogRecord],
                     explicitTimeout: TimeInterval? = nil) -> ExportResult {
    lock.lock()
    records.append(contentsOf: logRecords)
    lock.unlock()
    return .success
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {}

  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    return .success
  }

  public func getFinishedLogRecords() -> [ReadableLogRecord] {
    lock.lock()
    defer { lock.unlock() }
    return records
  }

  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    records.removeAll()
  }
}
