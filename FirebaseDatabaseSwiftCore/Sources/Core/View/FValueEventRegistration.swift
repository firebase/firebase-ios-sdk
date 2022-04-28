//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

class FValueEventRegistration: NSObject, FEventRegistration {
    let repo: FRepo
    let handle: DatabaseHandle
    let callback: ((DataSnapshot) -> Void)?
    let cancelCallback: ((Error) -> Void)?
    init(repo: FRepo, handle: DatabaseHandle, callback: ((DataSnapshot) -> Void)?, cancelCallback: ((Error) -> Void)?) {
        self.repo = repo
        self.handle = handle
        self.callback = callback
        self.cancelCallback = cancelCallback
    }

    func responseTo(_ eventType: DataEventType) -> Bool {
        eventType == .value
    }

    func createEventFrom(_ change: FChange, query: FQuerySpec) -> FDataEvent {
        let ref = DatabaseReference(repo: repo, path: query.path)
        let snapshot = DataSnapshot(ref: ref, indexedNode: change.indexedNode)
        let eventData = FDataEvent(eventType: .value, eventRegistration: self, dataSnapshot: snapshot)
        return eventData
    }

    func fireEvent(_ event: FEvent, queue: DispatchQueue) {
        if let cancelEvent = event as? FCancelEvent {
            FFLog("I-RDB065001", "Raising cancel value event on \(event.path)")
            queue.async {
                self.cancelCallback?(cancelEvent.error)
            }
        } else if let callback = self.callback {
            guard let dataEvent = event as? FDataEvent else { return }
            FFLog("I-RDB065002", "Raising value event on \(dataEvent.snapshot.key)")
            queue.async {
                callback(dataEvent.snapshot)
            }
        }
    }

    func createCancelEventFromError(_ error: Error, path: FPath) -> FCancelEvent? {
        guard let cancelCallback = cancelCallback else {
            return nil
        }
        return FCancelEvent(eventRegistration: self, error: error, path: path)
    }

    // XXX TODO: NSNotFound
    func matches(_ other: FEventRegistration) -> Bool {
        handle == NSNotFound || other.handle == NSNotFound || handle == other.handle
    }
}
