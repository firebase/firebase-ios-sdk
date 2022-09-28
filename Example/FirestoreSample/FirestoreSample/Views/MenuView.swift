// Copyright 2022 Google LLC
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

struct MenuView: View {
  var body: some View {
    List {
      Section(header: Text("Firestore Property Wrapper")) {
        NavigationLink(destination: FavouriteFruitsView()) {
          Label("**@FirestoreQuery** \nFetch data from a collection",
                systemImage: "shippingbox")
        }
        NavigationLink(destination: FavouriteFruitsMappingErrorView()) {
          Label("**Mapping failure** \nDisplay a different view if any document cannot be mapped.",
                systemImage: "shippingbox")
        }
        NavigationLink(destination: FavouriteFruitsMappingErrorView2()) {
          Label("**Mapping failure 2** \nShow how to recover from a mapping failure",
                systemImage: "shippingbox")
        }
      }
    }
    .listStyle(InsetGroupedListStyle())
    .navigationTitle("Firestore")
  }
}

struct MenuView_Previews: PreviewProvider {
  static var previews: some View {
    MenuView()
  }
}
