//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FOverwrite: NSObject, FOperation {
    public var source: FOperationSource
    public var type: FOperationType
    public var path: FPath
    @objc public let snap: FNode

    @objc public init(source: FOperationSource, path: FPath, snap: FNode) {
        self.source = source
        self.type = .overwrite
        self.path = path
        self.snap = snap
    }
    public func operationForChild(_ childKey: String) -> FOperation? {
        if path.isEmpty {
            return FOverwrite(source: source, path: .empty, snap: snap.getImmediateChild(childKey))
        } else {
            return FOverwrite(source: source, path: path.popFront(), snap: snap)
        }
    }

    public override var description: String {
        "FOverwrite { path=\(path), source=\(source), snapshot=\(snap) }"
    }
}
