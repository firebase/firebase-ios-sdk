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

/// Instruments SwiftUI `Views` and reports when the active view changes.
///
/// Listens for view appear and disappear notifications on a background thread. Processes
/// the notifications in order to track and report the currently active screen.
final actor ViewInstrumentation {
  private var logger: Logger
  private var viewStack: [CrashlyticsView] = []
  private var lastReportedView: CrashlyticsView?
  private var reportingTask: Task<Void, Never>?

  public init(logger: Logger) {
    self.logger = logger
    configure()
  }

  /// Returns the currently active view, defaults to unknown if the view stack is empty.
  public var activeView: CrashlyticsView {
    if let view = viewStack.last {
      return view
    } else {
      return CrashlyticsView.unknown
    }
  }

  /// Configures the ViewInstrumentation to listen for view events.
  ///
  /// Spawns a background thread which processes an async stream of notifications in order.
  /// Calls the `handleViewEvent` on the actor thread when a view event notification
  /// is received.
  private nonisolated func configure() {
    Task(priority: .utility) {
      let stream = NotificationCenter.default.notifications(named: .viewTrackingEvent)
      for await notification in stream {
        guard let id = notification.userInfo?["id"] as? UUID,
              let screenName = notification.userInfo?["screenName"] as? String,
              let type = notification.userInfo?["type"] as? ViewEventType
        else { continue }

        await handleViewEvent(
          view: CrashlyticsView(id: id, name: screenName),
          type: type
        )
      }
    }
  }

  /// Handles a view event to update the screen stack and report the currently active screen.
  ///
  /// - Parameters:
  ///   - view: The Screen metadata being updated.
  ///   - type: Whether the screen appeared or disappeared.
  private func handleViewEvent(view: CrashlyticsView, type: ViewEventType) {
    switch type {
    case .appear:
      if let existingIndex = viewStack.firstIndex(of: view) {
        viewStack = Array(viewStack[...existingIndex])
      } else {
        viewStack.append(view)
      }
      scheduleReporting()

    case .disappear:
      if let index = viewStack.lastIndex(of: view) {
        viewStack.remove(at: index)
        scheduleReporting()
      }
    }
  }

  /// Coalesces rapid sequential view events to only report the final settled active screen.
  private func scheduleReporting() {
    reportingTask?.cancel()
    reportingTask = Task {
      do {
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        guard !Task.isCancelled else { return }

        let view = activeView
        if view != lastReportedView {
          reportActiveView(view)
          lastReportedView = view
        }
      } catch {
        // Catch cancellation/sleep errors silently
      }
    }
  }

  /// Reports the currently active View.
  private func reportActiveView(_ view: CrashlyticsView) {
    let attributes: [String: AttributeValue] = [
      SemanticConventions.App.screenName.rawValue: AttributeValue(view.name),
      SemanticConventions.App.navigationDestination: AttributeValue(view.name),
    ]

    logger
      .logRecordBuilder()
      .setEventName(SemanticConventions.App.navigationEvent)
      .setSeverity(.info)
      .setAttributes(attributes)
      .emit()
  }
}
