import Foundation

/// A reference wrapper around `NSLock` for thread safety.
/// Used as a replacement for `UnfairLock` to ensure Linux compatibility.
public final class UnfairLock<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  public init(_ value: Value) {
    _value = value
  }

  public func value() -> Value {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  @discardableResult
  public func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
    lock.lock()
    defer { lock.unlock() }
    return try body(&_value)
  }

  @discardableResult
  public func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
    lock.lock()
    defer { lock.unlock() }
    return body(&_value)
  }
}
