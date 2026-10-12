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

/// An update of the session resumption state.
///
/// This message is only sent if ``SessionResumptionConfig`` was set in the
/// session setup.
@available(watchOS, unavailable)
public struct LiveSessionResumptionUpdate: Sendable {
  let bidiSessionResumptionUpdate: BidiSessionResumptionUpdate

  /// The new handle that represents the state that can be resumed. Empty if
  /// ``LiveSessionResumptionUpdate/resumable`` is false.
  public var newHandle: String? { bidiSessionResumptionUpdate.newHandle }

  /// Indicates if the session can be resumed at this point.
  public var resumable: Bool { bidiSessionResumptionUpdate.resumable ?? (newHandle != nil) }

  /// The index of the last client message that is included in the state
  /// represented by this update.
  public var lastConsumedClientMessageIndex: Int? {
    bidiSessionResumptionUpdate.lastConsumedClientMessageIndex
  }

  init(_ bidiSessionResumptionUpdate: BidiSessionResumptionUpdate) {
    self.bidiSessionResumptionUpdate = bidiSessionResumptionUpdate
  }
}
