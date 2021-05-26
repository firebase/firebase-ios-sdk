import Foundation

public struct Shell {
  static let shared = Shell()
  public init() {}
  @discardableResult
  public static func run(_ command: String, displayCommand: Bool = true,
           displayFailureResult: Bool = true) -> Int32 {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", command]
    task.launch()
    if displayCommand {
      print("[CoverageReportParser] Command:\(command)\n")
    }
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let log = String(data: data, encoding: .utf8)!
    if displayFailureResult, task.terminationStatus != 0 {
      print("-----Exit code: \(task.terminationStatus)")
      print("-----Log:\n \(log)")
    }
    return task.terminationStatus
  }
}
