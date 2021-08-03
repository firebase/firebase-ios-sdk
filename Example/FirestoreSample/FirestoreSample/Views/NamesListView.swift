// Copyright 2021 Google LLC
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

import SwiftUI
import FirebaseFirestoreSwift

struct Developer: Codable, Identifiable {
  @DocumentID var id: String?
  var name: String
}

struct NamesListView: View {
  @FirestoreQuery(collectionPath: "names", predicates: [.isNotIn(field: "name", values: ["Peter", "Paul"])]) var developers: [Developer]
  @FirestoreQuery(collectionPath: "names", predicates: [.whereField("name", isIn: ["Ryan", "Walter"])]) var developers2: [Developer]
  @FirestoreQuery(collectionPath: "names", predicates: [.where(field: "name", isIn: ["Ryan", "Walter"])]) var developers3: [Developer]

  var body: some View {
    List(developers) { developer in
      Text(developer.name)
    }
    .toolbar {
      ToolbarItem {
        Button(action: add) {
          Image(systemName: "plus")
        }
      }
    }
  }

  func add() {
//    let developer = Developer(name: "Florian")
//    developers.append(developer)
  }
}

struct NamesListView_Previews: PreviewProvider {
  static var previews: some View {
    NamesListView()
  }
}
