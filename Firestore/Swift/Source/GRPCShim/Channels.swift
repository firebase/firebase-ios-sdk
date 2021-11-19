//
//  ChannelCredentials.swift
//  GRPCSwiftShim
//
//  Created by Hui Wu on 2021-11-15.
//

import Foundation
import GRPC
import NIOSSL

@objc public enum ConnectivityStateShim: Int, RawRepresentable {
  /// This is the state where the channel has not yet been created.
  case idle

  /// The channel is trying to establish a connection and is waiting to make progress on one of the
  /// steps involved in name resolution, TCP connection establishment or TLS handshake.
  case connecting

  /// The channel has successfully established a connection all the way through TLS handshake (or
  /// equivalent) and protocol-level (HTTP/2, etc) handshaking.
  case ready

  /// There has been some transient failure (such as a TCP 3-way handshake timing out or a socket
  /// error). Channels in this state will eventually switch to the `.connecting` state and try to
  /// establish a connection again. Since retries are done with exponential backoff, channels that
  /// fail to connect will start out spending very little time in this state but as the attempts
  /// fail repeatedly, the channel will spend increasingly large amounts of time in this state.
  case transientFailure

  /// This channel has started shutting down. Any new RPCs should fail immediately. Pending RPCs
  /// may continue running till the application cancels them. Channels may enter this state either
  /// because the application explicitly requested a shutdown or if a non-recoverable error has
  /// happened during attempts to connect. Channels that have entered this state will never leave
  /// this state.
  case shutdown
}

@objc public class ClientConnectionShim: NSObject {
  private var connection: ClientConnection
  private init(conn: ClientConnection) {
    connection = conn
  }

  @objc public static func createCustomChannel(host: String,
                                               certiticateBytes: String) -> ClientConnectionShim {
    let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
    let cert = try! NIOSSLCertificate.fromPEMBytes(Array(certiticateBytes.utf8))
    let config = GRPCTLSConfiguration
      .makeClientConfigurationBackedByNIOSSL(certificateChain: cert
        .map(NIOSSLCertificateSource.certificate))
    let builder: ClientConnection.Builder.Secure = ClientConnection.usingTLS(
      with: config,
      on: group
    )
    return ClientConnectionShim(conn: builder.connect(host: host))
  }

  @objc public static func createCustomChannel(host: String) -> ClientConnectionShim {
    let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)

    let builder = ClientConnection.insecure(group: group)
    return ClientConnectionShim(conn: builder.connect(host: host, port: 443))
  }

  @objc public func getConnectionState() -> ConnectivityStateShim {
    switch connection.connectivity.state {
    case .connecting: return ConnectivityStateShim.connecting
    case .idle: return ConnectivityStateShim.idle
    case .ready: return ConnectivityStateShim.ready
    case .shutdown: return ConnectivityStateShim.shutdown
    case .transientFailure: return ConnectivityStateShim.transientFailure
    }
  }

  /*
   @objc public func client() {
       let client = Google_Firestore_V1_FirestoreClient.init(channel: self.connection)
   }*/
}

@objc public class CallOptionsShim: NSObject {
  var options: CallOptions
  private init(ops: CallOptions) {
    options = ops
  }

  @objc public func addMetadata(name: String, value: String) {
    options.customMetadata.add(name: name, value: name)
  }
}
