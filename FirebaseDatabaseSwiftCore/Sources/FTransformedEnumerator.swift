//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 12/03/2022.
//

import Foundation

@objc public class FTransformedEnumerator: NSEnumerator {
    let enumerator: NSEnumerator
    let transform: (Any) -> Any
    @objc public init(enumerator: NSEnumerator, andTransform transform: @escaping (Any) -> Any) {
        self.enumerator = enumerator
        self.transform = transform
    }

    @objc public override func nextObject() -> Any? {
        guard let next = enumerator.nextObject() else { return nil }
        return transform(next)
    }
}
