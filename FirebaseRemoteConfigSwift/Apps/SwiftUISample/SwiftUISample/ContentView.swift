//
//  ContentView.swift
//  SwiftUISample
//
//  Created by Charlotte Liang on 7/29/22.
//

import SwiftUI
import FirebaseRemoteConfigSwift

struct ContentView: View {
  @RemoteConfigProperty(forKey: "Color") var configValue : String 
    var body: some View {
        Text(configValue)
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
