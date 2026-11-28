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

import FirebaseCore
internal import FirebaseCoreExtension
import FirebaseCoreTestHooks
import Foundation
import XCTest

/// Tests for FIRHeartbeatLogger. They run unchanged against the Objective-C and Swift
/// implementations of FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRHeartbeatLoggerTests.m. Instead of FirebaseCoreInternal's
/// `FIRHeartbeatsPayload` and `FIRHeartbeatLoggingTestUtils`, which go away when
/// FirebaseCoreInternal is folded into FirebaseCore, the tests decode the header value that
/// products send, which `-headerValue` and `-asyncHeaderValueWithCompletionHandler:` flush. The
/// loggers store heartbeats under test-only IDs, and the tests remove that storage before and
/// after each test. Unlike FIRHeartbeatLoggerTests.m, they leave other heartbeat storage alone.
///
/// The heartbeats are stored in Application Support (user defaults on tvOS). Tests that need a
/// stored heartbeat are skipped when that location isn't writable, as in a sandboxed shell.
final class HeartbeatLoggerTests: XCTestCase {
  private let storageID = "CoreSwiftUnit-HeartbeatLoggerTests"
  private let otherStorageID = "CoreSwiftUnit-HeartbeatLoggerTests-UserAgent"
  private let userAgent = "dummy_agent"

  override func setUp() {
    super.setUp()
    TestHeartbeatStorage.remove(storageID)
    TestHeartbeatStorage.remove(otherStorageID)
  }

  override func tearDown() {
    TestHeartbeatStorage.remove(storageID)
    TestHeartbeatStorage.remove(otherStorageID)
    super.tearDown()
  }

  // MARK: - Logging

  func testDoNotLogMoreThanOnceToday() throws {
    try requireWritableStorage()
    let logger = makeLogger()

    logger.log()
    logger.log()

    try assertHeader(logger.headerValue(), hasHeartbeatsFor: [userAgent])
  }

  func testDoNotLogMoreThanOnceTodayAfterFlushing() throws {
    try requireWritableStorage()
    let logger = makeLogger()

    logger.log()
    let firstHeader = logger.headerValue()
    logger.log()
    let secondHeader = logger.headerValue()

    try assertHeader(firstHeader, hasHeartbeatsFor: [userAgent])
    XCTAssertNil(secondHeader)
  }

  func testLoggersWithTheSameIDShareStorage() throws {
    try requireWritableStorage()
    let logger1 = makeLogger()
    let logger2 = makeLogger()

    logger1.log()

    try assertHeader(logger2.headerValue(), hasHeartbeatsFor: [userAgent])
    XCTAssertNil(logger1.headerValue())
  }

  func testLoggingAHeartbeatDoesNotDependOnUserAgent() throws {
    try requireWritableStorage()
    let agent = LockedValue("dummy_agent_1")
    let logger = FIRHeartbeatLogger(appID: otherStorageID) { agent.value }

    logger.log()
    let header = logger.headerValue()
    agent.value = "dummy_agent_2"
    logger.log()

    // The second agent doesn't make a second heartbeat on the same day.
    try assertHeader(header, hasHeartbeatsFor: ["dummy_agent_1"])
    XCTAssertNil(logger.headerValue())
  }

  // MARK: - Flushing with the daily heartbeat code (V1 API)

  func testHeartbeatCodeWhenHeartbeatsAreStored() throws {
    try requireWritableStorage()
    let logger = makeLogger()
    logger.log()
    XCTAssertEqual(logger.heartbeatCodeForToday(), FIRDailyHeartbeatCode.some)
  }

  func testHeartbeatCodeWhenNoHeartbeatsAreStored() {
    XCTAssertEqual(makeLogger().heartbeatCodeForToday(), FIRDailyHeartbeatCode.none)
  }

  // MARK: - Flushing into a header value (V2 API)

  func testHeaderValueWhenHeartbeatsAreStored() throws {
    try requireWritableStorage()
    let logger = makeLogger()
    logger.log()
    try assertHeader(logger.headerValue(), hasHeartbeatsFor: [userAgent])
  }

  func testAsyncHeaderValueWhenHeartbeatsAreStored() throws {
    try requireWritableStorage()
    let logger = makeLogger()
    logger.log()
    try assertHeader(asyncHeaderValue(of: logger), hasHeartbeatsFor: [userAgent])
  }

  func testHeaderValueWhenNoHeartbeatsAreStored() {
    XCTAssertNil(makeLogger().headerValue())
  }

  func testAsyncHeaderValueWhenNoHeartbeatsAreStored() {
    XCTAssertNil(asyncHeaderValue(of: makeLogger()))
  }

  // MARK: - Mixing the APIs

  func testHeartbeatCodeFlushesTodaysHeartbeatBeforeHeaderValue() throws {
    try requireWritableStorage()
    let logger = makeLogger()
    logger.log()

    let code = logger.heartbeatCodeForToday()
    let header = logger.headerValue()

    XCTAssertEqual(code, FIRDailyHeartbeatCode.some)
    XCTAssertNil(header)
  }

  func testHeaderValueFlushesTodaysHeartbeatBeforeHeartbeatCode() throws {
    try requireWritableStorage()
    let logger = makeLogger()
    logger.log()

    let header = logger.headerValue()
    let code = logger.heartbeatCodeForToday()

    try assertHeader(header, hasHeartbeatsFor: [userAgent])
    XCTAssertEqual(code, FIRDailyHeartbeatCode.none)
  }

  // MARK: - Header decoding

  /// The helper that decodes header values fails, rather than crashing, on malformed gzip data.
  func testHeaderDecoderRejectsMalformedGzip() {
    let header: [UInt8] = [0x1F, 0x8B, 8, 0, 0, 0, 0, 0, 0, 0]
    func withFlags(_ flags: UInt8) -> [UInt8] {
      var bytes = header
      bytes[3] = flags
      return bytes
    }
    let malformed: [(String, [UInt8])] = [
      ("shorter than a header and trailer", header + [0x41, 0x42]),
      ("FNAME without a terminator", withFlags(0x08) + [UInt8](repeating: 0x41, count: 20)),
      (
        "FEXTRA longer than the data",
        withFlags(0x04) + [0xFF, 0xFF] + [UInt8](repeating: 0, count: 8)
      ),
    ]
    for (name, bytes) in malformed {
      let base64url = Data(bytes).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
      XCTAssertThrowsError(try decodeHeartbeatsHeader(base64url), name)
    }
  }

  // MARK: - Helpers

  private func makeLogger() -> FIRHeartbeatLogger {
    let userAgent = userAgent
    return FIRHeartbeatLogger(appID: storageID) { userAgent }
  }

  private func requireWritableStorage() throws {
    try XCTSkipUnless(TestHeartbeatStorage.isWritable,
                      "Heartbeat storage isn't writable here, so no heartbeat can be stored")
  }

  private func asyncHeaderValue(of logger: FIRHeartbeatLogger) -> String? {
    let result = LockedValue<String?>(nil)
    let flushed = expectation(description: "The heartbeats are flushed")
    logger.asyncHeaderValue { headerValue in
      result.value = headerValue
      flushed.fulfill()
    }
    wait(for: [flushed], timeout: 1)
    return result.value
  }

  /// Checks that `header` holds one heartbeat for today for each agent.
  private func assertHeader(_ header: String?, hasHeartbeatsFor agents: [String],
                            file: StaticString = #filePath, line: UInt = #line) throws {
    let header = try XCTUnwrap(header, "No heartbeats were flushed", file: file, line: line)
    let payload = try decodeHeartbeatsHeader(header)
    let today = TestHeartbeatStorage.dateFormatter.string(from: Date())
    let expected: NSDictionary = [
      "version": 2,
      "heartbeats": agents.map { ["agent": $0, "dates": [today]] },
    ]
    XCTAssertEqual(payload, expected, file: file, line: line)
  }
}

/// A value that can be read and written from any thread.
final class LockedValue<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  init(_ value: Value) {
    _value = value
  }

  var value: Value {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _value
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _value = newValue
    }
  }
}

/// Where heartbeats are stored, so the tests can remove what they store.
enum TestHeartbeatStorage {
  /// The format of the heartbeat dates in the header value.
  static var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }

  #if os(tvOS)
    private static let userDefaults = UserDefaults(suiteName: "com.google.heartbeat.storage")

    static var isWritable: Bool { userDefaults != nil }

    static func remove(_ id: String) {
      userDefaults?.removeObject(forKey: "heartbeats-\(id)")
    }
  #else
    private static var directory: URL? {
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("google-heartbeat-storage", isDirectory: true)
    }

    /// Whether heartbeats can be stored, checked by writing and removing a file where they're
    /// stored.
    static var isWritable: Bool {
      guard let directory else { return false }
      let probe = directory.appendingPathComponent("heartbeats-CoreSwiftUnit-probe")
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: probe)
        try FileManager.default.removeItem(at: probe)
        return true
      } catch {
        return false
      }
    }

    static func remove(_ id: String) {
      let fileName = "heartbeats-\(id.replacingOccurrences(of: ":", with: "_"))"
      guard let file = directory?.appendingPathComponent(fileName) else { return }
      try? FileManager.default.removeItem(at: file)
    }
  #endif // os(tvOS)
}

/// Decodes a heartbeats header value: base64url-encoded, usually gzipped, JSON.
func decodeHeartbeatsHeader(_ header: String) throws -> NSDictionary {
  var base64 = header.replacingOccurrences(of: "-", with: "+")
    .replacingOccurrences(of: "_", with: "/")
  while base64.count % 4 != 0 {
    base64 += "="
  }
  var data = try XCTUnwrap(Data(base64Encoded: base64), "The header isn't base64url: \(header)")
  if data.starts(with: [0x1F, 0x8B]) {
    data = try gunzip(data)
  }
  return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
}

/// Why a heartbeats header couldn't be decoded.
private struct HeartbeatsHeaderError: Error, CustomStringConvertible {
  let description: String
}

/// Decompresses gzip data (RFC 1952). Throws instead of reading out of bounds when `data` is
/// malformed or truncated.
private func gunzip(_ data: Data) throws -> Data {
  let bytes = [UInt8](data)
  // A 10-byte header and an 8-byte trailer (CRC-32 and size) surround the DEFLATE data.
  let headerSize = 10, trailerSize = 8
  guard bytes.count >= headerSize + trailerSize,
        bytes[0] == 0x1F, bytes[1] == 0x8B, bytes[2] == 8 /* DEFLATE */ else {
    throw HeartbeatsHeaderError(description: "Not gzip data: \(bytes.count) bytes")
  }
  let end = bytes.count - trailerSize
  let flags = bytes[3]
  var offset = headerSize

  /// Moves past `count` bytes of the optional header fields.
  func skip(_ count: Int) throws {
    guard count <= end - offset else {
      throw HeartbeatsHeaderError(description: "Truncated gzip header")
    }
    offset += count
  }

  if flags & 0x04 != 0 { // FEXTRA: a 2-byte little-endian length, then that many bytes.
    try skip(2)
    try skip(Int(bytes[offset - 2]) | Int(bytes[offset - 1]) << 8)
  }
  for flag in [UInt8(0x08), 0x10] where flags & flag != 0 { // FNAME, FCOMMENT: zero-terminated.
    guard let terminator = bytes[offset ..< end].firstIndex(of: 0) else {
      throw HeartbeatsHeaderError(description: "Truncated gzip header")
    }
    offset = terminator + 1
  }
  if flags & 0x02 != 0 { // FHCRC
    try skip(2)
  }
  let deflated = Data(bytes[offset ..< end])
  return try (deflated as NSData).decompressed(using: .zlib) as Data
}
