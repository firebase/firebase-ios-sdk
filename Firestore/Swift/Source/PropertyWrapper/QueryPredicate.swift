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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

/// Query predicates that can be used to filter results fetched by `FirestoreQuery`.
///
/// Construct predicates using one of the following ways:
///
///     let onlyFavourites: QueryPredicate = .whereField("isFavourite", isEqualTo: true)
///     let onlyFavourites2: QueryPredicate = .isEqualTo("isFavourite", true)
///     let onlyFavourites3: QueryPredicate = .where("isFavourite", isEqualTo: true)
public enum QueryPredicate {
  case isEqualTo(_ field: String, _ value: Any)

  case isIn(_ field: String, _ values: [Any])
  case isNotIn(_ field: String, _ values: [Any])

  case arrayContains(_ field: String, _ value: Any)
  case arrayContainsAny(_ field: String, _ values: [Any])

  case isLessThan(_ field: String, _ value: Any)
  case isGreaterThan(_ field: String, _ value: Any)

  case isLessThanOrEqualTo(_ field: String, _ value: Any)
  case isGreaterThanOrEqualTo(_ field: String, _ value: Any)

  case orderBy(_ field: String, _ value: Bool)

  case limitTo(_ value: Int)
  case limitToLast(_ value: Int)

  /*
   Factory methods
   */
  public static func whereField(_ field: String, isEqualTo value: Any) -> QueryPredicate {
    .isEqualTo(field, value)
  }

  public static func whereField(_ field: String, isIn values: [Any]) -> QueryPredicate {
    .isIn(field, values)
  }

  public static func whereField(_ field: String, isNotIn values: [Any]) -> QueryPredicate {
    .isNotIn(field, values)
  }

  public static func whereField(_ field: String, arrayContains value: Any) -> QueryPredicate {
    .arrayContains(field, value)
  }

  public static func whereField(_ field: String,
                                arrayContainsAny values: [Any]) -> QueryPredicate {
    .arrayContainsAny(field, values)
  }

  public static func whereField(_ field: String, isLessThan value: Any) -> QueryPredicate {
    .isLessThan(field, value)
  }

  public static func whereField(_ field: String, isGreaterThan value: Any) -> QueryPredicate {
    .isGreaterThan(field, value)
  }

  public static func whereField(_ field: String,
                                isLessThanOrEqualTo value: Any) -> QueryPredicate {
    .isLessThanOrEqualTo(field, value)
  }

  public static func whereField(_ field: String,
                                isGreaterThanOrEqualTo value: Any) -> QueryPredicate {
    .isGreaterThanOrEqualTo(field, value)
  }

  public static func order(by field: String, descending value: Bool = false) -> QueryPredicate {
    .orderBy(field, value)
  }

  public static func limit(to value: Int) -> QueryPredicate {
    .limitTo(value)
  }

  public static func limit(toLast value: Int) -> QueryPredicate {
    .limitToLast(value)
  }

  // Alternate naming

  public static func `where`(_ name: String, isEqualTo value: Any) -> QueryPredicate {
    .isEqualTo(name, value)
  }

  public static func `where`(_ name: String, isIn values: [Any]) -> QueryPredicate {
    .isIn(name, values)
  }

  public static func `where`(_ name: String, isNotIn values: [Any]) -> QueryPredicate {
    .isNotIn(name, values)
  }

  public static func `where`(field name: String, arrayContains value: Any) -> QueryPredicate {
    .arrayContains(name, value)
  }

  public static func `where`(_ name: String, arrayContainsAny values: [Any]) -> QueryPredicate {
    .arrayContainsAny(name, values)
  }

  public static func `where`(_ name: String, isLessThan value: Any) -> QueryPredicate {
    .isLessThan(name, value)
  }

  public static func `where`(_ name: String, isGreaterThan value: Any) -> QueryPredicate {
    .isGreaterThan(name, value)
  }

  public static func `where`(_ name: String, isLessThanOrEqualTo value: Any) -> QueryPredicate {
    .isLessThanOrEqualTo(name, value)
  }

  public static func `where`(_ name: String,
                             isGreaterThanOrEqualTo value: Any) -> QueryPredicate {
    .isGreaterThanOrEqualTo(name, value)
  }
}
