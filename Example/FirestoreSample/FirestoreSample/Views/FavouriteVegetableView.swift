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

private struct Vegetable: Codable, FirestoreDocumentReferable {
    var documentID: String = ""
    var name: String
    var isFavourite: Bool
}

struct FavouriteVegetableView: View {
    @FirestoreQuery(
      collectionPath: "vegetables",
      predicates: [
        .where("isFavourite", isEqualTo: false),
      ]
    ) fileprivate var vegetableResults: FirestoreQueryResult<Vegetable>
    
    @State var showOnlyFavourites = false
    @State var newVegetableName = ""
    
    var body: some View {
        Form {
            Section(header: Text("Add Vegetable")) {
                TextField("Name", text: $newVegetableName)
                Button("Add") {
                    vegetableResults.addDocument(Vegetable(
                        name: newVegetableName,
                        isFavourite: false
                    ))
                }
            }
            
            List {
                ForEach(vegetableResults, id: \.documentID) { vegetable in
                    Text(vegetable.name)
                }
                .onDelete { indexSet in
                    vegetableResults.removeDocument(at: indexSet)
                }
            }
        }
        .navigationTitle("My Vegetables")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleFilter) {
                  Image(systemName: showOnlyFavourites
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
    
    private func toggleFilter() {
      showOnlyFavourites.toggle()
      if showOnlyFavourites {
        $vegetableResults.predicates = [
          .whereField("isFavourite", isEqualTo: true),
        ]
      } else {
          $vegetableResults.predicates = []
      }
    }
}

struct FavouriteVegetableView_Previews: PreviewProvider {
    static var previews: some View {
        FavouriteVegetableView()
    }
}
