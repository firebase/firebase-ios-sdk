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

/// **[Experimental]** The log levels used by internal Firebase logging.
///
/// > Warning: This portable implementation is for development and testing use only. The Firebase
/// > Apple SDK is only officially supported on Apple platforms.
public enum FirebaseLoggerLevel: Int, Sendable {
  /// **[Experimental]** Error level, matches `ASL_LEVEL_ERR`.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  case error = 3

  /// **[Experimental]** Warning level, matches `ASL_LEVEL_WARNING`.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  case warning = 4

  /// **[Experimental]** Notice level, matches `ASL_LEVEL_NOTICE`.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  case notice = 5

  /// **[Experimental]** Info level, matches `ASL_LEVEL_INFO`.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  case info = 6

  /// **[Experimental]** Debug level, matches `ASL_LEVEL_DEBUG`.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  case debug = 7

  /// **[Experimental]** Minimum log level.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public static let min: FirebaseLoggerLevel = .error

  /// **[Experimental]** Maximum log level.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public static let max: FirebaseLoggerLevel = .debug
}
