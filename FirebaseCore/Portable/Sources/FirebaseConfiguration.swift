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

/// **[Experimental]** Global configuration properties for Firebase SDKs.
///
/// > Warning: This portable implementation is for development and testing use only. The Firebase
/// > Apple SDK is only officially supported on Apple platforms.
public final class FirebaseConfiguration: Sendable {
  // MARK: - Shared Instance

  /// **[Experimental]** Returns the shared configuration object.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public static let shared = FirebaseConfiguration()

  // MARK: - Private Storage

  private let currentLoggerLevel = UnfairLock<FirebaseLoggerLevel>(.notice)

  private init() {}

  // MARK: - Logger Configuration

  /// **[Experimental]** Sets the logging level for internal Firebase logging.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameter loggerLevel: The maximum logging level. Defaults to `.notice`.
  public func setLoggerLevel(_ loggerLevel: FirebaseLoggerLevel) {
    currentLoggerLevel.withLock { $0 = loggerLevel }
  }

  /// **[Experimental]** Returns the logging level for internal Firebase logging.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Returns: The currently configured `FirebaseLoggerLevel`.
  public func loggerLevel() -> FirebaseLoggerLevel {
    currentLoggerLevel.value()
  }
}
