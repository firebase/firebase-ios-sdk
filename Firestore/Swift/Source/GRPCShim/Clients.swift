//
//  ChannelCredentials.swift
//  GRPCSwiftShim
//
//  Created by Hui Wu on 2021-11-15.
//

import Foundation
import GRPC
import NIOSSL
import NIO

extension ByteBuffer: GRPCPayload {
  public init(serializedByteBuffer: inout ByteBuffer) throws {
    self = serializedByteBuffer
  }

  public func serialize(into buffer: inout ByteBuffer) throws {
    var copy = self
    buffer.writeBuffer(&copy)
  }
}

@objc public class FirestoreClientShim: NSObject {
  private var client: Google_Firestore_V1_FirestoreClient
  private init(conn: ClientConnection) {
      client = Google_Firestore_V1_FirestoreClient.init(channel: conn)
  }

    @objc public func prepareStreamCall(rpcName: String, options: CallOptionsShim) -> BidirectionalStreamingCallShim {
        let call: BidirectionalStreamingCall<ByteBuffer, ByteBuffer> = client.makeBidirectionalStreamingCall(path: rpcName, callOptions: options.options, interceptors: [], handler: {(buffer) in })
        return BidirectionalStreamingCallShim.init(call: call)
   }
    
    @objc public func prepareUnaryCall(rpcName: String, buffer: ByteBufferShim) -> UnaryCallShim {
        let call: UnaryCall<ByteBuffer, ByteBuffer> = client.makeUnaryCall(path: rpcName, request: buffer.buffer)
        return UnaryCallShim.init(call: call)
   }
}

@objc public class BidirectionalStreamingCallShim: NSObject {
    private var call: BidirectionalStreamingCall<ByteBuffer, ByteBuffer>
    init(call: BidirectionalStreamingCall<ByteBuffer, ByteBuffer>) {
        self.call = call
    }
}

@objc public class UnaryCallShim: NSObject {
    private var call: UnaryCall<ByteBuffer, ByteBuffer>
    init(call: UnaryCall<ByteBuffer, ByteBuffer>) {
        self.call = call
    }
}

@objc public class ByteBufferShim: NSObject {
    fileprivate var buffer: ByteBuffer
    init(buf: ByteBuffer) {
        self.buffer = buf
    }
}
