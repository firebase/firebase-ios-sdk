//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

public typealias FIRDatabaseHandle = Int

@objc public protocol FEventRegistration: NSObjectProtocol {
    func responseTo(_ eventType: DataEventType) -> Bool
    func createEventFrom(_ change: FChange, query: FQuerySpec) -> FDataEvent
    func fireEvent(_ event: FEvent, queue: DispatchQueue)
    func createCancelEventFromError(_ error: Error, path: FPath) -> FCancelEvent
    /**
     * Used to figure out what event registration match the event registration that
     * needs to be removed.
     */
    func matches(_ other: FEventRegistration) -> Bool
    var handle: FIRDatabaseHandle { get }
}
