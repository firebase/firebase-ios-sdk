//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

@objc(FIRAuthProto) public protocol AuthProto: NSObjectProtocol {
    @objc init(dictionary: [String: Any])
    @objc optional var dictionary: [String: Any] { get }
}
