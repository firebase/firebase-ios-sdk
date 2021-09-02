//
//  FavouriteFruitsMappingErrorView.swift
//  FavouriteFruitsMappingErrorView
//
//  Created by Peter Friese on 02.09.21.
//

import SwiftUI
import FirebaseFirestoreSwift

private struct Fruit: Codable, Identifiable, Equatable {
  @DocumentID var id: String?
  var name: String
}

struct FavouriteFruitsMappingErrorView: View {
  @FirestoreQuery(
    collectionPath: "mappingFailure"
  ) private var fruitResults: Result<[Fruit], Error>
  
  var body: some View {
    if case let .success(fruits) = fruitResults {
      List(fruits) { fruit in
        Text(fruit.name)
      }
      .animation(.default, value: fruits)
      .navigationTitle("Mapping failure")
    }
    else if case let .failure(error as NSError) = fruitResults {
      // Handle error
      Text("Couldn't map data: \(error)")
    }
  }
}

struct FavouriteFruitsMappingErrorView_Previews: PreviewProvider {
  static var previews: some View {
    FavouriteFruitsMappingErrorView()
  }
}
