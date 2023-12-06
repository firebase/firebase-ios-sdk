//
//  File.swift
//  
//
//  Created by Aashish Patil on 10/18/23.
//

import Foundation

import FirebaseCore


@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class FirebaseDataConnect {

  private var app: FirebaseApp
  private var settings: ServerSettings
  private var serviceConfig: ServiceConfig

  init(app: FirebaseApp, settings: ServerSettings, serviceConfig: ServiceConfig) {
    self.app = app
    self.settings = settings
    self.serviceConfig = serviceConfig
  }

  init(settings: ServerSettings, serviceConfig: ServiceConfig) throws {

    guard let app = FirebaseApp.app() else {
      throw DataConnectError.appConfigure
    }

    self.app = app
    self.settings = settings
    self.serviceConfig = serviceConfig
  }

}
