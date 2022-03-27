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
