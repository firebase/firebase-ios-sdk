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

/// The strategy to use when an error occurs during mapping Firestore documents
/// to the target type of `FirestoreQuery`.
///
public enum DecodingFailureStrategy {
  /// Ignore any errors that occur when mapping Firestore documents.
  case ignore

  /// Raise an error when mapping a Firestore document fails.
  case raise
}

/// A property wrapper that listens to a Firestore collection.
///
/// In the following example, `FirestoreQuery` will fetch all documents from the
/// `fruits` collection, filtering only documents whose `isFavourite` attribute
/// is equal to `true`, map members of result set to the `Fruit` type, and make
/// them available via the wrapped value `fruits`.
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
/// `FirestoreQuery` also supports returning a `Result` type. The `.success` case
/// returns an array of elements, whereas the `.failure` case returns an error
/// in case mapping the Firestore docments wasn't successful:
///
///     struct ContentView: View {
///       @FirestoreQuery(
///         collectionPath: "fruits",
///         predicates: [.whereField("isFavourite", isEqualTo: true)]
///       ) var fruitResults: Result<[Fruit], Error>
///
///     var body: some View {
///       if case let .success(fruits) = fruitResults {
///         List(fruits) { fruit in
///           Text(fruit.name)
///         }
///       } else if case let .failure(error) = fruitResults {
///         Text("Couldn't map data: \(error.localizedDescription)")
///       }
///     }
///
/// Alternatively, the _projected value_ of the property wrapper provides access to
/// the `error` as well. This allows you to display a list of all successfully mapped
/// documents, as well as an error message with details about the documents that couldn't
/// be mapped successfully (e.g. because of a field name mismatch).
///
///     struct ContentView: View {
///       @FirestoreQuery(
///         collectionPath: "mappingFailure",
///         decodingFailureStrategy: .ignore
///       ) private var fruits: [Fruit]
///
///       var body: some View {
///         VStack(alignment: .leading) {
///           List(fruits) { fruit in
///             Text(fruit.name)
///           }
///           if $fruits.error != nil {
///             HStack {
///               Text("There was an error")
///                 .foregroundColor(Color(UIColor.systemBackground))
///               Spacer()
///             }
///             .padding(30)
///             .background(Color.red)
///           }
///         }
///       }
///     }
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

    // The strategy to use in case there was a problem during the decoding phase.
    public var decodingFailureStrategy: DecodingFailureStrategy = .raise

    /// If any errors occurred, they will be exposed here as well.
    public var error: Error?
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
  ///   - decodingFailureStrategy: The strategy to use when there is a failure
  ///     during the decoding phase. Defaults to `DecodingFailureStrategy.raise`.
  public init<U: Decodable>(collectionPath: String, predicates: [QueryPredicate] = [],
                            decodingFailureStrategy: DecodingFailureStrategy = .raise)
    where T == [U] {
    let configuration = Configuration(
      path: collectionPath,
      predicates: predicates,
      decodingFailureStrategy: decodingFailureStrategy
    )

    _firestoreQueryObservable =
      StateObject(wrappedValue: FirestoreQueryObservable<T>(configuration: configuration))
  }

  /// Creates an instance by defining a query based on the parameters.
  /// - Parameters:
  ///   - collectionPath: The path to the Firestore collection to query.
  ///   - predicates: An optional array of `QueryPredicate`s that defines a
  ///     filter for the fetched results.
  ///   - decodingFailureStrategy: The strategy to use when there is a failure
  ///     during the decoding phase. Defaults to `DecodingFailureStrategy.raise`.
  public init<U: Decodable>(collectionPath: String, predicates: [QueryPredicate] = [],
                            decodingFailureStrategy: DecodingFailureStrategy = .raise)
    where T == Result<[U], Error> {
    let configuration = Configuration(
      path: collectionPath,
      predicates: predicates,
      decodingFailureStrategy: decodingFailureStrategy
    )

    _firestoreQueryObservable =
      StateObject(wrappedValue: FirestoreQueryObservable<T>(configuration: configuration))
  }
}
