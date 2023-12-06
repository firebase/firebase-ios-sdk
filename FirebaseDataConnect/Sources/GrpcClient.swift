//
//  File.swift
//  
//
//  Created by Aashish Patil on 12/5/23.
//

import Foundation

import GRPC
import NIOCore
import NIOPosix
import SwiftProtobuf


@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
class GrpcClient {

  private let threadPoolSize = 1

  var serverSettings: ServerSettings

  lazy var client: Google_Firebase_Dataconnect_V1main_DataServiceAsyncClient? = {
    do {
      let group = PlatformSupport.makeEventLoopGroup(loopCount: threadPoolSize)
      let channel = try GRPCChannelPool.with(target: .host(serverSettings.hostName, port: serverSettings.port), transportSecurity: serverSettings.sslEnabled ? .tls(GRPCTLSConfiguration.makeClientDefault(compatibleWith: group)) : .plaintext , eventLoopGroup: group)
      return Google_Firebase_Dataconnect_V1main_DataServiceAsyncClient(channel: channel)

    } catch {
      //TODO: Convert to using logger
      print("Error initing GRPC client \(error)")
      return nil
    }
  } ()

  init(serverSettings: ServerSettings) {
    self.serverSettings = serverSettings
  }

}
