/*
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Dispatch
import Foundation

public extension Process {
  /// Creates a new `Process` instance without running it.
  ///
  /// - Parameters:
  ///   - exe: The executable to run.
  ///   - args: An array of arguments to pass to the executable.
  ///   - env: A map of environment variables to set for the process.
  ///   - inheritEnvironment: When enabled, the parent process' environvment will also be applied
  ///   to this process. Effectively, this means that any environvment variables declared within the
  ///   parent process will propagate down to this new process.
  convenience init(_ exe: String,
                   _ args: [String] = [],
                   env: [String: String] = [:],
                   inheritEnvironment: Bool = false) {
    self.init()
    executableURL = URL(filePath: "/usr/bin/env")
    arguments = [exe] + args
    environment = env
    if inheritEnvironment {
      mergeEnvironment(ProcessInfo.processInfo.environment)
    }
  }

  /// Merges the provided environment variables with this process' existing environment variables.
  ///
  /// If an environment variable is already set, then it will **NOT** be overwritten. Only
  /// environment variables not currently set on the process will be applied.
  ///
  /// - Parameters:
  ///   - env: The environment variables to merge with this process.
  func mergeEnvironment(_ env: [String: String]) {
    guard environment != nil else {
      // if this process doesn't have an environment, we can just set it instead of merging
      environment = env
      return
    }

    environment = environment?.merging(env) { current, _ in current }
  }

  /// Run the process with signals from the parent process.
  ///
  /// The signals `SIGINT` and `SIGTERM` will both be propagated
  /// down to the process from the parent process.
  ///
  /// This function will not return until the process is done running.
  ///
  /// - Parameters:
  ///   - args: Optionally provide an array of arguments to run the process with.
  ///
  /// - Returns: The exit code that the process completed with.
  @discardableResult
  func runWithSignals(_ args: [String]? = nil) throws -> Int32 {
    if let args {
      arguments = (arguments ?? []) + args
    }

    let sigint = bindSignal(signal: SIGINT) {
      if self.isRunning {
        self.interrupt()
      }
    }

    let sigterm = bindSignal(signal: SIGTERM) {
      if self.isRunning {
        self.terminate()
      }
    }

    sigint.resume()
    sigterm.resume()

    try run()
    waitUntilExit()

    return terminationStatus
  }
}

/// Binds a callback to a signal from the parent process.
///
/// ```swift
/// bindSignal(SIGINT) {
///  print("SIGINT was triggered")
/// }
/// ```
///
/// - Parameters:
///   - signal: The signal to listen for.
///   - callback: The function to invoke when the signal is received.
func bindSignal(signal value: Int32,
                callback: @escaping DispatchSourceProtocol
                  .DispatchSourceHandler) -> any DispatchSourceSignal {
  // allow the process to survive long enough to trigger the callback
  signal(value, SIG_IGN)

  let dispatch = DispatchSource.makeSignalSource(signal: value, queue: .main)
  dispatch.setEventHandler(handler: callback)

  return dispatch
}
