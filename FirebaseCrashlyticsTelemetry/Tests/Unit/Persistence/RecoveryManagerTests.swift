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

import CrashlyticsTelemetryOTelProtos
import Foundation
import nanopb
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class RecoveryManagerTests: XCTestCase {
  private actor MockTelemetryUploader: TelemetryUploading {
    private(set) var uploadedPayloads: [Data] = []

    func uploadTrace(_ payload: Data) async throws {
      uploadedPayloads.append(payload)
    }
  }

  private enum MockError: Error {
    case installationsFailed
  }

  private func decodeResourceAttributes(from payload: Data) -> [String: String] {
    var request = opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest()
    let fieldsTuple = opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest_fields

    return withUnsafePointer(to: fieldsTuple) { fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      defer { pb_release(fields, &request) }

      let decoded = payload.withUnsafeBytes { rawBuffer -> Bool in
        guard let base = rawBuffer.baseAddress else { return false }
        var stream = pb_istream_from_buffer(
          base.assumingMemoryBound(to: pb_byte_t.self), rawBuffer.count
        )
        return pb_decode(&stream, fields, &request)
      }
      XCTAssertTrue(decoded, "Failed to decode ExportTraceServiceRequest")

      var result: [String: String] = [:]
      guard request.resource_spans_count > 0, let resourceSpans = request.resource_spans else {
        return result
      }
      let resource = resourceSpans[0].resource
      guard let attrs = resource.attributes else { return result }

      for i in 0 ..< Int(resource.attributes_count) {
        let kv = attrs[i]
        if let key = stringFromProtoBytes(kv.key),
           Int32(kv.value.which_value) == opentelemetry_proto_common_v1_AnyValue_string_value_tag,
           let val = stringFromProtoBytes(kv.value.string_value) {
          result[key] = val
        }
      }
      return result
    }
  }

  private func stringFromProtoBytes(_ pointer: UnsafeMutablePointer<pb_bytes_array_t>?) -> String? {
    guard let pointer else { return nil }
    let size = Int(pointer.pointee.size)
    let bytesStart = UnsafeRawPointer(pointer).advanced(by: MemoryLayout<pb_size_t>.size)
    let data = Data(bytes: bytesStart, count: size)
    return String(data: data, encoding: .utf8)
  }

  private func makeRecoveredSpan() -> RecoveredSpan {
    let spanData = MockTrace.mockSpan(name: "recovered_span")
    return SpanAdapter.toRecoveredSpan(spanData: SpanAdapter.toPersistedSpan(spanData: spanData))
  }

  func test_uploadRecoveredSpans_mergesInstallationIdIntoResource() async throws {
    let uploader = MockTelemetryUploader()
    let baseResource = Resource(attributes: [
      SemanticConventions.Service.name.rawValue: .string("1:123:ios:abc"),
      SemanticConventions.Gcp.crashlyticsFirebaseAppId: .string("1:123:ios:abc"),
    ])
    let scope = InstrumentationScopeInfo(
      name: FirebaseCrashlyticsTelemetry.scopeName,
      version: "13.0.0"
    )
    let manager = RecoveryManager(
      uploader: uploader,
      scope: scope,
      resource: baseResource,
      installations: MockInstallationsProvider(installationId: "resolved-fid-999"),
      didCrashDuringPreviousExecution: { true }
    )

    let span = makeRecoveredSpan()
    await Task.detached {
      await manager.uploadRecoveredSpans(spans: [span])
    }.value

    let payloads = await uploader.uploadedPayloads
    XCTAssertEqual(payloads.count, 1)

    let resourceAttrs = decodeResourceAttributes(from: try XCTUnwrap(payloads.first))
    XCTAssertEqual(resourceAttrs[SemanticConventions.Service.name.rawValue], "1:123:ios:abc")
    XCTAssertEqual(resourceAttrs[SemanticConventions.Gcp.crashlyticsFirebaseAppId], "1:123:ios:abc")
    XCTAssertEqual(
      resourceAttrs[SemanticConventions.Service.instanceId.rawValue],
      "resolved-fid-999"
    )
    XCTAssertEqual(
      resourceAttrs[SemanticConventions.App.installationId.rawValue],
      "resolved-fid-999"
    )
  }

  func test_uploadRecoveredSpans_whenInstallationsFails_stillUploadsBaseResource() async throws {
    let uploader = MockTelemetryUploader()
    let baseResource = Resource(attributes: [
      SemanticConventions.Service.name.rawValue: .string("1:123:ios:abc"),
    ])
    let manager = RecoveryManager(
      uploader: uploader,
      resource: baseResource,
      installations: MockInstallationsProvider(error: MockError.installationsFailed),
      didCrashDuringPreviousExecution: { true }
    )

    let span = makeRecoveredSpan()
    await Task.detached {
      await manager.uploadRecoveredSpans(spans: [span])
    }.value

    let payloads = await uploader.uploadedPayloads
    XCTAssertEqual(payloads.count, 1)

    let resourceAttrs = decodeResourceAttributes(from: try XCTUnwrap(payloads.first))
    XCTAssertEqual(resourceAttrs[SemanticConventions.Service.name.rawValue], "1:123:ios:abc")
    XCTAssertNil(resourceAttrs[SemanticConventions.Service.instanceId.rawValue])
    XCTAssertNil(resourceAttrs[SemanticConventions.App.installationId.rawValue])
  }

  func test_uploadRecoveredSpans_whenNoCrashOccurred_skipsUpload() async {
    let uploader = MockTelemetryUploader()
    let manager = RecoveryManager(
      uploader: uploader,
      installations: MockInstallationsProvider(installationId: "unused-fid"),
      didCrashDuringPreviousExecution: { false }
    )

    let span = makeRecoveredSpan()
    await Task.detached {
      await manager.uploadRecoveredSpans(spans: [span])
    }.value

    let payloads = await uploader.uploadedPayloads
    XCTAssertTrue(payloads.isEmpty)
  }
}
