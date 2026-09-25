/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public enum Connection {
  case unavailable, wifi, cellular
}

public protocol NetworkMonitorProtocol {
  func getConnection() -> Connection
}
