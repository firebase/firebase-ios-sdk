//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public enum FOperationType: Int {
    @objc(FOperationTypeOverwrite) case overwrite = 0
    @objc(FOperationTypeMerge) case merge = 1
    @objc(FOperationTypeAckUserWrite) case ackUserWrite = 2
    @objc(FOperationTypeListenComplete) case listenComplete = 3
}

@objc public protocol FOperation: NSObjectProtocol {
    var source: FOperationSource { get }
    var type: FOperationType { get }
    var path: FPath { get }
    func operationForChild(_ childKey: String) -> FOperation?
}
