//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/03/2022.
//

import Foundation

public typealias fbt_startListeningBlock = (FQuerySpec, Int?, FSyncTreeHash, @escaping (String) -> [FEvent]) -> [FEvent]

public typealias fbt_stopListeningBlock = (FQuerySpec, Int?) -> Void

public class FListenProvider {
    internal init(startListening: @escaping fbt_startListeningBlock, stopListening: @escaping fbt_stopListeningBlock) {
        self.startListening = startListening
        self.stopListening = stopListening
    }

    public var startListening: fbt_startListeningBlock
    public var stopListening: fbt_stopListeningBlock
}

public typealias fbt_startListeningBlockObjC = (FQuerySpec, NSNumber?, FSyncTreeHash, (String) -> [FEvent]) -> [FEvent]

public typealias fbt_stopListeningBlockObjC = (FQuerySpec, NSNumber?) -> Void

extension FListenProvider {
    convenience init(_ compat: FListenProviderObjC) {
        self.init(startListening: { query, tagId, hash, completion in
            return compat.startListening?(query, tagId.map { NSNumber(value: $0) } , hash, completion) ?? []
        },
                  stopListening:  { query, tagId in
            compat.stopListening?(query, tagId.map { NSNumber(value: $0) })
        })
    }
}

@objc(FListenProvider) public class FListenProviderObjC: NSObject {
    @objc public override init() {
        super.init()
    }

    @objc public var startListening: fbt_startListeningBlockObjC?
    @objc public var stopListening: fbt_stopListeningBlockObjC?
}
