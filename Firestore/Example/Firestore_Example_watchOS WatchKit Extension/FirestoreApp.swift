//
//  FirestoreApp.swift
//  Firestore_Example_watchOS WatchKit Extension
//
//  Created by Cheryl Lin on 2022-06-08.
//  Copyright © 2022 Google. All rights reserved.
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
