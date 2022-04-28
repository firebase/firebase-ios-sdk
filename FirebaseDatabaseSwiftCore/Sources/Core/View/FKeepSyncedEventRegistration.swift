//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FKeepSyncedEventRegistration: NSObject, FEventRegistration {
    @objc public static var instance: FKeepSyncedEventRegistration = .init()
    public func responseTo(_ eventType: DataEventType) -> Bool {
        false
    }
    public func createEventFrom(_ change: FChange, query: FQuerySpec) -> FDataEvent {
        fatalError("Should never create event for FKeepSyncedEventRegistration")
    }

    public func fireEvent(_ event: FEvent, queue: DispatchQueue) {
        fatalError("Should never raise event for FKeepSyncedEventRegistration")
    }
    public func createCancelEventFromError(_ error: Error, path: FPath) -> FCancelEvent? {
        // Don't create cancel events....
        fatalError()
    }
    public var handle: DatabaseHandle {
        // TODO[offline]: returning arbitray, can't return NSNotFound since that is
        // used to match other event registrations We should really redo this to
        // match on different kind of events (single observer, all observers,
        // cancelled) rather than on a NSNotFound handle...
        NSNotFound - 1
    }

    public func matches(_ other: FEventRegistration) -> Bool {
        // Only matches singleton instance
        self === other
    }
}
