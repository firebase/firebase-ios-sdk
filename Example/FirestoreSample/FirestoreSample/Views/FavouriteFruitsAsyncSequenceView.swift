/*
 * Copyright 2023 Google LLC
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
import FirebaseFirestoreSwift
import FirebaseAuth

private struct Fruit: Codable, Identifiable, Equatable {
  @DocumentID var id: String?
  var name: String
  var isFavourite: Bool
}

struct FavouriteFruitsAsyncSequenceView: View {
  @State var showAuthenticationView = false

  @State fileprivate var fruits: [Fruit] = []
  @State var showOnlyFavourites = true

  var body: some View {
    List(fruits) { fruit in
      Text(fruit.name)
    }
    .task {
      //      await fetchDocument1()
      await fetchDocuments2()
    }
    .animation(.default, value: fruits)
    .navigationTitle("Fruits")
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { showAuthenticationView.toggle() }) {
          Image(systemName: "person.circle")
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
    .sheet(isPresented: $showAuthenticationView) {
      AuthenticationView()
    }
  }

  private func fetchDocument1() async {
    do {
      // getting all documents as a single snapshot
      let collection = Firestore.firestore().collection("fruits")
      let auth = Auth.auth()
      let fruitsSequence = auth
        .authDidChangeSequence()
        .compactMap { user in
          user?.uid
        }
        .flatMap { userId in
          collection
            .whereField("userId", isEqualTo: userId)
            .snapshotSequence(Fruit.self)
        }

      for try await fruits in fruitsSequence {
        self.fruits = fruits
      }
    } catch {
      print(error)
    }
  }

@MainActor
private func fetchDocuments2() async {
  do {
    let collection = Firestore.firestore().collection("fruits")
    let auth = Auth.auth()

    let fruits = auth
      .authDidChangeSequence()
      .compactMap { $0?.uid }
      .flatMap {
        collection
          .whereField("userId", isEqualTo: $0)
          .documents(as: Fruit.self)
          .compactMap { $0 }
          .filter { $0.isFavourite }
      }

    self.fruits = try await fruits.collect()
  }
  catch {
    print(error)
  }
}

  func toggleFilter() {
    showOnlyFavourites.toggle()
  }
}

extension AsyncSequence {
  public func collect(_ numberOfElements: Int? = .none) async rethrows -> [Element] {
    var results: [Element] = []
    for try await element in self {
      results.append(element)

      if let numberOfElements = numberOfElements,
         results.count >= numberOfElements {
        break
      }
    }

    return results
  }

  @discardableResult
  public func assign<Root>(
    to keyPath: ReferenceWritableKeyPath<Root, Element>,
    on object: Root
  ) rethrows -> Task<Void, Error> where Self: Sendable, Root: Sendable {
    Task {
      for try await element in self {
        object[keyPath: keyPath] = element
      }
    }
  }
}

struct FavouriteFruitsAsyncSequenceView_Previews: PreviewProvider {
  static var previews: some View {
    FavouriteFruitsAsyncSequenceView()
  }
}

