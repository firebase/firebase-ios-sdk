//
//  ContentView.swift
//  RemoteConfigSwiftSample
//
//  Created by Karen Zeng on 11/16/20.
//  Copyright © 2020 Firebase. All rights reserved.
//

import SwiftUI
import FirebaseRemoteConfig

var remoteConfig: RemoteConfig!

struct ContentView: View {
    public init() {
        remoteConfig = RemoteConfig.remoteConfig()
    }
    
    var body: some View {
        Button(action: fetchRemoteConfig) {
            Text("Fetch")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

func fetchRemoteConfig() -> Void {
    remoteConfig.fetch() { (status, error) -> Void in
        if status == .success {
            print("Fetched successfully")
        } else {
            print("Fetch error:", error?.localizedDescription ?? "No error available.")
        }
    }
}
