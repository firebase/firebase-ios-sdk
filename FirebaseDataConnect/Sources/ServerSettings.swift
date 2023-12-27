//
//  File.swift
//  
//
//  Created by Aashish Patil on 12/5/23.
//

import Foundation

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct ServerSettings {

  public private(set) var hostName: String
  public private(set) var port: Int
  public private(set) var sslEnabled: Bool

  static var defaults: ServerSettings {
    return ServerSettings(hostName: "firebasedataconnect.googleapis.com", port: 443, sslEnabled: true)
  }

}
