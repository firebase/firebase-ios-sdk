import ArgumentParser
import Tests
import Logging
import Foundation

@main
struct Repo: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "repo",
    abstract: "CLI tools for managing the firebase-ios-sdk repository.",
    discussion: """
      A note on logging: by default, only log levels "info" and above are logged. For further \
      debugging, you can set the "LOG_LEVEL" environment variable to a different minimum level \
      (eg; "debug").
    """,
    subcommands: [
      Tests.self,
    ]
  )

  mutating func validate() throws {
    LoggingSystem.bootstrap { label in
      var handler = StreamLogHandler.standardOutput(label: label)
      if let level = ProcessInfo.processInfo.environment["LOG_LEVEL"] {
        if let parsedLevel = Logger.Level(rawValue: String(level)) {
          handler.logLevel = parsedLevel
          return handler
        } else {
          print(
            """
            [WARNING]: Unrecognized log level "\(level)"; defaulting to "info".
            Valid values: \(Logger.Level.allCases.map(\.rawValue))
            """
          )
        }
      }

      handler.logLevel = .info
      return handler
    }
  }
}
