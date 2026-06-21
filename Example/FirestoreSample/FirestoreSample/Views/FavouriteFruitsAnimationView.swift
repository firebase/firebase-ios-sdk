// Copyright 2023 Google LLC
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

import FirebaseFirestore
import SwiftUI

private struct Fruit: Codable, Identifiable, Equatable {
  @DocumentID var id: String?
  var name: String
  var isFavourite: Bool
}

extension Fruit {
  static let fruits = [
    Fruit(name: "Apple", isFavourite: true),
    Fruit(name: "Banana", isFavourite: true),
    Fruit(name: "Orange", isFavourite: true),
    Fruit(name: "Pineapple", isFavourite: true),
    Fruit(name: "Dragonfruit", isFavourite: true),
    Fruit(name: "Mangosteen", isFavourite: true),
    Fruit(name: "Lychee", isFavourite: true),
    Fruit(name: "Passionfruit", isFavourite: true),
    Fruit(name: "Starfruit", isFavourite: true),
  ]

  static func randomFruit() -> Fruit {
    return Fruit.fruits.randomElement()!
  }
}

/// This view demonstrates how to use the `FirestoreQuery` property wrapper,
/// using the `animation` parameter to make sure list items are animated when
/// being added or removed.
struct FavouriteFruitsAnimationView: View {
  @FirestoreQuery(
    collectionPath: "fruits",
    predicates: [
      .where("isFavourite", isEqualTo: true),
    ],
    animation: .default
  ) fileprivate var fruitResults: Result<[Fruit], Error>

  @State var showOnlyFavourites = true

  private func delete(fruit: Fruit) {
    if let id = fruit.id {
      Firestore.firestore().collection("fruits").document(id).delete()
    }
  }

  private func addRandomFruit() {
    let fruit = Fruit.randomFruit()
    add(fruit: fruit)
  }

  private func add(fruit: Fruit) {
    do {
      try Firestore.firestore().collection("fruits").addDocument(from: fruit)
    } catch {
      print(error)
    }
  }

  var body: some View {
    if case let .success(fruits) = fruitResults {
      List(fruits) { fruit in
        Text(fruit.name)
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
              delete(fruit: fruit)
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
      }
      .navigationTitle("Fruits")
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          Button {
            addRandomFruit()
          } label: {
            Label("Add", systemImage: "plus")
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: toggleFilter) {
            Image(systemName: showOnlyFavourites
              ? "line.3.horizontal.decrease.circle.fill"
              : "line.3.horizontal.decrease.circle")
          }
        }
      }
    } else if case let .failure(error) = fruitResults {
      // Handle error
      Text("Couldn't map data: \(error.localizedDescription)")
    }
  }

  func toggleFilter() {
    showOnlyFavourites.toggle()
    if showOnlyFavourites {
      $fruitResults.predicates = [
        .whereField("isFavourite", isEqualTo: true),
      ]
    } else {
      $fruitResults.predicates = []
    }
  }
}

struct FavouriteFruitsAnimationView_Previews: PreviewProvider {
  static var previews: some View {
    FavouriteFruitsAnimationView()
  }
}
