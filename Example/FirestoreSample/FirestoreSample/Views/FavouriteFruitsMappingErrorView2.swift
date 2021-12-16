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

private struct Fruit: Codable, Identifiable, Equatable {
  @DocumentID var id: String?
  var name: String
}

struct FavouriteFruitsMappingErrorView2: View {
  @FirestoreQuery(
    collectionPath: "mappingFailure",
    decodingFailureStrategy: .ignore
  ) private var fruits: [Fruit]

  var body: some View {
    VStack(alignment: .leading) {
      List(fruits) { fruit in
        Text(fruit.name)
      }
      if $fruits.error != nil {
        HStack {
          Text("There was an error")
            .foregroundColor(Color(UIColor.systemBackground))
          Spacer()
        }
        .padding(30)
        .background(Color.red)
      }
    }
    .animation(.default, value: fruits)
    .navigationTitle("Mapping failure")
    .ignoresSafeArea(edges: .bottom)
  }
}

struct FavouriteFruitsMappingErrorView2_Previews: PreviewProvider {
  static var previews: some View {
    FavouriteFruitsMappingErrorView2()
  }
}
