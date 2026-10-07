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

/// A log record processor that enriches emitted log records with Crashlytics context
/// (such as `app.screen.name`) and forwards them to the configured exporter.
final class CrashlyticsLogProcessor: LogRecordProcessor, Sendable {
  private actor Exporter {
    private let logRecordExporter: LogRecordExporter

    init(logRecordExporter: LogRecordExporter) {
      self.logRecordExporter = logRecordExporter
    }

    func export(_ logRecord: ReadableLogRecord) {
      _ = logRecordExporter.export(logRecords: [logRecord], explicitTimeout: nil)
    }
  }

  private let exporter: Exporter

  init(logRecordExporter: LogRecordExporter) {
    exporter = Exporter(logRecordExporter: logRecordExporter)
  }

  func onEmit(logRecord: ReadableLogRecord) {
    let exporter = self.exporter
    Task {
      var enrichedRecord = logRecord
      let commonAttributes = await AttributeStore.commonLogAttributes()
      for (key, value) in commonAttributes {
        enrichedRecord.setAttribute(key: key, value: value)
      }
      await exporter.export(enrichedRecord)
    }
  }

  func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    return .success
  }

  func shutdown(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    return .success
  }
}
