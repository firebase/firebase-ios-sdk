/*
 * Copyright 2021 Google LLC
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

import Foundation

public enum ProcessCom {
  case pipe
  case stdout
}

public enum Shell {
  @discardableResult
  public static func run(_ command: String, displayCommand: Bool = true,
                         displayFailureResult: Bool = true,
                         stdout: ProcessCom = .pipe) -> Int32 {
    let task = Process()
    let pipe = Pipe()
    if stdout == ProcessCom.pipe {
      task.standardOutput = pipe
    }
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", command]
    task.launch()
    if displayCommand {
      print("[Health Metrics] Command:\(command)\n")
    }
    task.waitUntilExit()
    if stdout == ProcessCom.pipe {
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let log = String(data: data, encoding: .utf8)!
      if displayFailureResult, task.terminationStatus != 0 {
        print("-----Exit code: \(task.terminationStatus)")
        print("-----Log:\n \(log)")
      }
    }
    return task.terminationStatus
  }
}
