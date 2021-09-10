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

import SwiftUI
import FirebaseFirestore

/// A property wrapper that listens to a Firestore collection.
///
/// Consider the following example:
///
///     struct ContentView: View {
///       @FirestoreQuery(
///         collectionPath: "fruits",
///         predicates: [.whereField("isFavourite", isEqualTo: true)]
///       ) var fruits: [Fruit]
///
///       var body: some View {
///         List(fruits) { fruit in
///           Text(fruit.name)
///         }
///       }
///     }
///
/// In this example, `FirestoreQuery` will fetch all documents from the `fruits`
/// collection, filtering only documents whose `isFavourite` attribute is equal
/// to `true`, map members of result set to the `Fruit` type, and make them
/// available via the wrapped value `fruits`.
///
/// Internally, `@FirestoreQuery` sets up a snapshot listener and publishes
/// any incoming changes via an `@StateObject`.
///
/// The projected value of this property wrapper provides access to a
/// configuration object of type `FirestoreQueryConfiguration` which can be used
/// to modify the query criteria. Changing the filter predicates results in the
/// underlying snapshot listener being unregistered and a new one registered.
///
///     Button("Show only Apples and Oranges") {
///       $fruits.predicates = [.whereField("name", isIn: ["Apple", "Orange]]
///     }
///
/// This property wrapper does not support updating the `wrappedValue`, i.e.
/// you need to use Firestore's other APIs to add, delete, or modify documents.
@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
@propertyWrapper
public struct FirestoreQuery<T>: DynamicProperty {
  @StateObject private var firestoreQueryObservable: FirestoreQueryObservable<T>

  /// The query's configurable properties.
  public struct Configuration {
    /// The query's collection path.
    public var path: String

    /// The query's predicates.
    public var predicates: [QueryPredicate]
  }

  /// The results of the query.
  ///
  /// This property returns an empty collection when there are no matching results.
  public var wrappedValue: T {
    firestoreQueryObservable.items
  }

  /// A binding to the request's mutable configuration properties
  public var projectedValue: Configuration {
    get {
      firestoreQueryObservable.configuration
    }
    nonmutating set {
      firestoreQueryObservable.objectWillChange.send()
      firestoreQueryObservable.configuration = newValue
    }
  }

  /// Creates an instance by defining a query based on the parameters.
  /// - Parameters:
  ///   - collectionPath: The path to the Firestore collection to query.
  ///   - predicates: An optional array of `QueryPredicate`s that defines a
  ///     filter for the fetched results.
  public init<U: Decodable>(collectionPath: String, predicates: [QueryPredicate] = [])
    where T == [U] {
    let configuration = Configuration(path: collectionPath, predicates: predicates)

    _firestoreQueryObservable =
      StateObject(wrappedValue: FirestoreQueryObservable<T>(configuration: configuration))
  }

  /// Creates an instance by defining a query based on the parameters.
  /// - Parameters:
  ///   - collectionPath: The path to the Firestore collection to query.
  ///   - predicates: An optional array of `QueryPredicate`s that defines a
  ///     filter for the fetched results.
  public init<U: Decodable>(collectionPath: String, predicates: [QueryPredicate] = [])
    where T == [Result<U, Error>] {
    let configuration = Configuration(path: collectionPath, predicates: predicates)

    _firestoreQueryObservable =
      StateObject(wrappedValue: FirestoreQueryObservable<T>(configuration: configuration))
  }

  /// Creates an instance by defining a query based on the parameters.
  /// - Parameters:
  ///   - collectionPath: The path to the Firestore collection to query.
  ///   - predicates: An optional array of `QueryPredicate`s that defines a
  ///     filter for the fetched results.
  public init<U: Decodable>(collectionPath: String, predicates: [QueryPredicate] = [])
    where T == Result<[U], Error> {
    let configuration = Configuration(path: collectionPath, predicates: predicates)

    _firestoreQueryObservable =
      StateObject(wrappedValue: FirestoreQueryObservable<T>(configuration: configuration))
  }
}
