// Copyright 2021 Google LLC
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

// MARK: - `HeartbeatLogger` ObjC Interop

@objc(FIRInteropHeartbeatLogger)
@objcMembers
public final class _ObjCInteropHeartbeatLogger: NSObject {
  private let logger: HeartbeatLogger

  /// Designated initializer.
  /// - Parameter id: The `id` to associate this logger's internal storage with.
  public init(id: String) {
    logger = HeartbeatLogger(id: id)
  }

  public func log(_ info: String?) {
    logger.log(info)
  }

  // TODO: Change `Logger` protocol to take numerical limit instead of Int?
  public func flush(limit: NSInteger) -> _ObjCInteropHeartbeatData {
    let logs = logger.flush(limit: limit)
    return _ObjCInteropHeartbeatData(logs)
  }

  public func assertSwiftInteropWorksOnCI() -> Bool {
    true
  }
}

// MARK: - `HeartbeatData` ObjC Interop

@objc(FIRInteropHeartbeatData)
@objcMembers
public final class _ObjCInteropHeartbeatData: NSObject {
  private let heartbeatData: HeartbeatData

  init(_ value: HeartbeatData) {
    heartbeatData = value
  }
}

extension _ObjCInteropHeartbeatData: HTTPHeaderRepresentable {
  public func headerValue() -> String {
    heartbeatData.headerValue()
  }
}
