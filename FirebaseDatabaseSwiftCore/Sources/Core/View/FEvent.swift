//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public protocol FEvent: NSObjectProtocol {
    var path: FPath { get }
    func fireEventOnQueue(_ queue: DispatchQueue)
    var isCancelEvent: Bool { get }
    var description: String { get }
}
