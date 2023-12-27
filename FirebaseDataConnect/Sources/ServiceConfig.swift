//
//  File.swift
//  
//
//  Created by Aashish Patil on 12/5/23.
//

import Foundation

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public enum ServiceRegion: String {
  case USCentral1 = "us-central1"
  case USWest1 = "us-west1"
}

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct ServiceConfig {
  public private(set) var serviceId: String
  public private(set) var location: ServiceRegion
  public private(set) var connector: String
  public private(set) var revision: String

  public init(serviceId: String, location: ServiceRegion,  connector: String, revision: String) {
    self.serviceId = serviceId
    self.location = location
    self.connector = connector
    self.revision = revision

  }

}
