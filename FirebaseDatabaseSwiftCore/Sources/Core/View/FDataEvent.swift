//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public protocol DataSnapshotDummy: NSObjectProtocol {
    var ref: RefDummy { get }
    var value: Any { get }
}
@objc public protocol RefDummy: NSObjectProtocol {
    var parent: RefDummy? { get }
    var path: FPath { get }
}

@objc public class FDataEvent: NSObject, FEvent {
    @objc public let eventRegistration: FEventRegistration
    @objc public let snapshot: DataSnapshotDummy // XXX TODO FIRDataSnapshot
    @objc public let prevName: String?
    @objc public let eventType: DataEventType

    @objc public init(eventType: DataEventType, eventRegistration: FEventRegistration, dataSnapshot: DataSnapshotDummy) {
        self.eventType = eventType
        self.eventRegistration = eventRegistration
        self.snapshot = dataSnapshot
        self.prevName = nil
    }
    @objc public init(eventType: DataEventType, eventRegistration: FEventRegistration, dataSnapshot: DataSnapshotDummy, prevName: String?) {
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
