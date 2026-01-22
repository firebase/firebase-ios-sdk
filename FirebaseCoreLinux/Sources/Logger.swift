import Foundation

/// The log levels used by internal logging.
public enum FirebaseLoggerLevel: Int {
  /// Error level.
  case error = 3
  /// Warning level.
  case warning = 4
  /// Notice level.
  case notice = 5
  /// Info level.
  case info = 6
  /// Debug level.
  case debug = 7
  /// Minimum log level.
  case min = 3
  /// Maximum log level.
  case max = 7
}

/// A wrapper for Firebase logging.
public class FirebaseLogger {
  /// Logs a given message at a given log level.
  ///
  /// - Parameters:
  ///   - level: The log level to use.
  ///   - service: The service name.
  ///   - code: The message code.
  ///   - message: The message string.
  public static func log(level: FirebaseLoggerLevel,
                         service: String,
                         code: String,
                         message: String) {
    // TODO: Integrate with GULLogger if available or needed.
    // For Linux, simple print to stderr/stdout is often sufficient or using standard Logger (SwiftLog).

    let levelStr: String
    switch level {
    case .error: levelStr = "ERROR"
    case .warning: levelStr = "WARNING"
    case .notice: levelStr = "NOTICE"
    case .info: levelStr = "INFO"
    case .debug: levelStr = "DEBUG"
    default: levelStr = "UNKNOWN"
    }

    // Format: [Service] Code - Message
    let output = "[\(levelStr)] \(service) - \(code): \(message)"
    print(output)
  }
}
