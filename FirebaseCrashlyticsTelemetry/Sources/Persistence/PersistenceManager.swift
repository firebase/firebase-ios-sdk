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

private import FirebaseCoreInternal
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
internal import PersistenceWrapper

/// A thread-safe interface for the native persistence layer.
final class PersistenceManager: Sendable {
  static let shared = PersistenceManager()

  private let persistenceFile = "crashlytics_persistence.clsrecord"

  private enum PersistenceEvent {
    case spanStart(SpanData)
    case addAttribute(spanId: UInt64, key: String, value: String?)
    case spanEnd(spanId: UInt64, endTime: UInt64)
  }

  private struct State: @unchecked Sendable {
    var persistenceBuffer: PersistenceBuffer?
    var recoveryManager: RecoveredTelemetryExporter?
    var isConfigured = false
    var pendingEvents = [PersistenceEvent]()

    mutating func flushPendingEvents() {
      for event in pendingEvents {
        switch event {
        case let .spanStart(span):
          persistenceBuffer?.add(SpanAdapter.toPersistedSpan(spanData: span))
        case let .addAttribute(spanId, key, value):
          if let value {
            persistenceBuffer?.setAttribute(value, forKey: key, onSpanId: spanId)
          }
        case let .spanEnd(spanId, endTime):
          persistenceBuffer?.endSpanId(spanId, endTime: endTime)
        }
      }

      pendingEvents.removeAll()
    }
  }

  private let state = UnfairLock(State())

  init() {}

  /// Initializes the manager and its underlying file handlers.
  ///
  /// - Parameter recoveryManager: The exporter responsible for uploading recovered spans.
  func configure(recoveryManager: RecoveredTelemetryExporter) {
    ThreadHelper.isNotMainThread()

    var recoveredSpansList: NSArray?
    let bufferFileURL = getCacheDirectory().appendingPathComponent(persistenceFile)
    let buffer = PersistenceWrapperFactory.initialize(
      filePath: bufferFileURL.path,
      bufferSize: .small,
      recoveredSpans: &recoveredSpansList
    )

    if let recovered = recoveredSpansList as? [PersistenceSpan], !recovered.isEmpty {
      uploadRecoveredSpans(spans: recovered, recoveryManager: recoveryManager)
    }

    if buffer == nil {
      LoggingHelper.logger.error("Failed to initialize PersistenceBuffer at \(bufferFileURL.path)")
    }

    state.withLock { state in
      state.recoveryManager = recoveryManager
      if let activeBuffer = buffer {
        state.persistenceBuffer = activeBuffer
      }
      state.isConfigured = true
      state.flushPendingEvents()
    }
  }

  // MARK: - SpanProcessor

  /// Records a newly started span to disk.
  ///
  /// - Parameter span: The active span data.
  public func onSpanStart(span: SpanData) {
    let persistedSpan = SpanAdapter.toPersistedSpan(spanData: span)
    state.withLock { state in
      guard state.isConfigured else {
        state.pendingEvents.append(.spanStart(span))
        return
      }

      state.persistenceBuffer?.add(persistedSpan)
    }
  }

  /// Updates the attributes for a span that has been persisted to disk.
  ///
  /// - Parameters:
  ///   - spanId: The ID of the span.
  ///   - key: The key for the attribute.
  ///   - value: The value for the attribute.
  public func onSpanAddAttribute(spanId: UInt64, key: String, value: String?) {
    state.withLock { state in
      guard state.isConfigured else {
        state.pendingEvents.append(.addAttribute(spanId: spanId, key: key, value: value))
        return
      }

      if let value {
        state.persistenceBuffer?.setAttribute(value, forKey: key, onSpanId: spanId)
      }
    }
  }

  /// Marks an active span as complete and frees its allocated slot.
  ///
  /// - Parameter spanId: The ID of the span.
  public func onSpanEnd(spanId: UInt64, endTime: UInt64) {
    state.withLock { state in
      guard state.isConfigured else {
        state.pendingEvents.append(.spanEnd(spanId: spanId, endTime: endTime))
        return
      }

      state.persistenceBuffer?.endSpanId(spanId, endTime: endTime)
    }
  }

  // MARK: - Private Helpers

  private func uploadRecoveredSpans(spans: [PersistenceSpan],
                                    recoveryManager: RecoveredTelemetryExporter) {
    var recoveredSpans = [RecoveredSpan]()
    for span in spans {
      recoveredSpans.append(SpanAdapter.toRecoveredSpan(spanData: span))
    }

    Task {
      await recoveryManager.uploadRecoveredSpans(spans: recoveredSpans)
    }
  }

  /// Returns the directory URL for the application cache.
  ///
  /// Files in the created in the cache directory are encrypted by the OS.
  private func getCacheDirectory() -> URL {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      return URL.cachesDirectory
    } else {
      return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
  }
}
