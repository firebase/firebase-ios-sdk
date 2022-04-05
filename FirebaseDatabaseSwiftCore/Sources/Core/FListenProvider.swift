//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/03/2022.
//

import Foundation

public typealias fbt_startListeningBlock = (FQuerySpec?, NSNumber?, FSyncTreeHash?, (String) -> [FEvent]) -> [FEvent]

public typealias fbt_stopListeningBlock = (FQuerySpec?, NSNumber?) -> Void

@objc public class FListenProvider: NSObject {
    @objc public override init() {
        super.init()
    }

    @objc public var startListening: fbt_startListeningBlock?
    @objc public var stopListening: fbt_stopListeningBlock?
}
