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

private struct Fruit: Codable, Identifiable, Equatable {
  @DocumentID var id: String?
  var name: String
  var isFavourite: Bool
}

extension Fruit {
  static let empty = Fruit(name: "", isFavourite: false)
}

struct FavouriteFruitView: View {
  @State fileprivate var fruit: Fruit = .empty

  var body: some View {
    VStack {
      Text(fruit.name)
      Toggle(isOn: $fruit.isFavourite, label: {
        Text("Is favourite")
      })
    }
    .task {
      do {
        let doc = Firestore.firestore().collection("fruits").document("1uxSAlCvYWmfrXN7rn2s")
        for try await fruit in doc.snapshotSequence(Fruit.self) {
          self.fruit = fruit
        }
      } catch {
        print(error)
      }
    }
    .navigationTitle("Fruit")
  }
}

struct FavouriteFruitView_Previews: PreviewProvider {
  static var previews: some View {
    FavouriteFruitView()
  }
}
