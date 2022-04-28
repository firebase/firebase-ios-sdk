//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 23/04/2022.
//

import Foundation

@objc public class FChildEventRegistration: NSObject, FEventRegistration {
    private let repo: FRepo
    init(repo: FRepo, handle: DatabaseHandle, callbacks: [DataEventType: (DataSnapshot, String?) -> Void], cancelCallback: ((Error) -> Void)?) {
        self.repo = repo
        self.handle = handle
        self.callbacks = callbacks
        self.cancelCallback = cancelCallback
    }
    /**
     * Maps FIRDataEventType (as NSNumber) to fbt_void_datasnapshot_nsstring
     */
    private var callbacks: [DataEventType: (DataSnapshot, String?) -> Void]
    var cancelCallback: ((Error) -> Void)?
    public var handle: DatabaseHandle

    public func responseTo(_ eventType: DataEventType) -> Bool {
        callbacks[eventType] != nil
    }

    public func createEventFrom(_ change: FChange, query: FQuerySpec) -> FDataEvent {
        let ref = DatabaseReference(repo: repo, path: query.path.child(fromString: change.childKey ?? ""))
        let snapshot = DataSnapshot(ref: ref, indexedNode: change.indexedNode)
        let eventData = FDataEvent(eventType: change.type, eventRegistration: self, dataSnapshot: snapshot, prevName: change.prevKey)
        return eventData
    }

    public func fireEvent(_ event: FEvent, queue: DispatchQueue) {
        if let cancelEvent = event as? FCancelEvent {
            FFLog("I-RDB061001", "Raising cancel value event on \(event.path)")
            assert(cancelCallback != nil, "Raising a cancel event on a listener with no cancel callback")
            queue.async {
                self.cancelCallback?(cancelEvent.error)
            }
        } else if let dataEvent = event as? FDataEvent {
            FFLog("I-RDB061002", "Raising event callback (\(dataEvent.eventType)) on \(dataEvent.path)")
            if let callback: (DataSnapshot, String?) -> Void = callbacks[dataEvent.eventType] {
                queue.async {
                    callback(dataEvent.snapshot, dataEvent.prevName)
                }
            }
        }
    }

    public func createCancelEventFromError(_ error: Error, path: FPath) -> FCancelEvent? {
        if let cancelCallback = cancelCallback {
            return FCancelEvent(eventRegistration: self, error: error, path: path)
        } else {
            return nil
        }
    }

    // XXX TODO: NSNotFound is not so nice
    public func matches(_ other: FEventRegistration) -> Bool {
        handle == NSNotFound || other.handle == NSNotFound || handle == other.handle
    }
}

