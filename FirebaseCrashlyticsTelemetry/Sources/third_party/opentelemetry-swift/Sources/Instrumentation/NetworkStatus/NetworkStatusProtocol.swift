/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(iOS) && !targetEnvironment(macCatalyst)

  import CoreTelephony
  import Foundation

  public protocol NetworkStatusProtocol {
    var networkMonitor: NetworkMonitorProtocol { get }
    func getStatus() -> (String, CTCarrier?)
  }
#endif // os(iOS) && !targetEnvironment(macCatalyst)
