// Copyright 2020 Google LLC
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
import FirebaseCore
import FirebaseMessaging

struct TopicView: View {
  @State private var topic: String = ""
  @State private var result: String = ""

  var body: some View {
    VStack(alignment: .leading) {
      Text("Topic").font(.callout).bold()
      TextField("Enter your topic", text: $topic)
        .textFieldStyle(RoundedBorderTextFieldStyle())
      Button(action: subscribe) {
        HStack {
          Image(systemName: "t.bubble.fill").font(.body)
          Text("Subscribe")
            .fontWeight(.semibold)
        }
      }
      Button(action: unsubscribe) {
        HStack {
          Image(systemName: "bin.xmark.fill").font(.body)
          Text("Unsubscribe")
            .fontWeight(.semibold)
        }
      }
      Text("\(result)")
        .lineLimit(10)
        .multilineTextAlignment(.leading)
    }
    .padding()
    .buttonStyle(IdentityButtonStyle())
  }

  func subscribe() {
    Messaging.messaging().subscribe(toTopic: topic) { error in
      if let error = error as NSError? {
        self.result = "Failed subscription: \(error)"
        return
      }
      self.result = "Successfully subscribe \(self.topic)."
    }
  }

  func unsubscribe() {
    Messaging.messaging().unsubscribe(fromTopic: topic) { error in
      if let error = error as NSError? {
        self.result = "Failed unsubscription: \(error)"
        return
      }
      self.result = "Successfully unsubscribe \(self.topic)"
    }
  }
}

struct TopicView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      TopicView()
    }
  }
}
