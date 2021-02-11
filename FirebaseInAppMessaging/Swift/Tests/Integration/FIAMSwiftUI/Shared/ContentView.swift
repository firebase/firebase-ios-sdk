//
//  ContentView.swift
//  Shared
//
//  Created by Chris Tibbs on 2/9/21.
//

import SwiftUI
import FirebaseInAppMessaging

struct ContentView: View {
  @State var analyticsEvent = ""

  var body: some View {
    VStack {
      Text("Firebase In-App Messaging")
        .font(.largeTitle)
        .bold()
        .multilineTextAlignment(.center)
        .padding()
      Text("🔥💍")
        .font(.system(size: 60.0))
        .padding()
      TextField("Enter an analytics event to trigger",
                text: $analyticsEvent) { _ in
      } onCommit: { InAppMessaging.inAppMessaging().triggerEvent(analyticsEvent) }
        .multilineTextAlignment(.center)
        .autocapitalization(.none)
        .padding()
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
