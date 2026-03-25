
// MARK: - Variable Factory

public extension Expression {
  /// Creates a reference to a variable defined in the pipeline scope.
  ///
  /// Variables can be defined using the `define()` stage on a `Pipeline`. This is useful for passing
  /// values from an outer query into a subquery, or for calculating intermediate values that are reused
  /// multiple times in the pipeline.
  ///
  /// ```swift
  /// // Find products whose price is greater than the average price of products in the same category.
  /// firestore.pipeline().collection("products")
  ///   .define([Field("category").as("productCategory"), Field("price").as("productPrice")])
  ///   .addFields([
  ///      firestore.pipeline().collection("products")
  ///          .where(Field("category").equal(Expression.variable("productCategory")))
  ///          .aggregate([Field("price").average().as("avgPrice")])
  ///          .toScalarExpression().as("categoryAvgPrice")
  ///   ])
  ///   .where(Field("productPrice").greaterThan(Expression.variable("categoryAvgPrice")))
  /// ```
  ///
  /// - Parameter name: The name of the variable to reference.
  /// - Returns: A new `Variable` expression.
  static func variable(_ name: String) -> Variable {
    return Variable(name)
  }
}
