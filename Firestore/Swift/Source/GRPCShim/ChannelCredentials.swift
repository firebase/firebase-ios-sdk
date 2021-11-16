//
//  ChannelCredentials.swift
//  GRPCSwiftShim
//
//  Created by Hui Wu on 2021-11-15.
//

import Foundation
import GRPC

public func createSslCredentials(certiticateBytes: [UInt8]) -> String {
    let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
    let cert = NIOSSLCertificate.fromPEMBytes(certiticateBytes)
    let config = GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL(certificateChain: [NIOSSLCertificateSource.certificate(cert)])
    ClientConnection.usingTLS(with: config, on: group)
}
