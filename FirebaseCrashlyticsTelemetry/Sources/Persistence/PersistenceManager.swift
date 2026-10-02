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
internal import PersistenceWrapper

/// A thread-safe interface for the native persistence layer.
actor PersistenceManager {
  static let shared = PersistenceManager()

  private let persistenceFile = "crashlytics_persistence.clsrecord"
  private var persistenceBuffer: PersistenceBuffer?
  private var recoveryManager: RecoveredTelemetryExporter?

  private var isConfigured = false

  private enum PersistenceEvent {
    case spanStart(SpanData)
    case addAttribute(spanId: UInt64, key: String, value: String?)
    case spanEnd(spanId: UInt64, endTime: UInt64)
  }

  private var pendingEvents = [PersistenceEvent]()

  init() {}

  /// Initializes the manager and its underlying file handlers.
  ///
  /// - Parameter cacheDirectory: `URL` to the cache directory where the telemtry should be stored.
  func configure(recoveryManager: RecoveredTelemetryExporter) {
    ThreadHelper.isNotMainThread()

    self.recoveryManager = recoveryManager

    var recoveredSpansList: NSArray?
    let bufferFileURL = getCacheDirectory().appendingPathComponent(persistenceFile)
    let buffer = PersistenceWrapperFactory.initialize(
      filePath: bufferFileURL.path,
      bufferSize: .small,
      recoveredSpans: &recoveredSpansList
    )

    if let recovered = recoveredSpansList as? [PersistenceSpan], !recovered.isEmpty {
      uploadRecoveredSpans(spans: recovered)
    }

    if let activeBuffer = buffer {
      persistenceBuffer = activeBuffer
    } else {
      LoggingHelper.logger.error("Failed to initialize PersistenceBuffer at \(bufferFileURL.path)")
    }

    isConfigured = true
    flushPendingEvents()
  }

  // MARK: - SpanProcessor

  /// Records a newly started span to disk.
  ///
  /// - Parameter span: The active span data.
  public func onSpanStart(span: SpanData) {
    guard isConfigured else {
      pendingEvents.append(.spanStart(span))
      return
    }

    persistenceBuffer?.add(SpanAdapter.toPersistedSpan(spanData: span))
  }

  /// Updates the attributes for a span that has been persisted to disk.
  ///
  /// - Parameters:
  ///   - spanId: The ID of the span.
  ///   - key: The key for the attribute.
  ///   - value: The value for the attribute.
  public func onSpanAddAttribute(spanId: UInt64, key: String, value: String?) {
    guard isConfigured else {
      pendingEvents.append(.addAttribute(spanId: spanId, key: key, value: value))
      return
    }

    if let value {
      persistenceBuffer?.setAttribute(value, forKey: key, onSpanId: spanId)
    }
  }

  /// Marks an active span as complete and frees its allocated slot.
  ///
  /// - Parameter spanId: The ID of the span.
  public func onSpanEnd(spanId: UInt64, endTime: UInt64) {
    guard isConfigured else {
      pendingEvents.append(.spanEnd(spanId: spanId, endTime: endTime))
      return
    }

    persistenceBuffer?.endSpanId(spanId, endTime: endTime)
  }

  // MARK: - Private Helpers

  private func uploadRecoveredSpans(spans: [PersistenceSpan]) {
    var recoveredSpans = [RecoveredSpan]()
    for span in spans {
      recoveredSpans.append(SpanAdapter.toRecoveredSpan(spanData: span))
    }

    Task {
      await self.recoveryManager?.uploadRecoveredSpans(spans: recoveredSpans)
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

  private func flushPendingEvents() {
    for event in pendingEvents {
      switch event {
      case let .spanStart(span):
        onSpanStart(span: span)
      case let .addAttribute(spanId, key, value):
        onSpanAddAttribute(spanId: spanId, key: key, value: value)
      case let .spanEnd(spanId, endTime):
        onSpanEnd(spanId: spanId, endTime: endTime)
      }
    }

    pendingEvents.removeAll()
  }
}
