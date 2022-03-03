//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/02/2022.
//

import Foundation

@objc public protocol FCompleteChildSource: NSObjectProtocol {
    func completeChild(_ childKey: String) -> FNode
    func childByIndex(_ index: FIndex, afterChild child: FNamedNode, isReverse: Bool) -> FNamedNode
}
