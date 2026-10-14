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

/// Instruments SwiftUI `Views` and reports when the active screen changes.
///
/// Listens for screen appear and disappear notifications on a background thread. Processes
/// the notifications in order to track and report the currently active screen.
final actor ScreenInstrumentation {
  private var logger: Logger
  private var onChange: (@Sendable (String) -> Void)?
  private var screenStack: [CrashlyticsScreen] = []
  private var lastReportedScreen: CrashlyticsScreen?
  private var listeningTask: Task<Void, Never>?
  private var reportingTask: Task<Void, Never>?

  public init(logger: Logger, onChange: (@Sendable (String) -> Void)? = nil) {
    self.logger = logger
    self.onChange = onChange
    let stream = NotificationCenter.default.notifications(named: .screenTrackingEvent)
    Task { [weak self] in
      await self?.configure(with: stream)
    }
  }

  deinit {
    listeningTask?.cancel()
    reportingTask?.cancel()
  }

  /// Returns the currently active screen, defaults to unknown if the screen stack is empty.
  public var activeScreen: CrashlyticsScreen {
    if let screen = screenStack.last {
      return screen
    } else {
      return CrashlyticsScreen.unknown
    }
  }

  /// Configures the ScreenInstrumentation to listen for screen events.
  ///
  /// Spawns a background thread which processes an async stream of notifications in order.
  /// Calls the `handleScreenEvent` on the actor thread when a screen event notification
  /// is received.
  private func configure(with stream: NotificationCenter.Notifications) {
    listeningTask = Task(priority: .utility) { [weak self] in
      for await notification in stream {
        guard let self else { break }
        guard let id = notification.userInfo?["id"] as? UUID,
              let screenName = notification.userInfo?["screenName"] as? String,
              let type = notification.userInfo?["type"] as? ScreenEventType
        else { continue }

        await self.handleScreenEvent(
          screen: CrashlyticsScreen(id: id, name: screenName),
          type: type
        )
      }
    }
  }

  /// Handles a screen event to update the screen stack and report the currently active screen.
  ///
  /// - Parameters:
  ///   - screen: The Screen metadata being updated.
  ///   - type: Whether the screen appeared or disappeared.
  private func handleScreenEvent(screen: CrashlyticsScreen, type: ScreenEventType) {
    switch type {
    case .appear:
      if let existingIndex = screenStack.firstIndex(of: screen) {
        screenStack = Array(screenStack[...existingIndex])
      } else {
        screenStack.append(screen)
      }
      scheduleReporting()

    case .disappear:
      if let index = screenStack.lastIndex(of: screen) {
        screenStack.remove(at: index)
        scheduleReporting()
      }
    }
  }

  /// Coalesces rapid sequential screen events to only report the final settled active screen.
  private func scheduleReporting() {
    reportingTask?.cancel()
    reportingTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        guard !Task.isCancelled, let self else { return }

        await self.reportActiveScreenIfNeeded()
      } catch {
        // Catch cancellation/sleep errors silently
      }
    }
  }

  /// Reports the currently active Screen if it has changed since the last report.
  private func reportActiveScreenIfNeeded() {
    let screen = activeScreen
    guard screen != lastReportedScreen else { return }
    onChange?(screen.name)

    let attributes: [String: AttributeValue] = [
      SemanticConventions.App.crashlyticsNavigationDestination: AttributeValue(screen.name),
    ]

    logger
      .logRecordBuilder()
      .setEventName(SemanticConventions.App.crashlyticsNavigationEvent)
      .setSeverity(.info)
      .setAttributes(attributes)
      .emit()

    lastReportedScreen = screen
  }
}
