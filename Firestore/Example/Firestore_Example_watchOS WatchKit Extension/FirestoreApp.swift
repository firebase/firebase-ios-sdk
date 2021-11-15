//
//  FirestoreApp.swift
//  Firestore_Example_watchOS WatchKit Extension
//
//  Created by Hui Wu on 2021-11-15.
//  Copyright © 2021 Google. All rights reserved.
//

import SwiftUI

@main
struct FirestoreApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
