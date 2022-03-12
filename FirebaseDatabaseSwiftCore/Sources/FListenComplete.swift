//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 12/03/2022.
//

import Foundation

@objc public class FListenComplete: NSObject, FOperation {
    public var source: FOperationSource
    public var path: FPath
    public var type: FOperationType
    @objc public init(source: FOperationSource, path: FPath) {
        assert(!source.fromUser,
                 "Can't have a listen complete from a user source")
        self.source = source
        self.path = path
        self.type = .listenComplete
    }

    public func operationForChild(_ childKey: String) -> FOperation? {
        if path.isEmpty() {
            return FListenComplete(source: source, path: .empty())
        } else {
            return FListenComplete(source: source, path: path.popFront())
        }
    }
    public override var description: String {
        "FListenComplete { path=\(path), source=\(source) }"
    }
}
