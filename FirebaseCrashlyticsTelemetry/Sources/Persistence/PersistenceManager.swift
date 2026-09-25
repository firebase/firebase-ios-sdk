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
import PersistenceWrapper

/// A thread-safe interface for the native persistence layer.
actor PersistenceManager {
  private let persistenceFile = "crashlytics_persistence.clsrecord"

  private var persistenceBuffer: PersistenceBuffer?

  static let shared: PersistenceManager? = {
    /// Returns the directory URL for persistence storage within the application cache.
    ///
    /// Files here are encrypted by the OS. Since writes happen via `mmap`, physical file
    /// memory is owned, managed, and paged directly by the OS virtual memory system.
    let directory = if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      URL.cachesDirectory
    } else {
      FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    return PersistenceManager(cacheDirectory: directory)
  }()

  /// Initializes the manager and its underlying file handlers.
  ///
  /// - Parameter cacheDirectory: `URL` to the cache directory where the telemtry should be stored.
  init(cacheDirectory dir: URL) {
    ThreadHelper.isNotMainThread()

    let bufferFileURL = dir.appendingPathComponent(persistenceFile)

    var recoveredSpansList: NSArray?
    let buffer = PersistenceWrapperFactory.initialize(
      filePath: bufferFileURL.path,
      bufferSize: .small,
      recoveredSpans: &recoveredSpansList
    )

    if let recovered = recoveredSpansList as? [PersistenceSpan], !recovered.isEmpty {
      Self.uploadRecoveredSpans(spans: recovered)
    }

    if let activeBuffer = buffer {
      persistenceBuffer = activeBuffer
    } else {
      LoggingHelper.logger.error("Failed to initialize PersistenceBuffer at \(bufferFileURL.path)")
    }
  }

  // MARK: - SpanProcessor

  /// Records a newly started span to disk.
  ///
  /// - Parameter span: The active span data.
  public func onSpanStart(span: SpanData) {
    persistenceBuffer?.add(SpanAdapter.toPersistedSpan(spanData: span))
  }

  /// Updates the attributes for a span that has been persisted to disk.
  ///
  /// - Parameters:
  ///   - spanId: The ID of the span.
  ///   - key: The key for the attribute.
  ///   - value: The value for the attribute.
  public func onSpanAddAttribute(spanId: UInt64, key: String, value: String?) {
    if let value {
      persistenceBuffer?.setAttribute(value, forKey: key, onSpanId: spanId)
    }
  }

  /// Marks an active span as complete and frees its allocated slot.
  ///
  /// - Parameter spanId: The ID of the span.
  public func onSpanEnd(spanId: UInt64, endTime: UInt64) {
    persistenceBuffer?.endSpanId(spanId, endTime: endTime)
  }

  // MARK: - Upload Helper

  private static func uploadRecoveredSpans(spans: [PersistenceSpan]) {
    var recoveredSpans = [RecoveredSpan]()
    for span in spans {
      recoveredSpans.append(SpanAdapter.toRecoveredSpan(spanData: span))
    }

    Task {
      await CrashlyticsTelemetry.shared.recoveryManager?.uploadRecoveredSpans(spans: recoveredSpans)
    }
  }
}
