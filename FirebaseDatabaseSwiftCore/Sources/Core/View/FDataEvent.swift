//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FDataEvent: NSObject, FEvent {
    @objc public let eventRegistration: FEventRegistration
    @objc public let snapshot: DataSnapshot
    @objc public let prevName: String?
    @objc public let eventType: DataEventType

    @objc public init(eventType: DataEventType, eventRegistration: FEventRegistration, dataSnapshot: DataSnapshot) {
        self.eventType = eventType
        self.eventRegistration = eventRegistration
        self.snapshot = dataSnapshot
        self.prevName = nil
    }
    @objc public init(eventType: DataEventType, eventRegistration: FEventRegistration, dataSnapshot: DataSnapshot, prevName: String?) {
        self.eventType = eventType
        self.eventRegistration = eventRegistration
        self.snapshot = dataSnapshot
        self.prevName = prevName
    }

    public var path: FPath {
        // Used for logging, so delay calculation
        let ref = self.snapshot.ref;
        if (eventType == .value) {
            return ref.path
        } else {
            return ref.parent!.path // XXX TODO FORCE UNWRAP?
        }
    }

    public func fireEventOnQueue(_ queue: DispatchQueue) {
        eventRegistration.fireEvent(self, queue: queue)
    }
    public var isCancelEvent: Bool { false }

    public override var description: String {
        "event \(eventType), data: \(snapshot.value)"
    }
}
