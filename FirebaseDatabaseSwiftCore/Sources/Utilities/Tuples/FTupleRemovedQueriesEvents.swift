//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 24/03/2022.
//

import Foundation

@objc public class FTupleRemovedQueriesEvents: NSObject {
    /**
     * `FQuerySpec`s removed with [SyncPoint removeEventRegistration:]
     */
    @objc public let removedQueries: [FQuerySpec]
    /**
     * cancel events as FEvent
     */
    @objc public let cancelEvents: [FEvent]
    @objc public init(removedQueries: [FQuerySpec], cancelEvents: [FEvent]) {
        self.removedQueries = removedQueries
        self.cancelEvents = cancelEvents
    }
}
