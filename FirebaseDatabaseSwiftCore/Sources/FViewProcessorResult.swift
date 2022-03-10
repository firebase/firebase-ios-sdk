//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FViewProcessorResult: NSObject {
    @objc public let viewCache: FViewCache
    /**
     * List of FChanges.
     */
    @objc public let changes: [FChange]

    @objc public init(viewCache: FViewCache, changes: [FChange]) {
        self.viewCache = viewCache
        self.changes = changes
    }
}
/*
 */
