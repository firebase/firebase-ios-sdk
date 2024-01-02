/*
 * Copyright 2019 Google
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

/// Convenience function for calling functions in the Shell. This should be used sparingly and only
/// when interacting with tools that can't be accessed directly in Swift (i.e. CocoaPods,
/// xcodebuild, etc). Intentionally empty, this enum is used as a namespace.
public enum Shell {}

public extension Shell {
  /// A type to represent the result of running a shell command.
  enum Result {
    /// The command was successfully run (based on the output code), with the output string as the
    /// associated value.
    case success(output: String)

    /// The command failed with a given exit code and output.
    case error(code: Int32, output: String)
  }

  /// Log without executing the shell commands.
  static var logOnly = false
  static func setLogOnly() {
    logOnly = true
  }

  /// Execute a command in the user's shell. This creates a temporary shell script and runs the
  /// command from there, instead of calling via `Process()` directly in order to include the
  /// appropriate environment variables. This is mostly for CocoaPods commands, but doesn't hurt
  /// other commands.
  ///
  /// - Parameters:
  ///   - command: The command to run in the shell.
  ///   - outputToConsole: A flag if the command output should be written to the console as well.
  ///   - workingDir: An optional working directory to run the shell command in.
  /// - Returns: A Result containing output information from the command.
  static func executeCommandFromScript(_ command: String,
                                       outputToConsole: Bool = true,
                                       workingDir: URL? = nil) -> Result {
    let scriptPath: URL
    do {
      let tempScriptsDir = FileManager.default.temporaryDirectory(withName: "temp_scripts")
      try FileManager.default.createDirectory(at: tempScriptsDir,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
      scriptPath = tempScriptsDir.appendingPathComponent("wrapper.sh")

      // Write the temporary script contents to the script's path. CocoaPods complains when LANG
      // isn't set in the environment, so explicitly set it here. The `/usr/local/git/current/bin`
      // is to allow the `sso` protocol if it's there.
      let contents = """
      export PATH="/usr/local/bin:/usr/local/git/current/bin:$PATH"
      export LANG="en_US.UTF-8"
      \(command)
      """
      try contents.write(to: scriptPath, atomically: true, encoding: .utf8)
    } catch let FileManager.FileError.failedToCreateDirectory(path, error) {
      fatalError("Could not execute shell command: \(command) - could not create temporary " +
        "script directory at \(path). \(error)")
    } catch {
      fatalError("Could not execute shell command: \(command) - unexpected error. \(error)")
    }

    // Remove the temporary script at the end of this function. If it fails, it's not a big deal
    // since it will be over-written next time and won't affect the Zip file, so we can ignore
    // any failure.
    defer { try? FileManager.default.removeItem(at: scriptPath) }

    // Let the process call directly into the temporary shell script we created.
    let task = Process()
    task.arguments = [scriptPath.path]

    if #available(OSX 10.13, *) {
      if let workingDir = workingDir {
        task.currentDirectoryURL = workingDir
      }

      // Explicitly use `/bin/bash`. Investigate whether or not we can use `/usr/local/env`
      task.executableURL = URL(fileURLWithPath: "/bin/bash")
    } else {
      // Assign the old `currentDirectoryPath` property if `currentDirectoryURL` isn't available.
      if let workingDir = workingDir {
        task.currentDirectoryPath = workingDir.path
      }
      task.launchPath = "/bin/bash"
    }

    // Assign a pipe to read as soon as data is available, log it to the console if requested, but
    // also keep an array of the output in memory so we can pass it back to functions.
    // Assign a pipe to grab the output, and handle it differently if we want to stream the results
    // to the console or not.
    let pipe = Pipe()
    task.standardOutput = pipe
    let outHandle = pipe.fileHandleForReading
    var output: [String] = []

    // If we want to output to the console, create a readabilityHandler and save each line along the
    // way. Otherwise, we can just read the pipe at the end. By disabling outputToConsole, some
    // commands (such as any xcodebuild) can run much, much faster.
    if outputToConsole {
      outHandle.readabilityHandler = { pipe in
        // This will be run any time data is sent to the pipe. We want to print it and store it for
        // later. Ignore any non-valid Strings.
        guard let line = String(data: pipe.availableData, encoding: .utf8) else {
          print("Could not get data from pipe for command \(command): \(pipe.availableData)")
          return
        }
        if line != "" {
          output.append(line)
        }
        print(line)
      }
      // Also set the termination handler on the task in order to stop the readabilityHandler from
      // parsing any more data from the task.
      task.terminationHandler = { t in
        guard let stdOut = t.standardOutput as? Pipe else { return }

        stdOut.fileHandleForReading.readabilityHandler = nil
      }
    }

    // Launch the task and wait for it to exit. This will trigger the above readabilityHandler
    // method and will redirect the command output back to the console for quick feedback.
    if outputToConsole {
      print("Running command: \(command).")
      print("----------------- COMMAND OUTPUT -----------------")
    }
    task.launch()
    // If we are not outputting to the console, there is a possibility that
    // the output pipe gets filled (e.g. when running a command that generates
    // lots of output). In this scenario, the process will hang and
    // `task.waitUntilExit()` will never return. To work around this issue,
    // calling `outHandle.readDataToEndOfFile()` before `task.waitUntilExit()`
    // will read from the pipe until the process ends.
    var outData: Data!
    if !outputToConsole {
      outData = outHandle.readDataToEndOfFile()
    }

    task.waitUntilExit()
    if outputToConsole { print("----------------- END COMMAND OUTPUT -----------------") }

    let fullOutput: String
    if outputToConsole {
      fullOutput = output.joined(separator: "\n")
    } else {
      // Force unwrapping since we know it's UTF8 coming from the console.
      fullOutput = String(data: outData, encoding: .utf8)!
    }

    // Check if the task succeeded or not, and return the failure code if it didn't.
    guard task.terminationStatus == 0 else {
      return Result.error(code: task.terminationStatus, output: fullOutput)
    }

    // The command was successful, return the output.
    return Result.success(output: fullOutput)
  }

  /// Execute a command in the user's shell. This creates a temporary shell script and runs the
  /// command from there, instead of calling via `Process()` directly in order to include the
  /// appropriate environment variables. This is mostly for CocoaPods commands, but doesn't hurt
  /// other commands.
  ///
  /// This is a variation of `executeCommandFromScript` that also does error handling internally.
  ///
  /// - Parameters:
  ///   - command: The command to run in the shell.
  ///   - outputToConsole: A flag if the command output should be written to the console as well.
  ///   - workingDir: An optional working directory to run the shell command in.
  /// - Returns: A Result containing output information from the command.
  static func executeCommand(_ command: String,
                             outputToConsole: Bool = true,
                             workingDir: URL? = nil) {
    if logOnly {
      print(command)
      return
    }
    let result = Shell.executeCommandFromScript(command, workingDir: workingDir)
    switch result {
    case let .error(code, output):
      fatalError("""
      `\(command)` failed with exit code \(code) while trying to install pods:

      Output from `\(command)`:
      \(output)
      """)
    case let .success(output):
      // Print the output to the console and return the information for all installed pods.
      print(output)
    }
  }
}
