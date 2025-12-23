// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

public protocol Expression: Sendable {
  /// Casts the expression to a `BooleanExpression`.
  ///
  /// - Returns: A `BooleanExpression` representing the same expression.
  func asBoolean() -> BooleanExpression

  /// Assigns an alias to this expression.
  ///
  /// Aliases are useful for renaming fields in the output of a stage or for giving meaningful
  /// names to calculated values.
  ///
  /// ```swift
  /// // Calculate total price and alias it "totalPrice"
  /// Field("price").multiply(Field("quantity")).as("totalPrice")
  /// ```
  ///
  /// - Parameter name: The alias to assign to this expression.
  /// - Returns: A new `AliasedExpression` wrapping this expression with the alias.
  func `as`(_ name: String) -> AliasedExpression

  // --- Added Mathematical Operations ---

  /// Creates an expression that returns the value of self rounded to the nearest integer.
  ///
  /// ```swift
  /// // Get the value of the "amount" field rounded to the nearest integer.
  /// Field("amount").round()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the rounded number.
  func round() -> FunctionExpression

  /// Creates an expression that returns the square root of self.
  ///
  /// ```swift
  /// // Get the square root of the "area" field.
  /// Field("area").sqrt()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the square root of the number.
  func sqrt() -> FunctionExpression

  /// Creates an expression that returns the value of self raised to the power of self.
  ///
  /// Returns zero on underflow.
  ///
  /// ```swift
  /// // Get the value of the "amount" field raised to the power of 2.
  /// Field("amount").pow(2)
  /// ```
  ///
  /// - Parameter exponent: The exponent to raise self to.
  /// - Returns: A new `FunctionExpression` representing the power of the number.
  func pow(_ exponent: Sendable) -> FunctionExpression

  /// Creates an expression that returns the value of self raised to the power of self.
  ///
  /// Returns zero on underflow.
  ///
  /// ```swift
  /// // Get the value of the "amount" field raised to the power of the "exponent" field.
  /// Field("amount").pow(Field("exponent"))
  /// ```
  ///
  /// - Parameter exponent: The exponent to raise self to.
  /// - Returns: A new `FunctionExpression` representing the power of the number.
  func pow(_ exponent: Expression) -> FunctionExpression

  /// Creates an expression that returns the natural logarithm of self.
  ///
  /// ```swift
  /// // Get the natural logarithm of the "amount" field.
  /// Field("amount").ln()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the natural logarithm of the number.
  func ln() -> FunctionExpression

  /// Creates an expression that returns the largest numeric value that isn't greater than self.
  ///
  /// ```swift
  /// // Get the floor of the "amount" field.
  /// Field("amount").floor()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the floor of the number.
  func floor() -> FunctionExpression

  /// Creates an expression that returns e to the power of self.
  ///
  /// Returns zero on underflow and nil on overflow.
  ///
  /// ```swift
  /// // Get the exp of the "amount" field.
  /// Field("amount").exp()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the exp of the number.
  func exp() -> FunctionExpression

  /// Creates an expression that returns the smallest numeric value that isn't less than the number.
  ///
  /// ```swift
  /// // Get the ceiling of the "amount" field.
  /// Field("amount").ceil()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the ceiling of the number.
  func ceil() -> FunctionExpression

  /// Creates an expression that returns the absolute value of the number.
  ///
  /// ```swift
  /// // Get the absolute value of the "amount" field.
  /// Field("amount").abs()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the absolute value of the number.
  func abs() -> FunctionExpression

  /// Creates an expression that adds another expression to this expression.
  /// To add multiple expressions, chain calls to this method.
  /// Assumes `self` and the parameter evaluate to compatible types for addition (e.g., numbers, or
  /// string/array concatenation if supported by the specific "add" implementation).
  ///
  /// ```swift
  /// // Add the value of the "quantity" field and the "reserve" field.
  /// Field("quantity").add(Field("reserve"))
  ///
  /// // Add multiple numeric fields
  /// Field("subtotal").add(Field("tax")).add(Field("shipping"))
  /// ```
  ///
  /// - Parameter value: An `Expression` to add.
  /// - Returns: A new `FunctionExpression` representing the addition operation.
  func add(_ value: Expression) -> FunctionExpression

  /// Creates an expression that adds a literal value to this expression.
  /// To add multiple literals, chain calls to this method.
  /// Assumes `self` and the parameter evaluate to compatible types for addition.
  ///
  /// ```swift
  /// // Add 5 to the "count" field
  /// Field("count").add(5)
  ///
  /// // Add multiple literal numbers
  /// Field("score").add(10).add(20).add(-5)
  /// ```
  ///
  /// - Parameter value: A `Sendable` literal value to add.
  /// - Returns: A new `FunctionExpression` representing the addition operation.
  func add(_ value: Sendable) -> FunctionExpression

  /// Creates an expression that subtracts another expression from this expression.
  /// Assumes `self` and `other` evaluate to numeric types.
  ///
  /// ```swift
  /// // Subtract the "discount" field from the "price" field
  /// Field("price").subtract(Field("discount"))
  /// ```
  ///
  /// - Parameter other: The `Expression` (evaluating to a number) to subtract from this expression.
  /// - Returns: A new `FunctionExpression` representing the subtraction operation.
  func subtract(_ other: Expression) -> FunctionExpression

  /// Creates an expression that subtracts a literal value from this expression.
  /// Assumes `self` evaluates to a numeric type.
  ///
  /// ```swift
  /// // Subtract 20 from the value of the "total" field
  /// Field("total").subtract(20)
  /// ```
  ///
  /// - Parameter other: The `Sendable` literal (numeric) value to subtract from this expression.
  /// - Returns: A new `FunctionExpression` representing the subtraction operation.
  func subtract(_ other: Sendable) -> FunctionExpression

  /// Creates an expression that multiplies this expression by another expression.
  /// To multiply multiple expressions, chain calls to this method.
  /// Assumes `self` and the parameter evaluate to numeric types.
  ///
  /// ```swift
  /// // Multiply the "quantity" field by the "price" field
  /// Field("quantity").multiply(Field("price"))
  ///
  /// // Multiply "rate" by "time" and "conversionFactor" fields
  /// Field("rate").multiply(Field("time")).multiply(Field("conversionFactor"))
  /// ```
  ///
  /// - Parameter value: An `Expression` to multiply by.
  /// - Returns: A new `FunctionExpression` representing the multiplication operation.
  func multiply(_ value: Expression) -> FunctionExpression

  /// Creates an expression that multiplies this expression by a literal value.
  /// To multiply multiple literals, chain calls to this method.
  /// Assumes `self` evaluates to a numeric type.
  ///
  /// ```swift
  /// // Multiply the "score" by 1.1
  /// Field("score").multiply(1.1)
  ///
  /// // Multiply "base" by 2 and then by 3.0
  /// Field("base").multiply(2).multiply(3.0)
  /// ```
  ///
  /// - Parameter value: A `Sendable` literal value to multiply by.
  /// - Returns: A new `FunctionExpression` representing the multiplication operation.
  func multiply(_ value: Sendable) -> FunctionExpression

  /// Creates an expression that divides this expression by another expression.
  /// Assumes `self` and `other` evaluate to numeric types.
  ///
  /// ```swift
  /// // Divide the "total" field by the "count" field
  /// Field("total").divide(Field("count"))
  /// ```
  ///
  /// - Parameter other: The `Expression` (evaluating to a number) to divide by.
  /// - Returns: A new `FunctionExpression` representing the division operation.
  func divide(_ other: Expression) -> FunctionExpression

  /// Creates an expression that divides this expression by a literal value.
  /// Assumes `self` evaluates to a numeric type.
  ///
  /// ```swift
  /// // Divide the "value" field by 10
  /// Field("value").divide(10)
  /// ```
  ///
  /// - Parameter other: The `Sendable` literal (numeric) value to divide by.
  /// - Returns: A new `FunctionExpression` representing the division operation.
  func divide(_ other: Sendable) -> FunctionExpression

  /// Creates an expression that calculates the modulo (remainder) of dividing this expression by
  /// another expression.
  /// Assumes `self` and `other` evaluate to numeric types.
  ///
  /// ```swift
  /// // Calculate the remainder of dividing the "value" field by the "divisor" field
  /// Field("value").mod(Field("divisor"))
  /// ```
  ///
  /// - Parameter other: The `Expression` (evaluating to a number) to use as the divisor.
  /// - Returns: A new `FunctionExpression` representing the modulo operation.
  func mod(_ other: Expression) -> FunctionExpression

  /// Creates an expression that calculates the modulo (remainder) of dividing this expression by a
  /// literal value.
  /// Assumes `self` evaluates to a numeric type.
  ///
  /// ```swift
  /// // Calculate the remainder of dividing the "value" field by 10
  /// Field("value").mod(10)
  /// ```
  ///
  /// - Parameter other: The `Sendable` literal (numeric) value to use as the divisor.
  /// - Returns: A new `FunctionExpression` representing the modulo operation.
  func mod(_ other: Sendable) -> FunctionExpression

  // --- Added Array Operations ---

  /// Creates an expression that returns the `input` with elements in reverse order.
  ///
  /// ```swift
  /// // Reverse the "tags" array.
  /// Field("tags").arrayReverse()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the reversed array.
  func arrayReverse() -> FunctionExpression

  /// Creates an expression that concatenates an array expression (from `self`) with one or more
  /// other array expressions.
  /// Assumes `self` and all parameters evaluate to arrays.
  ///
  /// ```swift
  /// // Combine the "items" array with "otherItems" and "archiveItems" array fields.
  /// Field("items").arrayConcat(Field("otherItems"), Field("archiveItems"))
  /// ```
  /// - Parameter arrays: An array of at least one `Expression` (evaluating to an array) to
  /// concatenate.
  /// - Returns: A new `FunctionExpression` representing the concatenated array.
  func arrayConcat(_ arrays: [Expression]) -> FunctionExpression

  /// Creates an expression that concatenates an array expression (from `self`) with one or more
  /// array literals.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Combine "tags" (an array field) with ["new", "featured"] and ["urgent"]
  /// Field("tags").arrayConcat(["new", "featured"], ["urgent"])
  /// ```
  /// - Parameter arrays: An array of at least one `Sendable` values to concatenate.
  /// - Returns: A new `FunctionExpression` representing the concatenated array.
  func arrayConcat(_ arrays: [[Sendable]]) -> FunctionExpression

  /// Creates an expression that checks if an array (from `self`) contains a specific element
  /// expression.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "sizes" contains the value from "selectedSize" field
  /// Field("sizes").arrayContains(Field("selectedSize"))
  /// ```
  ///
  /// - Parameter element: The `Expression` representing the element to search for in the array.
  /// - Returns: A new `BooleanExpr` representing the "array_contains" comparison.
  func arrayContains(_ element: Expression) -> BooleanExpression

  /// Creates an expression that checks if an array (from `self`) contains a specific literal
  /// element.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "colors" array contains "red"
  /// Field("colors").arrayContains("red")
  /// ```
  ///
  /// - Parameter element: The `Sendable` literal element to search for in the array.
  /// - Returns: A new `BooleanExpr` representing the "array_contains" comparison.
  func arrayContains(_ element: Sendable) -> BooleanExpression

  /// Creates an expression that checks if an array (from `self`) contains all the specified element
  /// expressions.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "candidateSkills" contains all skills from "requiredSkill1" and "requiredSkill2"
  /// fields
  /// Field("candidateSkills").arrayContainsAll([Field("requiredSkill1"), Field("requiredSkill2")])
  /// ```
  ///
  /// - Parameter values: A list of `Expression` elements to check for in the array represented
  /// by `self`.
  /// - Returns: A new `BooleanExpr` representing the "array_contains_all" comparison.
  func arrayContainsAll(_ values: [Expression]) -> BooleanExpression

  /// Creates an expression that checks if an array (from `self`) contains all the specified literal
  /// elements.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "tags" contains both "urgent" and "review"
  /// Field("tags").arrayContainsAll(["urgent", "review"])
  /// ```
  ///
  /// - Parameter values: An array of at least one `Sendable` element to check for in the array.
  /// - Returns: A new `BooleanExpr` representing the "array_contains_all" comparison.
  func arrayContainsAll(_ values: [Sendable]) -> BooleanExpression

  /// Creates an expression that checks if an array (from `self`) contains all the specified element
  /// expressions.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if the "tags" array contains "foo", "bar", and "baz"
  /// Field("tags").arrayContainsAll(Constant(["foo", "bar", "baz"]))
  /// ```
  ///
  /// - Parameter values: An `Expression` elements evaluated to be array.
  /// - Returns: A new `BooleanExpr` representing the "array_contains_all" comparison.
  func arrayContainsAll(_ arrayExpression: Expression) -> BooleanExpression

  /// Creates an expression that checks if an array (from `self`) contains any of the specified
  /// element expressions.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "userGroups" contains any group from "allowedGroup1" or "allowedGroup2" fields
  /// Field("userGroups").arrayContainsAny([Field("allowedGroup1"), Field("allowedGroup2")])
  /// ```
  ///
  /// - Parameter values: A list of `Expression` elements to check for in the array.
  /// - Returns: A new `BooleanExpr` representing the "array_contains_any" comparison.
  func arrayContainsAny(_ values: [Expression]) -> BooleanExpression

  /// Creates an expression that checks if an array (from `self`) contains any of the specified
  /// literal elements.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "categories" contains either "electronics" or "books"
  /// Field("categories").arrayContainsAny(["electronics", "books"])
  /// ```
  ///
  /// - Parameter values: An array of at least one `Sendable` element to check for in the array.
  /// - Returns: A new `BooleanExpr` representing the "array_contains_any" comparison.
  func arrayContainsAny(_ values: [Sendable]) -> BooleanExpression

  /// Creates an expression that checks if an array (from `self`) contains any of the specified
  /// element expressions.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "groups" array contains any of the values from the "userGroup" field
  /// Field("groups").arrayContainsAny(Field("userGroup"))
  /// ```
  ///
  /// - Parameter arrayExpression: An `Expression` elements evaluated to be array.
  /// - Returns: A new `BooleanExpr` representing the "array_contains_any" comparison.
  func arrayContainsAny(_ arrayExpression: Expression) -> BooleanExpression

  /// Creates an expression that calculates the length of an array.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Get the number of items in the "cart" array
  /// Field("cart").arrayLength()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the length of the array.
  func arrayLength() -> FunctionExpression

  /// Creates an expression that accesses an element in an array (from `self`) at the specified
  /// integer offset.
  /// A negative offset starts from the end. If the offset is out of bounds, an error may be
  /// returned during evaluation.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Return the value in the "tags" field array at index 1.
  /// Field("tags").arrayGet(1)
  /// // Return the last element in the "tags" field array.
  /// Field("tags").arrayGet(-1)
  /// ```
  ///
  /// - Parameter offset: The literal `Int` offset of the element to return.
  /// - Returns: A new `FunctionExpression` representing the "arrayGet" operation.
  func arrayGet(_ offset: Int) -> FunctionExpression

  /// Creates an expression that accesses an element in an array (from `self`) at the offset
  /// specified by an expression.
  /// A negative offset starts from the end. If the offset is out of bounds, an error may be
  /// returned during evaluation.
  /// Assumes `self` evaluates to an array and `offsetExpr` evaluates to an integer.
  ///
  /// ```swift
  /// // Return the value in the tags field array at index specified by field "favoriteTagIndex".
  /// Field("tags").arrayGet(Field("favoriteTagIndex"))
  /// ```
  ///
  /// - Parameter offsetExpression: An `Expression` (evaluating to an Int) representing the offset
  /// of the
  /// element to return.
  /// - Returns: A new `FunctionExpression` representing the "arrayGet" operation.
  func arrayGet(_ offsetExpression: Expression) -> FunctionExpression

  /// Creates an expression that returns the maximum element of an array.
  ///
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Get the maximum value in the "scores" array.
  /// Field("scores").arrayMaximum()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the maximum element of the array.
  func arrayMaximum() -> FunctionExpression

  /// Creates an expression that returns the minimum element of an array.
  ///
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Get the minimum value in the "scores" array.
  /// Field("scores").arrayMinimum()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the minimum element of the array.
  func arrayMinimum() -> FunctionExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is greater
  /// than the given expression.
  ///
  /// - Parameter other: The expression to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func greaterThan(_ other: Expression) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is greater
  /// than the given value.
  ///
  /// - Parameter other: The value to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func greaterThan(_ other: Sendable) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is
  /// greater than or equal to the given expression.
  ///
  /// - Parameter other: The expression to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func greaterThanOrEqual(_ other: Expression) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is
  /// greater than or equal to the given value.
  ///
  /// - Parameter other: The value to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func greaterThanOrEqual(_ other: Sendable) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is less
  /// than the given expression.
  ///
  /// - Parameter other: The expression to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func lessThan(_ other: Expression) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is less
  /// than the given value.
  ///
  /// - Parameter other: The value to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func lessThan(_ other: Sendable) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is less
  /// than or equal to the given expression.
  ///
  /// - Parameter other: The expression to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func lessThanOrEqual(_ other: Expression) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is less
  /// than or equal to the given value.
  ///
  /// - Parameter other: The value to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func lessThanOrEqual(_ other: Sendable) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is equal
  /// to the given expression.
  ///
  /// - Parameter other: The expression to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func equal(_ other: Expression) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is equal
  /// to the given value.
  ///
  /// - Parameter other: The value to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func equal(_ other: Sendable) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is not
  /// equal to the given expression.
  ///
  /// - Parameter other: The expression to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func notEqual(_ other: Expression) -> BooleanExpression

  /// Creates a `BooleanExpression` that returns `true` if this expression is not
  /// equal to the given value.
  ///
  /// - Parameter other: The value to compare against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func notEqual(_ other: Sendable) -> BooleanExpression

  /// Creates an expression that checks if this expression is equal to any of the provided
  /// expression values.
  ///
  /// ```swift
  /// // Check if "categoryID" field is equal to "featuredCategory" or "popularCategory" fields
  /// Field("categoryID").equalAny([Field("featuredCategory"), Field("popularCategory")])
  /// ```
  ///
  /// - Parameter others: An array of at least one `Expression` value to check against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func equalAny(_ others: [Expression]) -> BooleanExpression

  /// Creates an expression that checks if this expression is equal to any of the provided literal
  /// values.
  ///
  /// ```swift
  /// // Check if "category" is "Electronics", "Books", or "Home Goods"
  /// Field("category").equalAny(["Electronics", "Books", "Home Goods"])
  /// ```
  ///
  /// - Parameter others: An array of at least one `Sendable` literal value to check against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func equalAny(_ others: [Sendable]) -> BooleanExpression

  /// Creates an expression that checks if this expression is equal to any of the provided
  /// expression values.
  ///
  /// ```swift
  /// // Check if "categoryID" field is equal to any of "categoryIDs" fields
  /// Field("categoryID").equalAny(Field("categoryIDs"))
  /// ```
  ///
  /// - Parameter arrayExpression: An `Expression` elements evaluated to be array.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func equalAny(_ arrayExpression: Expression) -> BooleanExpression

  /// Creates an expression that checks if this expression is not equal to any of the provided
  /// expression values.
  ///
  /// ```swift
  /// // Check if "statusValue" is not equal to "archivedStatus" or "deletedStatus" fields
  /// Field("statusValue").notEqualAny([Field("archivedStatus"), Field("deletedStatus")])
  /// ```
  ///
  /// - Parameter others: An array of at least one `Expression` value to check against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func notEqualAny(_ others: [Expression]) -> BooleanExpression

  /// Creates an expression that checks if this expression is not equal to any of the provided
  /// literal values.
  ///
  /// ```swift
  /// // Check if "status" is neither "pending" nor "archived"
  /// Field("status").notEqualAny(["pending", "archived"])
  /// ```
  ///
  /// - Parameter others: An array of at least one `Sendable` literal value to check against.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func notEqualAny(_ others: [Sendable]) -> BooleanExpression

  /// Creates an expression that checks if this expression is equal to any of the provided
  /// expression values.
  ///
  /// ```swift
  /// // Check if "categoryID" field is not equal to any of "categoryIDs" fields
  /// Field("categoryID").equalAny(Field("categoryIDs"))
  /// ```
  ///
  /// - Parameter arrayExpression: An `Expression` elements evaluated to be array.
  /// - Returns: A `BooleanExpression` that can be used in a where stage, together with other
  /// boolean expressions.
  func notEqualAny(_ arrayExpression: Expression) -> BooleanExpression

  /// Creates an expression that checks if a field exists in the document.
  ///
  /// ```swift
  /// // Check if the document has a field named "phoneNumber"
  /// Field("phoneNumber").exists()
  /// ```
  ///
  /// - Returns: A new `BooleanExpression` representing the "exists" check.
  func exists() -> BooleanExpression

  /// Creates an expression that checks if this expression produces an error during evaluation.
  ///
  /// ```swift
  /// // Check if accessing a non-existent array index causes an error
  /// Field("myArray").arrayGet(100).isError()
  /// ```
  ///
  /// - Returns: A new `BooleanExpression` representing the "isError" check.
  func isError() -> BooleanExpression

  /// Creates an expression that returns `true` if the result of this expression
  /// is absent (e.g., a field does not exist in a map). Otherwise, returns `false`.
  ///
  /// ```swift
  /// // Check if the field `value` is absent.
  /// Field("value").isAbsent()
  /// ```
  ///
  /// - Returns: A new `BooleanExpression` representing the "isAbsent" check.
  func isAbsent() -> BooleanExpression

  // MARK: String Operations

  /// Creates an expression that joins the elements of an array of strings with a given separator.
  ///
  /// Assumes `self` evaluates to an array of strings.
  ///
  /// ```swift
  /// // Join the "tags" array with a ", " separator.
  /// Field("tags").join(separator: ", ")
  /// ```
  ///
  /// - Parameter delimiter: The string to use as a delimiter.
  /// - Returns: A new `FunctionExpression` representing the joined string.
  func join(delimiter: String) -> FunctionExpression

  /// Creates an expression that splits a string into an array of substrings based on a delimiter.
  ///
  /// - Parameter delimiter: The string to split on.
  /// - Returns: A new `FunctionExpression` representing the array of substrings.
  func split(delimiter: String) -> FunctionExpression

  /// Creates an expression that splits a string into an array of substrings based on a delimiter.
  ///
  /// - Parameter delimiter: An expression that evaluates to a string or bytes to split on.
  /// - Returns: A new `FunctionExpression` representing the array of substrings.
  func split(delimiter: Expression) -> FunctionExpression

  /// Creates an expression that returns the length of a string.
  ///
  /// ```swift
  /// // Get the length of the "name" field.
  /// Field("name").length()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the length of the string.
  func length() -> FunctionExpression

  /// Creates an expression that calculates the character length of a string in UTF-8.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Get the character length of the "name" field in its UTF-8 form.
  /// Field("name").charLength()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the length of the string.
  func charLength() -> FunctionExpression

  /// Creates an expression that performs a case-sensitive string comparison using wildcards against
  /// a literal pattern.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Check if the "title" field contains the word "guide" (case-sensitive)
  /// Field("title").like("%guide%")
  /// ```
  ///
  /// - Parameter pattern: The literal string pattern to search for. Use "%" as a wildcard.
  /// - Returns: A new `BooleanExpression` representing the "like" comparison.
  func like(_ pattern: String) -> BooleanExpression

  /// Creates an expression that performs a case-sensitive string comparison using wildcards against
  /// an expression pattern.
  /// Assumes `self` evaluates to a string, and `pattern` evaluates to a string.
  ///
  /// ```swift
  /// // Check if "filename" matches a pattern stored in "patternField"
  /// Field("filename").like(Field("patternField"))
  /// ```
  ///
  /// - Parameter pattern: An `Expression` (evaluating to a string) representing the pattern to
  /// search for.
  /// - Returns: A new `BooleanExpression` representing the "like" comparison.
  func like(_ pattern: Expression) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) contains a specified regular
  /// expression literal as a substring.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Check if "description" contains "example" (case-insensitive)
  /// Field("description").regexContains("(?i)example")
  /// ```
  ///
  /// - Parameter pattern: The literal string regular expression to use for the search.
  /// - Returns: A new `BooleanExpression` representing the "regex_contains" comparison.
  func regexContains(_ pattern: String) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) contains a specified regular
  /// expression (from an expression) as a substring.
  /// Assumes `self` evaluates to a string, and `pattern` evaluates to a string.
  ///
  /// ```swift
  /// // Check if "logEntry" contains a pattern from "errorPattern" field
  /// Field("logEntry").regexContains(Field("errorPattern"))
  /// ```
  ///
  /// - Parameter pattern: An `Expression` (evaluating to a string) representing the regular
  /// expression to use for the search.
  /// - Returns: A new `BooleanExpression` representing the "regex_contains" comparison.
  func regexContains(_ pattern: Expression) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) matches a specified regular
  /// expression literal entirely.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Check if the "email" field matches a valid email pattern
  /// Field("email").regexMatch("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
  /// ```
  ///
  /// - Parameter pattern: The literal string regular expression to use for the match.
  /// - Returns: A new `BooleanExpression` representing the regular expression match.
  func regexMatch(_ pattern: String) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) matches a specified regular
  /// expression (from an expression) entirely.
  /// Assumes `self` evaluates to a string, and `pattern` evaluates to a string.
  ///
  /// ```swift
  /// // Check if "input" matches the regex stored in "validationRegex"
  /// Field("input").regexMatch(Field("validationRegex"))
  /// ```
  ///
  /// - Parameter pattern: An `Expression` (evaluating to a string) representing the regular
  /// expression to use for the match.
  /// - Returns: A new `BooleanExpression` representing the regular expression match.
  func regexMatch(_ pattern: Expression) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) contains a specified literal
  /// substring (case-sensitive).
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Check if the "description" field contains "example".
  /// Field("description").stringContains("example")
  /// ```
  ///
  /// - Parameter substring: The literal string substring to search for.
  /// - Returns: A new `BooleanExpression` representing the "stringContains" comparison.
  func stringContains(_ substring: String) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) contains a specified substring
  /// from an expression (case-sensitive).
  /// Assumes `self` evaluates to a string, and `expression` evaluates to a string.
  ///
  /// ```swift
  /// // Check if the "message" field contains the value of the "keyword" field.
  /// Field("message").stringContains(Field("keyword"))
  /// ```
  ///
  /// - Parameter expression: An `Expression` (evaluating to a string) representing the substring to
  /// search for.
  /// - Returns: A new `BooleanExpression` representing the "str_contains" comparison.
  func stringContains(_ expression: Expression) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) starts with a given literal prefix
  /// (case-sensitive).
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Check if the "name" field starts with "Mr."
  /// Field("name").startsWith("Mr.")
  /// ```
  ///
  /// - Parameter prefix: The literal string prefix to check for.
  /// - Returns: A new `BooleanExpr` representing the "starts_with" comparison.
  func startsWith(_ prefix: String) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) starts with a given prefix from an
  /// expression (case-sensitive).
  /// Assumes `self` evaluates to a string, and `prefix` evaluates to a string.
  ///
  /// ```swift
  /// // Check if "fullName" starts with the value of "firstName"
  /// Field("fullName").startsWith(Field("firstName"))
  /// ```
  ///
  /// - Parameter prefix: An `Expression` (evaluating to a string) representing the prefix to check
  /// for.
  /// - Returns: A new `BooleanExpr` representing the "starts_with" comparison.
  func startsWith(_ prefix: Expression) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) ends with a given literal suffix
  /// (case-sensitive).
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Check if the "filename" field ends with ".txt"
  /// Field("filename").endsWith(".txt")
  /// ```
  ///
  /// - Parameter suffix: The literal string suffix to check for.
  /// - Returns: A new `BooleanExpr` representing the "ends_with" comparison.
  func endsWith(_ suffix: String) -> BooleanExpression

  /// Creates an expression that checks if a string (from `self`) ends with a given suffix from an
  /// expression (case-sensitive).
  /// Assumes `self` evaluates to a string, and `suffix` evaluates to a string.
  ///
  /// ```swift
  /// // Check if "url" ends with the value of "extension" field
  /// Field("url").endsWith(Field("extension"))
  /// ```
  ///
  /// - Parameter suffix: An `Expression` (evaluating to a string) representing the suffix to check
  /// for.
  /// - Returns: A new `BooleanExpression` representing the "ends_with" comparison.
  func endsWith(_ suffix: Expression) -> BooleanExpression

  /// Creates an expression that converts a string (from `self`) to lowercase.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Convert the "name" field to lowercase
  /// Field("name").toLower()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the lowercase string.
  func toLower() -> FunctionExpression

  /// Creates an expression that converts a string (from `self`) to uppercase.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Convert the "title" field to uppercase
  /// Field("title").toUpper()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the uppercase string.
  func toUpper() -> FunctionExpression

  /// Creates an expression that removes leading and trailing whitespace from a string.
  ///
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Trim leading/trailing whitespace from the "comment" field.
  /// Field("comment").trim()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the trimmed string.
  func trim() -> FunctionExpression

  /// Creates an expression that removes leading and trailing occurrences of specified characters
  /// from a string (from `self`).
  /// Assumes `self` evaluates to a string, and `value` evaluates to a string.
  ///
  /// ```swift
  /// // Trim leading/trailing "xy" from field
  /// Field("code").trim(characters: "xy")
  /// ```
  ///
  /// - Parameter value: A `String` containing the characters to trim.
  /// - Returns: A new `FunctionExpression` representing the trimmed string.
  func trim(_ value: String) -> FunctionExpression

  /// Creates an expression that removes leading and trailing occurrences of specified string
  /// (from an expression) from a string (from `self`).
  /// Assumes `self` evaluates to a string, and `value` evaluates to a string.
  ///
  /// ```swift
  /// // Trim characters specified by the "trimChars" field from "data"
  /// Field("data").trim(characters: Field("trimChars"))
  /// ```
  ///
  /// - Parameter value: An `Expression` (evaluating to a string) containing the characters to
  /// trim.
  /// - Returns: A new `FunctionExpression` representing the trimmed string.
  func trim(_ value: Expression) -> FunctionExpression

  /// Creates an expression that concatenates this string expression with other string expressions.
  /// Assumes `self` and all parameters evaluate to strings.
  ///
  /// ```swift
  /// // Combine "firstName", " ", and "lastName"
  /// Field("firstName").stringConcat([" ", Field("lastName")])
  /// ```
  ///
  /// - Parameter strings: An array of `Expression` or `String` to concatenate.
  /// - Returns: A new `FunctionExpression` representing the concatenated string.
  func stringConcat(_ strings: [Sendable]) -> FunctionExpression

  /// Creates an expression that concatenates this string expression with other string expressions.
  /// Assumes `self` and all parameters evaluate to strings.
  ///
  /// ```swift
  /// // Combine "firstName", "middleName", and "lastName" fields
  /// Field("firstName").stringConcat(Field("middleName"), Field("lastName"))
  /// ```
  ///
  /// - Parameter secondString: An `Expression` (evaluating to a string) to concatenate.
  /// - Parameter otherStrings: Optional additional `Expression` (evaluating to strings) to
  /// concatenate.
  /// - Returns: A new `FunctionExpression` representing the concatenated string.
  func stringConcat(_ strings: [Expression]) -> FunctionExpression

  /// Creates an expression that reverses this expression.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Reverse the value of the "myString" field.
  /// Field("myString").reverse()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the reversed string.
  func reverse() -> FunctionExpression

  /// Creates an expression that reverses this string expression.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Reverse the value of the "myString" field.
  /// Field("myString").stringReverse()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the reversed string.
  func stringReverse() -> FunctionExpression

  /// Creates an expression that calculates the length of this string or bytes expression in bytes.
  /// Assumes `self` evaluates to a string or bytes.
  ///
  /// ```swift
  /// // Calculate the length of the "myString" field in bytes.
  /// Field("myString").byteLength()
  ///
  /// // Calculate the size of the "avatar" (Data/Bytes) field.
  /// Field("avatar").byteLength()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the length in bytes.
  func byteLength() -> FunctionExpression

  /// Creates an expression that returns a substring of this expression (String or Bytes) using
  /// literal integers for position and optional length.
  /// Indexing is 0-based. Assumes `self` evaluates to a string or bytes.
  ///
  /// ```swift
  /// // Get substring from index 5 with length 10
  /// Field("myString").substring(5, 10)
  ///
  /// // Get substring from "myString" starting at index 3 to the end
  /// Field("myString").substring(3) // Default nil
  /// ```
  ///
  /// - Parameter position: Literal `Int` index of the first character/byte.
  /// - Parameter length: Optional literal `Int` length of the substring. If `nil`, goes to the end.
  /// - Returns: A new `FunctionExpression` representing the substring.
  func substring(position: Int, length: Int?) -> FunctionExpression

  /// Creates an expression that returns a substring of this expression (String or Bytes) using
  /// expressions for position and optional length.
  /// Indexing is 0-based. Assumes `self` evaluates to a string or bytes, and parameters evaluate to
  /// integers.
  ///
  /// ```swift
  /// // Get substring from index calculated by Field("start") with length from Field("len")
  /// Field("myString").substring(Field("start"), Field("len"))
  ///
  /// // Get substring from index calculated by Field("start") to the end
  /// Field("myString").substring(Field("start")) // Default nil for optional Expression length
  /// ```
  ///
  /// - Parameter position: An `Expression` (evaluating to an Int) for the index of the first
  /// character.
  /// - Parameter length: Optional `Expression` (evaluating to an Int) for the length of the
  /// substring. If `nil`, goes to the end.
  /// - Returns: A new `FunctionExpression` representing the substring.
  func substring(position: Expression, length: Expression?) -> FunctionExpression

  // MARK: Map Operations

  /// Accesses a value from a map (object) field using the provided literal string key.
  /// Assumes `self` evaluates to a Map.
  ///
  /// ```swift
  /// // Get the "city" value from the "address" map field
  /// Field("address").mapGet("city")
  /// ```
  ///
  /// - Parameter subfield: The literal string key to access in the map.
  /// - Returns: A new `FunctionExpression` representing the value associated with the given key.
  func mapGet(_ subfield: String) -> FunctionExpression

  /// Creates an expression that removes a key (specified by a literal string) from the map produced
  /// by evaluating this expression.
  /// Assumes `self` evaluates to a Map.
  ///
  /// ```swift
  /// // Removes the key "baz" from the map held in field "myMap"
  /// Field("myMap").mapRemove("baz")
  /// ```
  ///
  /// - Parameter key: The literal string key to remove from the map.
  /// - Returns: A new `FunctionExpression` representing the "map_remove" operation.
  func mapRemove(_ key: String) -> FunctionExpression

  /// Creates an expression that removes a key (specified by an expression) from the map produced by
  /// evaluating this expression.
  /// Assumes `self` evaluates to a Map, and `keyExpression` evaluates to a string.
  ///
  /// ```swift
  /// // Removes the key specified by field "keyToRemove" from the map in "settings"
  /// Field("settings").mapRemove(Field("keyToRemove"))
  /// ```
  ///
  /// - Parameter keyExpression: An `Expression` (evaluating to a string) representing the key to
  /// remove from the map.
  /// - Returns: A new `FunctionExpression` representing the "map_remove" operation.
  func mapRemove(_ keyExpression: Expression) -> FunctionExpression

  /// Creates an expression that merges this map with multiple other map literals.
  /// Assumes `self` evaluates to a Map. Later maps overwrite keys from earlier maps.
  ///
  /// ```swift
  /// // Merge "settings" field with { "enabled": true } and another map literal { "priority": 1 }
  /// Field("settings").mapMerge(["enabled": true], ["priority": 1])
  /// ```
  ///
  /// - Parameter maps: Maps (dictionary literals with `Sendable` values)
  /// to merge.
  /// - Returns: A new `FunctionExpression` representing the "map_merge" operation.
  func mapMerge(_ maps: [[String: Sendable]])
    -> FunctionExpression

  /// Creates an expression that merges this map with multiple other map expressions.
  /// Assumes `self` and other arguments evaluate to Maps. Later maps overwrite keys from earlier
  /// maps.
  ///
  /// ```swift
  /// // Merge "baseSettings" field with "userOverrides" field and "adminConfig" field
  /// Field("baseSettings").mapMerge(Field("userOverrides"), Field("adminConfig"))
  /// ```
  ///
  /// - Parameter maps: Additional `Expression` (evaluating to Maps) to merge.
  /// - Returns: A new `FunctionExpression` representing the "map_merge" operation.
  func mapMerge(_ maps: [Expression]) -> FunctionExpression

  // MARK: Aggregations

  /// Creates an aggregation that counts the number of distinct values of this expression.
  ///
  /// ```swift
  /// // Count the number of distinct categories.
  /// Field("category").countDistinct().as("distinctCategories")
  /// ```
  ///
  /// - Returns: A new `AggregateFunction` representing the "count_distinct" aggregation.
  func countDistinct() -> AggregateFunction

  /// Creates an aggregation that counts the number of stage inputs where this expression evaluates
  /// to a valid, non-null value.
  ///
  /// ```swift
  /// // Count the total number of products with a "productId"
  /// Field("productId").count().alias("totalProducts")
  /// ```
  ///
  /// - Returns: A new `AggregateFunction` representing the "count" aggregation on this expression.
  func count() -> AggregateFunction

  /// Creates an aggregation that calculates the sum of this numeric expression across multiple
  /// stage inputs.
  /// Assumes `self` evaluates to a numeric type.
  ///
  /// ```swift
  /// // Calculate the total revenue from a set of orders
  /// Field("orderAmount").sum().alias("totalRevenue")
  /// ```
  ///
  /// - Returns: A new `AggregateFunction` representing the "sum" aggregation.
  func sum() -> AggregateFunction

  /// Creates an aggregation that calculates the average (mean) of this numeric expression across
  /// multiple stage inputs.
  /// Assumes `self` evaluates to a numeric type.
  ///
  /// ```swift
  /// // Calculate the average age of users
  /// Field("age").average().as("averageAge")
  /// ```
  ///
  /// - Returns: A new `AggregateFunction` representing the "average" aggregation.
  func average() -> AggregateFunction

  /// Creates an aggregation that finds the minimum value of this expression across multiple stage
  /// inputs.
  ///
  /// ```swift
  /// // Find the lowest price of all products
  /// Field("price").minimum().alias("lowestPrice")
  /// ```
  ///
  /// - Returns: A new `AggregateFunction` representing the "min" aggregation.
  func minimum() -> AggregateFunction

  /// Creates an aggregation that finds the maximum value of this expression across multiple stage
  /// inputs.
  ///
  /// ```swift
  /// // Find the highest score in a leaderboard
  /// Field("score").maximum().alias("highestScore")
  /// ```
  ///
  /// - Returns: A new `AggregateFunction` representing the "max" aggregation.
  func maximum() -> AggregateFunction

  /// Creates an expression that returns the larger value between this expression and other
  /// expressions, based on Firestore"s value type ordering.
  ///
  /// ```swift
  /// // Returns the largest of "val1", "val2", and "val3" fields
  /// Field("val1").logicalMaximum(Field("val2"), Field("val3"))
  /// ```
  ///
  /// - Parameter expressions: An array of at least one `Expression` to compare with.
  /// - Returns: A new `FunctionExpression` representing the logical max operation.
  func logicalMaximum(_ expressions: [Expression]) -> FunctionExpression

  /// Creates an expression that returns the larger value between this expression and other literal
  /// values, based on Firestore"s value type ordering.
  ///
  /// ```swift
  /// // Returns the largest of "val1" (a field), 100, and 200.0
  /// Field("val1").logicalMaximum(100, 200.0)
  /// ```
  ///
  /// - Parameter values: An array of at least one `Sendable` value to compare with.
  /// - Returns: A new `FunctionExpression` representing the logical max operation.
  func logicalMaximum(_ values: [Sendable]) -> FunctionExpression

  /// Creates an expression that returns the smaller value between this expression and other
  /// expressions, based on Firestore"s value type ordering.
  ///
  /// ```swift
  /// // Returns the smallest of "val1", "val2", and "val3" fields
  /// Field("val1").logicalMinimum(Field("val2"), Field("val3"))
  /// ```
  ///
  /// - Parameter expressions: An array of at least one `Expression` to compare with.
  /// - Returns: A new `FunctionExpression` representing the logical min operation.
  func logicalMinimum(_ expressions: [Expression]) -> FunctionExpression

  /// Creates an expression that returns the smaller value between this expression and other literal
  /// values, based on Firestore"s value type ordering.
  ///
  /// ```swift
  /// // Returns the smallest of "val1" (a field), 0, and -5.5
  /// Field("val1").logicalMinimum(0, -5.5)
  /// ```
  ///
  /// - Parameter values: An array of at least one `Sendable` value to compare with.
  /// - Returns: A new `FunctionExpression` representing the logical min operation.
  func logicalMinimum(_ values: [Sendable]) -> FunctionExpression

  // MARK: Vector Operations

  /// Creates an expression that calculates the length (number of dimensions) of this Firestore
  /// Vector expression.
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Get the vector length (dimension) of the field "embedding".
  /// Field("embedding").vectorLength()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the length of the vector.
  func vectorLength() -> FunctionExpression

  /// Calculates the cosine distance between this vector expression and another vector expression.
  /// Assumes both `self` and `other` evaluate to Vectors.
  ///
  /// ```swift
  /// // Cosine distance between "userVector" field and "itemVector" field
  /// Field("userVector").cosineDistance(Field("itemVector"))
  /// ```
  ///
  /// - Parameter expression: The other vector as an `Expr` to compare against.
  /// - Returns: A new `FunctionExpression` representing the cosine distance.
  func cosineDistance(_ expression: Expression) -> FunctionExpression

  /// Calculates the cosine distance between this vector expression and another vector literal
  /// (`VectorValue`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Cosine distance with a VectorValue
  /// let targetVector = VectorValue(vector: [0.1, 0.2, 0.3])
  /// Field("docVector").cosineDistance(targetVector)
  /// ```
  /// - Parameter vector: The other vector as a `VectorValue` to compare against.
  /// - Returns: A new `FunctionExpression` representing the cosine distance.
  func cosineDistance(_ vector: VectorValue) -> FunctionExpression

  /// Calculates the cosine distance between this vector expression and another vector literal
  /// (`[Double]`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Cosine distance between "location" field and a target location
  /// Field("location").cosineDistance([37.7749, -122.4194])
  /// ```
  /// - Parameter vector: The other vector as `[Double]` to compare against.
  /// - Returns: A new `FunctionExpression` representing the cosine distance.
  func cosineDistance(_ vector: [Double]) -> FunctionExpression

  /// Calculates the dot product between this vector expression and another vector expression.
  /// Assumes both `self` and `other` evaluate to Vectors.
  ///
  /// ```swift
  /// // Dot product between "vectorA" and "vectorB" fields
  /// Field("vectorA").dotProduct(Field("vectorB"))
  /// ```
  ///
  /// - Parameter expression: The other vector as an `Expr` to calculate with.
  /// - Returns: A new `FunctionExpression` representing the dot product.
  func dotProduct(_ expression: Expression) -> FunctionExpression

  /// Calculates the dot product between this vector expression and another vector literal
  /// (`VectorValue`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Dot product with a VectorValue
  /// let weightVector = VectorValue(vector: [0.5, -0.5])
  /// Field("features").dotProduct(weightVector)
  /// ```
  /// - Parameter vector: The other vector as a `VectorValue` to calculate with.
  /// - Returns: A new `FunctionExpression` representing the dot product.
  func dotProduct(_ vector: VectorValue) -> FunctionExpression

  /// Calculates the dot product between this vector expression and another vector literal
  /// (`[Double]`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Dot product between a feature vector and a target vector literal
  /// Field("features").dotProduct([0.5, 0.8, 0.2])
  /// ```
  /// - Parameter vector: The other vector as `[Double]` to calculate with.
  /// - Returns: A new `FunctionExpression` representing the dot product.
  func dotProduct(_ vector: [Double]) -> FunctionExpression

  /// Calculates the Euclidean distance between this vector expression and another vector
  /// expression.
  /// Assumes both `self` and `other` evaluate to Vectors.
  ///
  /// ```swift
  /// // Euclidean distance between "pointA" and "pointB" fields
  /// Field("pointA").euclideanDistance(Field("pointB"))
  /// ```
  ///
  /// - Parameter expression: The other vector as an `Expr` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Euclidean distance.
  func euclideanDistance(_ expression: Expression) -> FunctionExpression

  /// Calculates the Euclidean distance between this vector expression and another vector literal
  /// (`VectorValue`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// let targetPoint = VectorValue(vector: [1.0, 2.0])
  /// Field("currentLocation").euclideanDistance(targetPoint)
  /// ```
  /// - Parameter vector: The other vector as a `VectorValue` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Euclidean distance.
  func euclideanDistance(_ vector: VectorValue) -> FunctionExpression

  /// Calculates the Euclidean distance between this vector expression and another vector literal
  /// (`[Double]`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Euclidean distance between "location" field and a target location literal
  /// Field("location").euclideanDistance([37.7749, -122.4194])
  /// ```
  /// - Parameter vector: The other vector as `[Double]` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Euclidean distance.
  func euclideanDistance(_ vector: [Double]) -> FunctionExpression

  // MARK: Timestamp operations

  /// Creates an expression that interprets this expression (evaluating to a number) as microseconds
  /// since the Unix epoch and returns a timestamp.
  /// Assumes `self` evaluates to a number.
  ///
  /// ```swift
  /// // Interpret "microseconds" field as microseconds since epoch.
  /// Field("microseconds").unixMicrosToTimestamp()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the timestamp.
  func unixMicrosToTimestamp() -> FunctionExpression

  /// Creates an expression that converts this timestamp expression to the number of microseconds
  /// since the Unix epoch. Assumes `self` evaluates to a Timestamp.
  ///
  /// ```swift
  /// // Convert "timestamp" field to microseconds since epoch.
  /// Field("timestamp").timestampToUnixMicros()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the number of microseconds.
  func timestampToUnixMicros() -> FunctionExpression

  /// Creates an expression that interprets this expression (evaluating to a number) as milliseconds
  /// since the Unix epoch and returns a timestamp.
  /// Assumes `self` evaluates to a number.
  ///
  /// ```swift
  /// // Interpret "milliseconds" field as milliseconds since epoch.
  /// Field("milliseconds").unixMillisToTimestamp()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the timestamp.
  func unixMillisToTimestamp() -> FunctionExpression

  /// Creates an expression that converts this timestamp expression to the number of milliseconds
  /// since the Unix epoch. Assumes `self` evaluates to a Timestamp.
  ///
  /// ```swift
  /// // Convert "timestamp" field to milliseconds since epoch.
  /// Field("timestamp").timestampToUnixMillis()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the number of milliseconds.
  func timestampToUnixMillis() -> FunctionExpression

  /// Creates an expression that interprets this expression (evaluating to a number) as seconds
  /// since the Unix epoch and returns a timestamp.
  /// Assumes `self` evaluates to a number.
  ///
  /// ```swift
  /// // Interpret "seconds" field as seconds since epoch.
  /// Field("seconds").unixSecondsToTimestamp()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the timestamp.
  func unixSecondsToTimestamp() -> FunctionExpression

  /// Creates an expression that converts this timestamp expression to the number of seconds
  /// since the Unix epoch. Assumes `self` evaluates to a Timestamp.
  ///
  /// ```swift
  /// // Convert "timestamp" field to seconds since epoch.
  /// Field("timestamp").timestampToUnixSeconds()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the number of seconds.
  func timestampToUnixSeconds() -> FunctionExpression

  /// Creates an expression that truncates a timestamp to a specified granularity.
  /// Assumes `self` evaluates to a Timestamp.
  ///
  /// ```swift
  /// // Truncate "timestamp" field to the nearest day.
  /// Field("timestamp").timestampTruncate(granularity: .day)
  /// ```
  ///
  /// - Parameter granularity: A `TimeGranularity` representing the truncation unit.
  /// - Returns: A new `FunctionExpression` representing the truncated timestamp.
  func timestampTruncate(granularity: TimeGranularity) -> FunctionExpression

  /// Creates an expression that truncates a timestamp to a specified granularity.
  /// Assumes `self` evaluates to a Timestamp.
  ///
  /// ```swift
  /// // Truncate "timestamp" field to the nearest day using a literal string.
  /// Field("timestamp").timestampTruncate(granularity: "day")
  ///
  /// // Truncate "timestamp" field to the nearest day using an expression.
  /// Field("timestamp").timestampTruncate(granularity: Field("granularity_field"))
  /// ```
  ///
  /// - Parameter granularity: A `Sendable` literal string or an `Expression` that evaluates to a
  /// string, specifying the truncation unit.
  /// - Returns: A new `FunctionExpression` representing the truncated timestamp.
  func timestampTruncate(granularity: Sendable) -> FunctionExpression

  /// Creates an expression that adds a specified amount of time to this timestamp expression,
  /// where unit and amount are provided as literals.
  /// Assumes `self` evaluates to a Timestamp.
  ///
  /// ```swift
  /// // Add 1 day to the "timestamp" field.
  /// Field("timestamp").timestampAdd(1, .day)
  /// ```
  ///
  /// - Parameter unit: The `TimeUnit` enum representing the unit of time.
  /// - Parameter amount: The literal `Int` amount of the unit to add.
  /// - Returns: A new "FunctionExpression" representing the resulting timestamp.
  func timestampAdd(_ amount: Int, _ unit: TimeUnit) -> FunctionExpression

  /// Creates an expression that adds a specified amount of time to this timestamp expression,
  /// where unit and amount are provided as an expression for amount and a literal for unit.
  /// Assumes `self` evaluates to a Timestamp, `amount` evaluates to an integer, and `unit`
  /// evaluates to a string.
  ///
  /// ```swift
  /// // Add duration from "amountField" to "timestamp" with a literal unit "day".
  /// Field("timestamp").timestampAdd(amount: Field("amountField"), unit: "day")
  /// ```
  ///
  /// - Parameter unit: A `Sendable` literal string specifying the unit of time.
  ///                 Valid units are "microsecond", "millisecond", "second", "minute", "hour",
  /// "day".
  /// - Parameter amount: An `Expression` evaluating to the amount (Int) of the unit to add.
  /// - Returns: A new "FunctionExpression" representing the resulting timestamp.
  func timestampAdd(amount: Expression, unit: Sendable) -> FunctionExpression

  /// Creates an expression that subtracts a specified amount of time from this timestamp
  /// expression, where unit and amount are provided as literals.
  /// Assumes `self` evaluates to a Timestamp.
  ///
  /// ```swift
  /// // Subtract 1 day from the "timestamp" field.
  /// Field("timestamp").timestampSubtract(1, .day)
  /// ```
  ///
  /// - Parameter unit: The `TimeUnit` enum representing the unit of time.
  /// - Parameter amount: The literal `Int` amount of the unit to subtract.
  /// - Returns: A new "FunctionExpression" representing the resulting timestamp.
  func timestampSubtract(_ amount: Int, _ unit: TimeUnit) -> FunctionExpression

  /// Creates an expression that subtracts a specified amount of time from this timestamp
  /// expression, where unit and amount are provided as an expression for amount and a literal for
  /// unit.
  /// Assumes `self` evaluates to a Timestamp, `amount` evaluates to an integer, and `unit`
  /// evaluates to a string.
  ///
  /// ```swift
  /// // Subtract duration from "amountField" from "timestamp" with a literal unit "day".
  /// Field("timestamp").timestampSubtract(amount: Field("amountField"), unit: "day")
  /// ```
  ///
  /// - Parameter unit: A `Sendable` literal string specifying the unit of time.
  ///                 Valid units are "microsecond", "millisecond", "second", "minute", "hour",
  /// "day".
  /// - Parameter amount: An `Expression` evaluating to the amount (Int) of the unit to subtract.
  /// - Returns: A new "FunctionExpression" representing the resulting timestamp.
  func timestampSubtract(amount: Expression, unit: Sendable) -> FunctionExpression

  /// Creates an expression that returns the document ID from a path.
  ///
  /// ```swift
  /// // Get the document ID from a path.
  /// Field(FieldPath.documentID()).documentId()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the documentId operation.
  func documentId() -> FunctionExpression

  /// Gets the collection id (kind) of a given document (either an absolute or
  /// namespace relative reference).  Throw error if the input is the
  /// root itself.
  func collectionId() -> FunctionExpression

  /// Creates an expression that returns the result of `catchExpression` if this expression produces
  /// an error during evaluation, otherwise returns the result of this expression.
  ///
  /// ```swift
  /// // Try dividing "a" by "b", return field "fallbackValue" on error (e.g., division by zero)
  /// Field("a").divide(Field("b")).ifError(Field("fallbackValue"))
  /// ```
  ///
  /// - Parameter catchExpression: The `Expression` to evaluate and return if this expression
  /// errors.
  /// - Returns: A new "FunctionExpression" representing the "ifError" operation.
  func ifError(_ catchExpression: Expression) -> FunctionExpression

  /// Creates an expression that returns the literal `catchValue` if this expression produces an
  /// error during evaluation, otherwise returns the result of this expression.
  ///
  /// ```swift
  /// // Get first item in "title" array, or return "Default Title" if error (e.g., empty array)
  /// Field("title").arrayGet(0).ifError("Default Title")
  /// ```
  ///
  /// - Parameter catchValue: The literal `Sendable` value to return if this expression errors.
  /// - Returns: A new "FunctionExpression" representing the "ifError" operation.
  func ifError(_ catchValue: Sendable) -> FunctionExpression

  /// Creates an expression that returns the literal `defaultValue` if this expression is
  /// absent (e.g., a field does not exist in a map).
  /// Otherwise, returns the result of this expression.
  ///
  /// ```swift
  /// // If the "optionalField" is absent, return "default value".
  /// Field("optionalField").ifAbsent("default value")
  /// ```
  ///
  /// - Parameter defaultValue: The literal `Sendable` value to return if this expression is absent.
  /// - Returns: A new "FunctionExpression" representing the "ifAbsent" operation.
  func ifAbsent(_ defaultValue: Sendable) -> FunctionExpression

  // MARK: Sorting

  /// Creates an `Ordering` object that sorts documents in ascending order based on this expression.
  ///
  /// ```swift
  /// // Sort documents by the "name" field in ascending order
  /// firestore.pipeline().collection("users")
  ///   .sort(Field("name").ascending())
  /// ```
  ///
  /// - Returns: A new `Ordering` instance for ascending sorting.
  func ascending() -> Ordering

  /// Creates an `Ordering` object that sorts documents in descending order based on this
  /// expression.
  ///
  /// ```swift
  /// // Sort documents by the "createdAt" field in descending order
  /// firestore.pipeline().collection("users")
  ///   .sort(Field("createdAt").descending())
  /// ```
  ///
  /// - Returns: A new `Ordering` instance for descending sorting.
  func descending() -> Ordering

  /// Creates an expression that concatenates multiple sequenceable types together.
  ///
  /// ```swift
  /// // Concatenate the firstName and lastName with a space in between.
  /// Field("firstName").concat([" ", Field("lastName")])
  /// ```
  ///
  /// - Parameter values: The values to concatenate.
  /// - Returns: A new `FunctionExpression` representing the concatenated result.
  func concat(_ values: [Sendable]) -> FunctionExpression

  /// Creates an expression that returns the type of the expression.
  ///
  /// ```swift
  /// // Get the type of the "rating" field.
  /// Field("rating").type()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the type of the expression as a string.
  func type() -> FunctionExpression
}
