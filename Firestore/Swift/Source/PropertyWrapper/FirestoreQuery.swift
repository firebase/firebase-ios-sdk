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

import FirebaseFirestore
import SwiftUI

/// A Property Wrapper to fetch data from Firestore and keep an active SnapshotListener to listen to changes.
///
/// Consider the following Example:
///
///     struct ContentView: View {
///         @FirestoreQuery(collectionPath: "developers",
///                      predicates: [
///                         .whereField("firstName", isEqualTo: "Flo")
///                      ]
///         ) var developers: [Developer]
///
///         var body: some View {
///             List(developers) { developer in
///                Text(developer.name)
///            }
///         }
///     }
///
/// The FirestoreQuery automatically fetches all developers with the firstName "Flo" from Firestore, adds them to the developers array and keeps a SnapshotListener alive.
/// A FirestoreQueryConfiguration is generated based on the specified collectionPath and predicates, which can be accessed and updated with the projectedValue:
///
///     Button("Change Name to Peter") {
///         $developers.predicates = [.whereField("firstName", isEqualTo: "Peter"]
///     }
///
/// This automatically removes the old SnapshotListener and installs a new one based on the updated configuration.
///
/// The Property Wrapper does not support updating the wrappedValue, i.e. creating a new document needs to be done through the basic Firestore APIs.
@available(iOS 14.0, *)
@available(tvOS, unavailable)
@propertyWrapper
public struct FirestoreQuery<T: Decodable>: DynamicProperty {
  @StateObject private var firestoreQueryObservable: FirestoreQueryObservable<T>

  public var wrappedValue: [T] {
    firestoreQueryObservable.items
  }

  public var projectedValue: FirestoreQueryConfiguration {
    get {
      firestoreQueryObservable.configuration
    }
    nonmutating set {
      firestoreQueryObservable.objectWillChange.send()
      firestoreQueryObservable.configuration = newValue
    }
  }

  public init(collectionPath: String, predicates: [QueryPredicate] = []) {
    let configuration = FirestoreQueryConfiguration(path: collectionPath, predicates: predicates)

    _firestoreQueryObservable =
      StateObject(wrappedValue: FirestoreQueryObservable<T>(configuration: configuration))
  }
}
