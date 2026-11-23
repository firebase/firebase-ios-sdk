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

import FirebaseCrashlytics
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Manages the recovery and export of telemetry data from previous app sessions.
actor RecoveryManager: RecoveredTelemetryExporter {
  /// The uploader to upload recovered telemetry
  private let uploader: any TelemetryUploading
  /// The instrumentation scope information associated with the exported traces.
  private var scope: InstrumentationScopeInfo?
  /// The resource metadata associated with the exported traces.
  private var resource: Resource?
  /// Provider used to resolve the app installation ID for resource attributes.
  private let installations: (any TelemetryInstallationsProvider)?
  /// Returns whether the application crashed during its previous run.
  private let didCrashDuringPreviousExecution: @Sendable () -> Bool

  /// Initializes a new recovery manager.
  ///
  /// - Parameters:
  ///   - uploader: The uploader responsible for sending serialized trace payloads.
  ///   - scope: The instrumentation scope info to include in trace exports.
  ///   - resource: The resource metadata to include in trace exports.
  ///   - installations: Provider for resolving the Firebase Installation ID.
  ///   - didCrashDuringPreviousExecution: Closure reporting whether the previous run crashed.
  public init(uploader: any TelemetryUploading,
              // TODO: Support persistence and recovery of these values instead of using
              // the ones on initialization.
              scope: InstrumentationScopeInfo? = nil,
              resource: Resource? = nil,
              installations: (any TelemetryInstallationsProvider)? = nil,
              didCrashDuringPreviousExecution: @escaping @Sendable () -> Bool = {
                Crashlytics.crashlytics().didCrashDuringPreviousExecution()
              }) {
    self.uploader = uploader
    self.scope = scope
    self.resource = resource
    self.installations = installations
    self.didCrashDuringPreviousExecution = didCrashDuringPreviousExecution
  }

  public func uploadRecoveredSpans(spans: [RecoveredSpan]) async {
    ThreadHelper.isNotMainThread()

    guard crashDidOccur() else {
      LoggingHelper.logger.info("Crash did not occur, skipping uploading \(spans.count) spans")
      return
    }

    let exportResource = await resolvedResource()
    let traceExportRequestPayloads = createTraceExportRequestPayloads(
      from: spans, resource: exportResource
    )

    // The implementation for the final network request is not robust as we may
    // decide to use GDT for this, which will provide the robustness.
    for payload in traceExportRequestPayloads {
      do {
        try await uploader.uploadTrace(payload)
      } catch {
        LoggingHelper.logger.debug("Failed to export trace. \(error)")
        continue
      }
    }
  }

  /// Resolves the installation ID if available and merges `service.instance.id` and
  /// `app.installation.id` into the export resource.
  private func resolvedResource() async -> Resource? {
    guard let installations else {
      return resource
    }

    if let existingResource = resource,
       existingResource.attributes[SemanticConventions.Service.instanceId.rawValue] != nil,
       existingResource.attributes[SemanticConventions.App.installationId.rawValue] != nil {
      return existingResource
    }

    do {
      let installationId = try await installations.installationID()
      let installationAttrs = AttributeStore.installationAttributes(installationId: installationId)
      guard !installationAttrs.isEmpty else {
        return resource
      }

      let merged = (resource ?? Resource(attributes: [:])).merging(
        other: Resource(attributes: installationAttrs)
      )
      resource = merged
      return merged
    } catch {
      LoggingHelper.logger.debug("Failed to resolve installation ID for telemetry: \(error)")
      return resource
    }
  }

  /// Returns a Boolean value indicating whether the application crashed during its previous run.
  ///
  /// - Returns: `true` if a crash occurred during the previous run; otherwise, `false`.
  private func crashDidOccur() -> Bool {
    return didCrashDuringPreviousExecution()
  }

  /// Makes 1-2KB sized chunks of the given spans and converts
  /// them into a serialized payload of ExportTraceServiceRequest's.
  ///
  /// - Parameters:
  ///   - spans: The array of spans to serialize.
  ///   - resource: The resolved resource metadata to attach to each export request.
  /// - Returns: An array of serialized trace export requests payloads.
  private func createTraceExportRequestPayloads(from spans: [RecoveredSpan],
                                                resource: Resource?) -> [Data] {
    // Each OpenTelemetry span is roughly 1-2 KB in size.
    // Limiting each export trace request to 512 spans set the max request size to ~1MB.
    let chunkLength = 512
    var traceExportPayloads: [Data] = []

    for startIdx in stride(from: 0, to: spans.count, by: chunkLength) {
      let endIdx = min(startIdx + chunkLength, spans.count)
      guard
        let payload = SpanAdapter.toTraceExportRequestPayload(
          spans: Array(spans[startIdx ..< endIdx]), scope: scope, resource: resource
        )
      else { continue }

      traceExportPayloads.append(payload)
    }

    return traceExportPayloads
  }
}
