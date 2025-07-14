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
  /// Assigns an alias to this expression.
  ///
  /// Aliases are useful for renaming fields in the output of a stage or for giving meaningful
  /// names to calculated values.
  ///
  /// ```swift
  /// // Calculate total price and alias it "totalPrice"
  /// Field("price").multiply(Field("quantity")).`as`("totalPrice")
  /// ```
  ///
  /// - Parameter name: The alias to assign to this expression.
  /// - Returns: A new `AliasedExpression` wrapping this expression with the alias.
  func `as`(_ name: String) -> AliasedExpression

  // --- Added Mathematical Operations ---

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

  /// Creates an expression that concatenates an array expression (from `self`) with one or more
  /// other array expressions.
  /// Assumes `self` and all parameters evaluate to arrays.
  ///
  /// ```swift
  /// // Combine the "items" array with "otherItems" and "archiveItems" array fields.
  /// Field("items").arrayConcat(Field("otherItems"), Field("archiveItems"))
  /// ```
  /// - Parameter secondArray: An `Expression` (evaluating to an array) to concatenate.
  /// - Parameter otherArrays: Optional additional `Expression` values (evaluating to arrays) to
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
  /// - Parameter secondArray: An array literal of `Sendable` values to concatenate.
  /// - Parameter otherArrays: Optional additional array literals of `Sendable` values to
  /// concatenate.
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
  func arrayContains(_ element: Expression) -> BooleanExpr

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
  func arrayContains(_ element: Sendable) -> BooleanExpr

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
  func arrayContainsAll(_ values: [Expression]) -> BooleanExpr

  /// Creates an expression that checks if an array (from `self`) contains all the specified literal
  /// elements.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "tags" contains both "urgent" and "review"
  /// Field("tags").arrayContainsAll(["urgent", "review"])
  /// ```
  ///
  /// - Parameter values: A list of `Sendable` literal elements to check for in the array
  /// represented by `self`.
  /// - Returns: A new `BooleanExpr` representing the "array_contains_all" comparison.
  func arrayContainsAll(_ values: [Sendable]) -> BooleanExpr

  /// Creates an expression that checks if an array (from `self`) contains any of the specified
  /// element expressions.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "userGroups" contains any group from "allowedGroup1" or "allowedGroup2" fields
  /// Field("userGroups").arrayContainsAny([Field("allowedGroup1"), Field("allowedGroup2")])
  /// ```
  ///
  /// - Parameter values: A list of `Expression` elements to check for in the array represented
  /// by `self`.
  /// - Returns: A new `BooleanExpr` representing the "array_contains_any" comparison.
  func arrayContainsAny(_ values: [Expression]) -> BooleanExpr

  /// Creates an expression that checks if an array (from `self`) contains any of the specified
  /// literal elements.
  /// Assumes `self` evaluates to an array.
  ///
  /// ```swift
  /// // Check if "categories" contains either "electronics" or "books"
  /// Field("categories").arrayContainsAny(["electronics", "books"])
  /// ```
  ///
  /// - Parameter values: A list of `Sendable` literal elements to check for in the array
  /// represented by `self`.
  /// - Returns: A new `BooleanExpr` representing the "array_contains_any" comparison.
  func arrayContainsAny(_ values: [Sendable]) -> BooleanExpr

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
  /// - Parameter offsetExpr: An `Expression` (evaluating to an Int) representing the offset of the
  /// element to return.
  /// - Returns: A new `FunctionExpression` representing the "arrayGet" operation.
  func arrayGet(_ offsetExpr: Expression) -> FunctionExpression

  func gt(_ other: Expression) -> BooleanExpr

  func gt(_ other: Sendable) -> BooleanExpr

  // MARK: - Greater Than or Equal (gte)

  func gte(_ other: Expression) -> BooleanExpr

  func gte(_ other: Sendable) -> BooleanExpr

  // MARK: - Less Than (lt)

  func lt(_ other: Expression) -> BooleanExpr

  func lt(_ other: Sendable) -> BooleanExpr

  // MARK: - Less Than or Equal (lte)

  func lte(_ other: Expression) -> BooleanExpr

  func lte(_ other: Sendable) -> BooleanExpr

  // MARK: - Equal (eq)

  func eq(_ other: Expression) -> BooleanExpr

  func eq(_ other: Sendable) -> BooleanExpr

  func neq(_ other: Expression) -> BooleanExpr

  func neq(_ other: Sendable) -> BooleanExpr

  // MARK: Equality with Sendable

  /// Creates an expression that checks if this expression is equal to any of the provided
  /// expression values.
  /// This is similar to an "IN" operator in SQL.
  ///
  /// ```swift
  /// // Check if "categoryID" field is equal to "featuredCategory" or "popularCategory" fields
  /// Field("categoryID").eqAny([Field("featuredCategory"), Field("popularCategory")])
  /// ```
  ///
  /// - Parameter others: A list of `Expression` values to check against.
  /// - Returns: A new `BooleanExpr` representing the "IN" comparison (eq_any).
  func eqAny(_ others: [Expression]) -> BooleanExpr

  /// Creates an expression that checks if this expression is equal to any of the provided literal
  /// values.
  /// This is similar to an "IN" operator in SQL.
  ///
  /// ```swift
  /// // Check if "category" is "Electronics", "Books", or "Home Goods"
  /// Field("category").eqAny(["Electronics", "Books", "Home Goods"])
  /// ```
  ///
  /// - Parameter others: A list of `Sendable` literal values to check against.
  /// - Returns: A new `BooleanExpr` representing the "IN" comparison (eq_any).
  func eqAny(_ others: [Sendable]) -> BooleanExpr

  /// Creates an expression that checks if this expression is not equal to any of the provided
  /// expression values.
  /// This is similar to a "NOT IN" operator in SQL.
  ///
  /// ```swift
  /// // Check if "statusValue" is not equal to "archivedStatus" or "deletedStatus" fields
  /// Field("statusValue").notEqAny([Field("archivedStatus"), Field("deletedStatus")])
  /// ```
  ///
  /// - Parameter others: A list of `Expression` values to check against.
  /// - Returns: A new `BooleanExpr` representing the "NOT IN" comparison (not_eq_any).
  func notEqAny(_ others: [Expression]) -> BooleanExpr

  /// Creates an expression that checks if this expression is not equal to any of the provided
  /// literal values.
  /// This is similar to a "NOT IN" operator in SQL.
  ///
  /// ```swift
  /// // Check if "status" is neither "pending" nor "archived"
  /// Field("status").notEqAny(["pending", "archived"])
  /// ```
  ///
  /// - Parameter others: A list of `Sendable` literal values to check against.
  /// - Returns: A new `BooleanExpr` representing the "NOT IN" comparison (not_eq_any).
  func notEqAny(_ others: [Sendable]) -> BooleanExpr

  // MARK: Checks

  /// Creates an expression that checks if this expression evaluates to "NaN" (Not a Number).
  /// Assumes `self` evaluates to a numeric type.
  ///
  /// ```swift
  /// // Check if the result of a calculation is NaN
  /// Field("value").divide(0).isNan()
  /// ```
  ///
  /// - Returns: A new `BooleanExpr` representing the "isNaN" check.
  func isNan() -> BooleanExpr

  /// Creates an expression that checks if this expression evaluates to "Nil".
  ///
  /// ```swift
  /// // Check if the "optionalField" is null
  /// Field("optionalField").isNil()
  /// ```
  ///
  /// - Returns: A new `BooleanExpr` representing the "isNil" check.
  func isNil() -> BooleanExpr

  /// Creates an expression that checks if a field exists in the document.
  ///
  /// - Note: This typically only makes sense when `self` is a `Field` expression.
  ///
  /// ```swift
  /// // Check if the document has a field named "phoneNumber"
  /// Field("phoneNumber").exists()
  /// ```
  ///
  /// - Returns: A new `BooleanExpr` representing the "exists" check.
  func exists() -> BooleanExpr

  /// Creates an expression that checks if this expression produces an error during evaluation.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Check if accessing a non-existent array index causes an error
  /// Field("myArray").arrayGet(100).isError()
  /// ```
  ///
  /// - Returns: A new `BooleanExpr` representing the "isError" check.
  func isError() -> BooleanExpr

  /// Creates an expression that returns `true` if the result of this expression
  /// is absent (e.g., a field does not exist in a map). Otherwise, returns `false`, even if the
  /// value is `null`.
  ///
  /// - Note: This API is in beta.
  /// - Note: This typically only makes sense when `self` is a `Field` expression.
  ///
  /// ```swift
  /// // Check if the field `value` is absent.
  /// Field("value").isAbsent()
  /// ```
  ///
  /// - Returns: A new `BooleanExpr` representing the "isAbsent" check.
  func isAbsent() -> BooleanExpr

  /// Creates an expression that checks if the result of this expression is not null.
  ///
  /// ```swift
  /// // Check if the value of the "name" field is not null
  /// Field("name").isNotNil()
  /// ```
  ///
  /// - Returns: A new `BooleanExpr` representing the "isNotNil" check.
  func isNotNil() -> BooleanExpr

  /// Creates an expression that checks if the results of this expression is NOT "NaN" (Not a
  /// Number).
  /// Assumes `self` evaluates to a numeric type.
  ///
  /// ```swift
  /// // Check if the result of a calculation is NOT NaN
  /// Field("value").divide(Field("count")).isNotNan() // Assuming count might be 0
  /// ```
  ///
  /// - Returns: A new `BooleanExpr` representing the "isNotNaN" check.
  func isNotNan() -> BooleanExpr

  // MARK: String Operations

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
  /// - Returns: A new `BooleanExpr` representing the "like" comparison.
  func like(_ pattern: String) -> BooleanExpr

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
  /// search
  /// for.
  /// - Returns: A new `BooleanExpr` representing the "like" comparison.
  func like(_ pattern: Expression) -> BooleanExpr

  /// Creates an expression that checks if a string (from `self`) contains a specified regular
  /// expression literal as a substring.
  /// Uses RE2 syntax. Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Check if "description" contains "example" (case-insensitive)
  /// Field("description").regexContains("(?i)example")
  /// ```
  ///
  /// - Parameter pattern: The literal string regular expression to use for the search.
  /// - Returns: A new `BooleanExpr` representing the "regex_contains" comparison.
  func regexContains(_ pattern: String) -> BooleanExpr

  /// Creates an expression that checks if a string (from `self`) contains a specified regular
  /// expression (from an expression) as a substring.
  /// Uses RE2 syntax. Assumes `self` evaluates to a string, and `pattern` evaluates to a string.
  ///
  /// ```swift
  /// // Check if "logEntry" contains a pattern from "errorPattern" field
  /// Field("logEntry").regexContains(Field("errorPattern"))
  /// ```
  ///
  /// - Parameter pattern: An `Expression` (evaluating to a string) representing the regular
  /// expression to
  /// use for the search.
  /// - Returns: A new `BooleanExpr` representing the "regex_contains" comparison.
  func regexContains(_ pattern: Expression) -> BooleanExpr

  /// Creates an expression that checks if a string (from `self`) matches a specified regular
  /// expression literal entirely.
  /// Uses RE2 syntax. Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Check if the "email" field matches a valid email pattern
  /// Field("email").regexMatch("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
  /// ```
  ///
  /// - Parameter pattern: The literal string regular expression to use for the match.
  /// - Returns: A new `BooleanExpr` representing the regular expression match.
  func regexMatch(_ pattern: String) -> BooleanExpr

  /// Creates an expression that checks if a string (from `self`) matches a specified regular
  /// expression (from an expression) entirely.
  /// Uses RE2 syntax. Assumes `self` evaluates to a string, and `pattern` evaluates to a string.
  ///
  /// ```swift
  /// // Check if "input" matches the regex stored in "validationRegex"
  /// Field("input").regexMatch(Field("validationRegex"))
  /// ```
  ///
  /// - Parameter pattern: An `Expression` (evaluating to a string) representing the regular
  /// expression to
  /// use for the match.
  /// - Returns: A new `BooleanExpr` representing the regular expression match.
  func regexMatch(_ pattern: Expression) -> BooleanExpr

  /// Creates an expression that checks if a string (from `self`) contains a specified literal
  /// substring (case-sensitive).
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Check if the "description" field contains "example".
  /// Field("description").strContains("example")
  /// ```
  ///
  /// - Parameter substring: The literal string substring to search for.
  /// - Returns: A new `BooleanExpr` representing the "str_contains" comparison.
  func strContains(_ substring: String) -> BooleanExpr

  /// Creates an expression that checks if a string (from `self`) contains a specified substring
  /// from an expression (case-sensitive).
  /// Assumes `self` evaluates to a string, and `expr` evaluates to a string.
  ///
  /// ```swift
  /// // Check if the "message" field contains the value of the "keyword" field.
  /// Field("message").strContains(Field("keyword"))
  /// ```
  ///
  /// - Parameter expr: An `Expression` (evaluating to a string) representing the substring to
  /// search for.
  /// - Returns: A new `BooleanExpr` representing the "str_contains" comparison.
  func strContains(_ expr: Expression) -> BooleanExpr

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
  func startsWith(_ prefix: String) -> BooleanExpr

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
  func startsWith(_ prefix: Expression) -> BooleanExpr

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
  func endsWith(_ suffix: String) -> BooleanExpr

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
  /// - Returns: A new `BooleanExpr` representing the "ends_with" comparison.
  func endsWith(_ suffix: Expression) -> BooleanExpr

  /// Creates an expression that converts a string (from `self`) to lowercase.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Convert the "name" field to lowercase
  /// Field("name").lowercased()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the lowercase string.
  func lowercased() -> FunctionExpression

  /// Creates an expression that converts a string (from `self`) to uppercase.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Convert the "title" field to uppercase
  /// Field("title").uppercased()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the uppercase string.
  func uppercased() -> FunctionExpression

  /// Creates an expression that removes leading and trailing whitespace from a string (from
  /// `self`).
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Trim whitespace from the "userInput" field
  /// Field("userInput").trim()
  /// ```
  ///
  /// - Returns: A new `FunctionExpression` representing the trimmed string.
  func trim() -> FunctionExpression

  /// Creates an expression that concatenates this string expression with other string expressions.
  /// Assumes `self` and all parameters evaluate to strings.
  ///
  /// ```swift
  /// // Combine "firstName", "middleName", and "lastName" fields
  /// Field("firstName").strConcat(Field("middleName"), Field("lastName"))
  /// ```
  ///
  /// - Parameter secondString: An `Expression` (evaluating to a string) to concatenate.
  /// - Parameter otherStrings: Optional additional `Expression` (evaluating to strings) to
  /// concatenate.
  /// - Returns: A new `FunctionExpression` representing the concatenated string.
  func strConcat(_ strings: [Expression]) -> FunctionExpression

  /// Creates an expression that concatenates this string expression with other string literals.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Combine "firstName" field with " " and "lastName"
  /// Field("firstName").strConcat(" ", "lastName")
  /// ```
  ///
  /// - Parameter secondString: A string literal to concatenate.
  /// - Parameter otherStrings: Optional additional string literals to concatenate.
  /// - Returns: A new `FunctionExpression` representing the concatenated string.
  func strConcat(_ strings: [String]) -> FunctionExpression

  /// Creates an expression that reverses this string expression.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Reverse the value of the "myString" field.
  /// Field("myString").reverse()
  /// ```
  ///
  /// - Returns: A new `FunctionExpr` representing the reversed string.
  func reverse() -> FunctionExpression

  /// Creates an expression that replaces the first occurrence of a literal substring within this
  /// string expression with another literal substring.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Replace the first "hello" with "hi" in the "message" field
  /// Field("message").replaceFirst("hello", "hi")
  /// ```
  ///
  /// - Parameter find: The literal string substring to search for.
  /// - Parameter replace: The literal string substring to replace the first occurrence with.
  /// - Returns: A new `FunctionExpr` representing the string with the first occurrence replaced.
  func replaceFirst(_ find: String, _ replace: String) -> FunctionExpression

  /// Creates an expression that replaces the first occurrence of a substring (from an expression)
  /// within this string expression with another substring (from an expression).
  /// Assumes `self` evaluates to a string, and `find`/`replace` evaluate to strings.
  ///
  /// ```swift
  /// // Replace first occurrence of field "findPattern" with field "replacePattern" in "text"
  /// Field("text").replaceFirst(Field("findPattern"), Field("replacePattern"))
  /// ```
  ///
  /// - Parameter find: An `Expr` (evaluating to a string) for the substring to search for.
  /// - Parameter replace: An `Expr` (evaluating to a string) for the substring to replace the first
  /// occurrence with.
  /// - Returns: A new `FunctionExpr` representing the string with the first occurrence replaced.
  func replaceFirst(_ find: Expression, _ replace: Expression) -> FunctionExpression

  /// Creates an expression that replaces all occurrences of a literal substring within this string
  /// expression with another literal substring.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Replace all occurrences of " " with "_" in "description"
  /// Field("description").replaceAll(" ", "_")
  /// ```
  ///
  /// - Parameter find: The literal string substring to search for.
  /// - Parameter replace: The literal string substring to replace all occurrences with.
  /// - Returns: A new `FunctionExpr` representing the string with all occurrences replaced.
  func replaceAll(_ find: String, _ replace: String) -> FunctionExpression

  /// Creates an expression that replaces all occurrences of a substring (from an expression) within
  /// this string expression with another substring (from an expression).
  /// Assumes `self` evaluates to a string, and `find`/`replace` evaluate to strings.
  ///
  /// ```swift
  /// // Replace all occurrences of field "target" with field "replacement" in "content"
  /// Field("content").replaceAll(Field("target"), Field("replacement"))
  /// ```
  ///
  /// - Parameter find: An `Expr` (evaluating to a string) for the substring to search for.
  /// - Parameter replace: An `Expr` (evaluating to a string) for the substring to replace all
  /// occurrences with.
  /// - Returns: A new `FunctionExpr` representing the string with all occurrences replaced.
  func replaceAll(_ find: Expression, _ replace: Expression) -> FunctionExpression

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
  /// - Returns: A new `FunctionExpr` representing the length in bytes.
  func byteLength() -> FunctionExpression

  /// Creates an expression that returns a substring of this expression (String or Bytes) using
  /// literal integers for position and optional length.
  /// Indexing is 0-based. Assumes `self` evaluates to a string or bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Get substring from index 5 with length 10
  /// Field("myString").substr(5, 10)
  ///
  /// // Get substring from "myString" starting at index 3 to the end
  /// Field("myString").substr(3, nil)
  /// ```
  ///
  /// - Parameter position: Literal `Int` index of the first character/byte.
  /// - Parameter length: Optional literal `Int` length of the substring. If `nil`, goes to the end.
  /// - Returns: A new `FunctionExpr` representing the substring.
  func substr(_ position: Int, _ length: Int?) -> FunctionExpression

  /// Creates an expression that returns a substring of this expression (String or Bytes) using
  /// expressions for position and optional length.
  /// Indexing is 0-based. Assumes `self` evaluates to a string or bytes, and parameters evaluate to
  /// integers.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Get substring from index calculated by Field("start") with length from Field("len")
  /// Field("myString").substr(Field("start"), Field("len"))
  ///
  /// // Get substring from index calculated by Field("start") to the end
  /// Field("myString").substr(Field("start"), nil) // Passing nil for optional Expr length
  /// ```
  ///
  /// - Parameter position: An `Expr` (evaluating to an Int) for the index of the first
  /// character/byte.
  /// - Parameter length: Optional `Expr` (evaluating to an Int) for the length of the substring. If
  /// `nil`, goes to the end.
  /// - Returns: A new `FunctionExpr` representing the substring.
  func substr(_ position: Expression, _ length: Expression?) -> FunctionExpression

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
  /// - Returns: A new `FunctionExpr` representing the value associated with the given key.
  func mapGet(_ subfield: String) -> FunctionExpression

  /// Creates an expression that removes a key (specified by a literal string) from the map produced
  /// by evaluating this expression.
  /// Assumes `self` evaluates to a Map.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Removes the key "baz" from the map held in field "myMap"
  /// Field("myMap").mapRemove("baz")
  /// ```
  ///
  /// - Parameter key: The literal string key to remove from the map.
  /// - Returns: A new `FunctionExpr` representing the "map_remove" operation.
  func mapRemove(_ key: String) -> FunctionExpression

  /// Creates an expression that removes a key (specified by an expression) from the map produced by
  /// evaluating this expression.
  /// Assumes `self` evaluates to a Map, and `keyExpr` evaluates to a string.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Removes the key specified by field "keyToRemove" from the map in "settings"
  /// Field("settings").mapRemove(Field("keyToRemove"))
  /// ```
  ///
  /// - Parameter keyExpr: An `Expr` (evaluating to a string) representing the key to remove from
  /// the map.
  /// - Returns: A new `FunctionExpr` representing the "map_remove" operation.
  func mapRemove(_ keyExpr: Expression) -> FunctionExpression

  /// Creates an expression that merges this map with multiple other map literals.
  /// Assumes `self` evaluates to a Map. Later maps overwrite keys from earlier maps.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Merge "settings" field with { "enabled": true } and another map literal { "priority": 1 }
  /// Field("settings").mapMerge(["enabled": true], ["priority": 1])
  /// ```
  ///
  /// - Parameter maps: Maps (dictionary literals with `Sendable` values)
  /// to merge.
  /// - Returns: A new `FunctionExpr` representing the "map_merge" operation.
  func mapMerge(_ maps: [[String: Sendable]])
    -> FunctionExpression

  /// Creates an expression that merges this map with multiple other map expressions.
  /// Assumes `self` and other arguments evaluate to Maps. Later maps overwrite keys from earlier
  /// maps.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Merge "baseSettings" field with "userOverrides" field and "adminConfig" field
  /// Field("baseSettings").mapMerge(Field("userOverrides"), Field("adminConfig"))
  /// ```
  ///
  /// - Parameter maps: Additional `Expression` (evaluating to Maps) to merge.
  /// - Returns: A new `FunctionExpr` representing the "map_merge" operation.
  func mapMerge(_ maps: [Expression]) -> FunctionExpression

  // MARK: Aggregations

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
  /// Field("age").avg().alias("averageAge")
  /// ```
  ///
  /// - Returns: A new `AggregateFunction` representing the "avg" aggregation.
  func avg() -> AggregateFunction

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

  // MARK: Logical min/max

  /// Creates an expression that returns the larger value between this expression and other
  /// expressions, based on Firestore"s value type ordering.
  ///
  /// ```swift
  /// // Returns the largest of "val1", "val2", and "val3" fields
  /// Field("val1").logicalMaximum(Field("val2"), Field("val3"))
  /// ```
  ///
  /// - Parameter second: The second `Expr` to compare with.
  /// - Parameter others: Optional additional `Expr` values to compare with.
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
  /// - Parameter second: The second literal `Sendable` value to compare with.
  /// - Parameter others: Optional additional literal `Sendable` values to compare with.
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
  /// - Parameter second: The second `Expr` to compare with.
  /// - Parameter others: Optional additional `Expr` values to compare with.
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
  /// - Parameter second: The second literal `Sendable` value to compare with.
  /// - Parameter others: Optional additional literal `Sendable` values to compare with.
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
  /// - Parameter other: The other vector as an `Expr` to compare against.
  /// - Returns: A new `FunctionExpression` representing the cosine distance.
  func cosineDistance(_ other: Expression) -> FunctionExpression

  /// Calculates the cosine distance between this vector expression and another vector literal
  /// (`VectorValue`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Cosine distance with a VectorValue
  /// let targetVector = VectorValue(vector: [0.1, 0.2, 0.3])
  /// Field("docVector").cosineDistance(targetVector)
  /// ```
  /// - Parameter other: The other vector as a `VectorValue` to compare against.
  /// - Returns: A new `FunctionExpression` representing the cosine distance.
  func cosineDistance(_ other: VectorValue) -> FunctionExpression

  /// Calculates the cosine distance between this vector expression and another vector literal
  /// (`[Double]`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Cosine distance between "location" field and a target location
  /// Field("location").cosineDistance([37.7749, -122.4194])
  /// ```
  /// - Parameter other: The other vector as `[Double]` to compare against.
  /// - Returns: A new `FunctionExpression` representing the cosine distance.
  func cosineDistance(_ other: [Double]) -> FunctionExpression

  /// Calculates the dot product between this vector expression and another vector expression.
  /// Assumes both `self` and `other` evaluate to Vectors.
  ///
  /// ```swift
  /// // Dot product between "vectorA" and "vectorB" fields
  /// Field("vectorA").dotProduct(Field("vectorB"))
  /// ```
  ///
  /// - Parameter other: The other vector as an `Expr` to calculate with.
  /// - Returns: A new `FunctionExpression` representing the dot product.
  func dotProduct(_ other: Expression) -> FunctionExpression

  /// Calculates the dot product between this vector expression and another vector literal
  /// (`VectorValue`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Dot product with a VectorValue
  /// let weightVector = VectorValue(vector: [0.5, -0.5])
  /// Field("features").dotProduct(weightVector)
  /// ```
  /// - Parameter other: The other vector as a `VectorValue` to calculate with.
  /// - Returns: A new `FunctionExpression` representing the dot product.
  func dotProduct(_ other: VectorValue) -> FunctionExpression

  /// Calculates the dot product between this vector expression and another vector literal
  /// (`[Double]`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Dot product between a feature vector and a target vector literal
  /// Field("features").dotProduct([0.5, 0.8, 0.2])
  /// ```
  /// - Parameter other: The other vector as `[Double]` to calculate with.
  /// - Returns: A new `FunctionExpression` representing the dot product.
  func dotProduct(_ other: [Double]) -> FunctionExpression

  /// Calculates the Euclidean distance between this vector expression and another vector
  /// expression.
  /// Assumes both `self` and `other` evaluate to Vectors.
  ///
  /// ```swift
  /// // Euclidean distance between "pointA" and "pointB" fields
  /// Field("pointA").euclideanDistance(Field("pointB"))
  /// ```
  ///
  /// - Parameter other: The other vector as an `Expr` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Euclidean distance.
  func euclideanDistance(_ other: Expression) -> FunctionExpression

  /// Calculates the Euclidean distance between this vector expression and another vector literal
  /// (`VectorValue`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// let targetPoint = VectorValue(vector: [1.0, 2.0])
  /// Field("currentLocation").euclideanDistance(targetPoint)
  /// ```
  /// - Parameter other: The other vector as a `VectorValue` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Euclidean distance.
  func euclideanDistance(_ other: VectorValue) -> FunctionExpression

  /// Calculates the Euclidean distance between this vector expression and another vector literal
  /// (`[Double]`).
  /// Assumes `self` evaluates to a Vector.
  ///
  /// ```swift
  /// // Euclidean distance between "location" field and a target location literal
  /// Field("location").euclideanDistance([37.7749, -122.4194])
  /// ```
  /// - Parameter other: The other vector as `[Double]` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Euclidean distance.
  func euclideanDistance(_ other: [Double]) -> FunctionExpression

  /// Calculates the Manhattan (L1) distance between this vector expression and another vector
  /// expression.
  /// Assumes both `self` and `other` evaluate to Vectors.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Manhattan distance between "vector1" field and "vector2" field
  /// Field("vector1").manhattanDistance(Field("vector2"))
  /// ```
  ///
  /// - Parameter other: The other vector as an `Expr` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Manhattan distance.
  func manhattanDistance(_ other: Expression) -> FunctionExpression

  /// Calculates the Manhattan (L1) distance between this vector expression and another vector
  /// literal (`VectorValue`).
  /// Assumes `self` evaluates to a Vector.
  /// - Note: This API is in beta.
  /// ```swift
  /// let referencePoint = VectorValue(vector: [5.0, 10.0])
  /// Field("dataPoint").manhattanDistance(referencePoint)
  /// ```
  /// - Parameter other: The other vector as a `VectorValue` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Manhattan distance.
  func manhattanDistance(_ other: VectorValue) -> FunctionExpression

  /// Calculates the Manhattan (L1) distance between this vector expression and another vector
  /// literal (`[Double]`).
  /// Assumes `self` evaluates to a Vector.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Manhattan distance between "point" field and a target point
  /// Field("point").manhattanDistance([10.0, 20.0])
  /// ```
  /// - Parameter other: The other vector as `[Double]` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Manhattan distance.
  func manhattanDistance(_ other: [Double]) -> FunctionExpression

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

  /// Creates an expression that adds a specified amount of time to this timestamp expression,
  /// where unit and amount are provided as expressions.
  /// Assumes `self` evaluates to a Timestamp, `unit` evaluates to a unit string, and `amount`
  /// evaluates to an integer.
  ///
  /// ```swift
  /// // Add duration from "unitField"/"amountField" to "timestamp"
  /// Field("timestamp").timestampAdd(Field("unitField"), Field("amountField"))
  /// ```
  ///
  /// - Parameter unit: An `Expr` evaluating to the unit of time string (e.g., "day", "hour").
  ///                 Valid units are "microsecond", "millisecond", "second", "minute", "hour",
  /// "day".
  /// - Parameter amount: An `Expr` evaluating to the amount (Int) of the unit to add.
  /// - Returns: A new "FunctionExpression" representing the resulting timestamp.
  func timestampAdd(_ unit: Expression, _ amount: Expression) -> FunctionExpression

  /// Creates an expression that adds a specified amount of time to this timestamp expression,
  /// where unit and amount are provided as literals.
  /// Assumes `self` evaluates to a Timestamp.
  ///
  /// ```swift
  /// // Add 1 day to the "timestamp" field.
  /// Field("timestamp").timestampAdd(.day, 1)
  /// ```
  ///
  /// - Parameter unit: The `TimeUnit` enum representing the unit of time.
  /// - Parameter amount: The literal `Int` amount of the unit to add.
  /// - Returns: A new "FunctionExpression" representing the resulting timestamp.
  func timestampAdd(_ unit: TimeUnit, _ amount: Int) -> FunctionExpression

  /// Creates an expression that subtracts a specified amount of time from this timestamp
  /// expression,
  /// where unit and amount are provided as expressions.
  /// Assumes `self` evaluates to a Timestamp, `unit` evaluates to a unit string, and `amount`
  /// evaluates to an integer.
  ///
  /// ```swift
  /// // Subtract duration from "unitField"/"amountField" from "timestamp"
  /// Field("timestamp").timestampSub(Field("unitField"), Field("amountField"))
  /// ```
  ///
  /// - Parameter unit: An `Expr` evaluating to the unit of time string (e.g., "day", "hour").
  ///                 Valid units are "microsecond", "millisecond", "second", "minute", "hour",
  /// "day".
  /// - Parameter amount: An `Expr` evaluating to the amount (Int) of the unit to subtract.
  /// - Returns: A new "FunctionExpression" representing the resulting timestamp.
  func timestampSub(_ unit: Expression, _ amount: Expression) -> FunctionExpression

  /// Creates an expression that subtracts a specified amount of time from this timestamp
  /// expression,
  /// where unit and amount are provided as literals.
  /// Assumes `self` evaluates to a Timestamp.
  ///
  /// ```swift
  /// // Subtract 1 day from the "timestamp" field.
  /// Field("timestamp").timestampSub(.day, 1)
  /// ```
  ///
  /// - Parameter unit: The `TimeUnit` enum representing the unit of time.
  /// - Parameter amount: The literal `Int` amount of the unit to subtract.
  /// - Returns: A new "FunctionExpression" representing the resulting timestamp.
  func timestampSub(_ unit: TimeUnit, _ amount: Int) -> FunctionExpression

  // MARK: - Bitwise operations

  /// Creates an expression applying bitwise AND between this expression and an integer literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise AND of "flags" field and 0xFF
  /// Field("flags").bitAnd(0xFF)
  /// ```
  ///
  /// - Parameter otherBits: The integer literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise AND operation.
  func bitAnd(_ otherBits: Int) -> FunctionExpression

  /// Creates an expression applying bitwise AND between this expression and a UInt8 literal (often
  /// for byte masks).
  /// Assumes `self` evaluates to an Integer or Bytes.
  /// - Note: This API is in beta.
  /// ```swift
  /// // Bitwise AND of "byteFlags" field and a byte mask
  /// Field("byteFlags").bitAnd(0b00001111 as UInt8)
  /// ```
  /// - Parameter otherBits: The UInt8 literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise AND operation.
  func bitAnd(_ otherBits: UInt8) -> FunctionExpression

  /// Creates an expression applying bitwise AND between this expression and another expression.
  /// Assumes `self` and `bitsExpression` evaluate to Integer or Bytes.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise AND of "mask1" and "mask2" fields
  /// Field("mask1").bitAnd(Field("mask2"))
  /// ```
  /// - Parameter bitsExpression: The other `Expr` operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise AND operation.
  func bitAnd(_ bitsExpression: Expression) -> FunctionExpression

  /// Creates an expression applying bitwise OR between this expression and an integer literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise OR of "flags" field and 0x01
  /// Field("flags").bitOr(0x01)
  /// ```
  ///
  /// - Parameter otherBits: The integer literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise OR operation.
  func bitOr(_ otherBits: Int) -> FunctionExpression

  /// Creates an expression applying bitwise OR between this expression and a UInt8 literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  /// - Note: This API is in beta.
  /// ```swift
  /// // Set specific bits in "controlByte"
  /// Field("controlByte").bitOr(0b10000001 as UInt8)
  /// ```
  /// - Parameter otherBits: The UInt8 literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise OR operation.
  func bitOr(_ otherBits: UInt8) -> FunctionExpression

  /// Creates an expression applying bitwise OR between this expression and another expression.
  /// Assumes `self` and `bitsExpression` evaluate to Integer or Bytes.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise OR of "permissionSet1" and "permissionSet2" fields
  /// Field("permissionSet1").bitOr(Field("permissionSet2"))
  /// ```
  /// - Parameter bitsExpression: The other `Expr` operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise OR operation.
  func bitOr(_ bitsExpression: Expression) -> FunctionExpression

  /// Creates an expression applying bitwise XOR between this expression and an integer literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise XOR of "toggle" field and 0xFFFF
  /// Field("toggle").bitXor(0xFFFF)
  /// ```
  ///
  /// - Parameter otherBits: The integer literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise XOR operation.
  func bitXor(_ otherBits: Int) -> FunctionExpression

  /// Creates an expression applying bitwise XOR between this expression and a UInt8 literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  /// - Note: This API is in beta.
  /// ```swift
  /// // Toggle bits in "statusByte" using a XOR mask
  /// Field("statusByte").bitXor(0b01010101 as UInt8)
  /// ```
  /// - Parameter otherBits: The UInt8 literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise XOR operation.
  func bitXor(_ otherBits: UInt8) -> FunctionExpression

  /// Creates an expression applying bitwise XOR between this expression and another expression.
  /// Assumes `self` and `bitsExpression` evaluate to Integer or Bytes.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise XOR of "key1" and "key2" fields (assuming Bytes)
  /// Field("key1").bitXor(Field("key2"))
  /// ```
  /// - Parameter bitsExpression: The other `Expr` operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise XOR operation.
  func bitXor(_ bitsExpression: Expression) -> FunctionExpression

  /// Creates an expression applying bitwise NOT to this expression.
  /// Assumes `self` evaluates to an Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise NOT of "mask" field
  /// Field("mask").bitNot()
  /// ```
  ///
  /// - Returns: A new "FunctionExpression" representing the bitwise NOT operation.
  func bitNot() -> FunctionExpression

  /// Creates an expression applying bitwise left shift to this expression by a literal number of
  /// bits.
  /// Assumes `self` evaluates to Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Left shift "value" field by 2 bits
  /// Field("value").bitLeftShift(2)
  /// ```
  ///
  /// - Parameter y: The number of bits (Int literal) to shift by.
  /// - Returns: A new "FunctionExpression" representing the bitwise left shift operation.
  func bitLeftShift(_ y: Int) -> FunctionExpression

  /// Creates an expression applying bitwise left shift to this expression by a number of bits
  /// specified by an expression.
  /// Assumes `self` evaluates to Integer or Bytes, and `numberExpr` evaluates to an Integer.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Left shift "data" by number of bits in "shiftCount" field
  /// Field("data").bitLeftShift(Field("shiftCount"))
  /// ```
  /// - Parameter numberExpr: An `Expr` (evaluating to an Int) for the number of bits to shift by.
  /// - Returns: A new "FunctionExpression" representing the bitwise left shift operation.
  func bitLeftShift(_ numberExpr: Expression) -> FunctionExpression

  /// Creates an expression applying bitwise right shift to this expression by a literal number of
  /// bits.
  /// Assumes `self` evaluates to Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Right shift "value" field by 4 bits
  /// Field("value").bitRightShift(4)
  /// ```
  ///
  /// - Parameter y: The number of bits (Int literal) to shift by.
  /// - Returns: A new "FunctionExpression" representing the bitwise right shift operation.
  func bitRightShift(_ y: Int) -> FunctionExpression

  /// Creates an expression applying bitwise right shift to this expression by a number of bits
  /// specified by an expression.
  /// Assumes `self` evaluates to Integer or Bytes, and `numberExpr` evaluates to an Integer.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Right shift "data" by number of bits in "shiftCount" field
  /// Field("data").bitRightShift(Field("shiftCount"))
  /// ```
  /// - Parameter numberExpr: An `Expr` (evaluating to an Int) for the number of bits to shift by.
  /// - Returns: A new "FunctionExpression" representing the bitwise right shift operation.
  func bitRightShift(_ numberExpr: Expression) -> FunctionExpression

  func documentId() -> FunctionExpression

  /// Creates an expression that returns the result of `catchExpr` if this expression produces an
  /// error during evaluation,
  /// otherwise returns the result of this expression.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Try dividing "a" by "b", return field "fallbackValue" on error (e.g., division by zero)
  /// Field("a").divide(Field("b")).ifError(Field("fallbackValue"))
  /// ```
  ///
  /// - Parameter catchExpr: The `Expr` to evaluate and return if this expression errors.
  /// - Returns: A new "FunctionExpression" representing the "ifError" operation.
  func ifError(_ catchExpr: Expression) -> FunctionExpression

  /// Creates an expression that returns the literal `catchValue` if this expression produces an
  /// error during evaluation,
  /// otherwise returns the result of this expression.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Get first item in "title" array, or return "Default Title" if error (e.g., empty array)
  /// Field("title").arrayGet(0).ifError("Default Title")
  /// ```
  ///
  /// - Parameter catchValue: The literal `Sendable` value to return if this expression errors.
  /// - Returns: A new "FunctionExpression" representing the "ifError" operation.
  func ifError(_ catchValue: Sendable) -> FunctionExpression

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
}
