//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 24/03/2022.
//

import Foundation

@objc public protocol FSyncTreeHash: NSObjectProtocol {
    var simpleHash: String { get }
    var compoundHash: FCompoundHashWrapper { get }
    var includeCompoundHash: Bool { get }
}

// Size after which we start including the compound hash
let kFSizeThresholdForCompoundHash = 1024

@objc public class FListenContainer: NSObject, FSyncTreeHash {
    @objc public var view: FView
    @objc public var onComplete: (String) -> [AnyHashable]

    @objc public init(view: FView, onComplete: @escaping (String) -> [AnyHashable]) {
        self.view = view
        self.onComplete = onComplete
    }

    public var serverCache: FNode {
        view.serverCache
    }

    public var compoundHash: FCompoundHashWrapper {
        FCompoundHashWrapper(wrapped:         FCompoundHash.fromNode(node: serverCache)
)
    }

    public var simpleHash: String {
        serverCache.dataHash()
    }

    public var includeCompoundHash: Bool {
        FSnapshotUtilities.estimateSerializedNodeSize(serverCache) > kFSizeThresholdForCompoundHash
    }
}
