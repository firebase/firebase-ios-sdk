
// MARK: - Variable Factory

public extension Expression {
  /// Creates a reference to a variable defined in the pipeline scope.
  ///
  /// - Parameter name: The name of the variable to reference.
  /// - Returns: A new `Variable` expression.
  static func variable(_ name: String) -> Variable {
    return Variable(name)
  }
}
