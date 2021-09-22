//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 21/09/2021.
//

import Foundation

@objc public class FTuplePathValue: NSObject {
    @objc public private(set) var path: FPath
    @objc public private(set) var value: Any

    @objc public init(path: FPath, value: Any) {
        self.path = path
        self.value = value
    }
}
