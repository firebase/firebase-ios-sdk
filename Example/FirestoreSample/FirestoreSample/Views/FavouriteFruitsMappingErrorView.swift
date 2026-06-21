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

import FirebaseFirestore
import SwiftUI

private struct Fruit: Codable, Identifiable, Equatable {
  @DocumentID var id: String?
  var name: String
}

/// This view demonstrates how to use the `FirestoreQuery` property wrapper's
/// error handling. When any of the documents can't be mapped, this view will
/// just show an error message.
struct FavouriteFruitsMappingErrorView: View {
  @FirestoreQuery(
    collectionPath: "mappingFailure",
    decodingFailureStrategy: .raise,
    animation: .default
  ) private var fruitResults: Result<[Fruit], Error>

  var body: some View {
    switch fruitResults {
    case let .success(fruits):
      List(fruits) { fruit in
        Text(fruit.name)
      }
      .navigationTitle("Mapping failure")

    case let .failure(error):
      // Handle error
      VStack {
        Text("Couldn't map data: \(error.localizedDescription)")
      }
    }
  }
}

struct FavouriteFruitsMappingErrorView_Previews: PreviewProvider {
  static var previews: some View {
    FavouriteFruitsMappingErrorView()
  }
}
