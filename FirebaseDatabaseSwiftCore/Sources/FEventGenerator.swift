//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 11/03/2022.
//

import Foundation

@objc public class FEventGenerator: NSObject {
    let query: FQuerySpec
    @objc public init(query: FQuerySpec) {
        self.query = query
    }

    /**
     * Given a set of raw changes (no moved events, and prevName not specified yet),
     * and a set of EventRegistrations that should be notified of these changes,
     * generate the actual events to be raised.
     *
     * Notes:
     * - child_moved events will be synthesized at this time for any child_changed
     * events that affect our index
     * - prevName will be calculated based on the index ordering
     *
     * @param changes NSArray of FChange, not necessarily in order.
     * @param registrations is NSArray of FEventRegistration.
     * @return NSArray of FEvent.
     */
    public func generateEventsForChanges(_ changes: [FChange],
                                          eventCache: FIndexedNode,
                                          eventRegistrations: [FEventRegistration]) -> [FEvent] {
        var events: [FEvent] = []
        // child_moved is index-specific, so check all our child_changed events to
        // see if we need to materialize child_moved events with this view's index
        var moves: [FChange] = []
        for change in changes {
            if change.type == .childChanged &&
/* XXX TODO AAARGH, YET ANOTHER FORCE UNWRAP I CAN'T EXPLAIN */
                query.index.indexedValueChangedBetween(change.oldIndexedNode!.node, and: change.indexedNode.node) {
                let moveChange = FChange(type: .childMoved,
                                         indexedNode: change.indexedNode,
                                         childKey: change.childKey,
                                         oldIndexedNode: nil)
                moves.append(moveChange)
            }
        }
        generateEvents(&events,
                       forType: .childRemoved,
                       changes: changes,
                       eventCache: eventCache,
                       eventRegistrations: eventRegistrations)
        generateEvents(&events,
                       forType: .childAdded,
                       changes: changes,
                       eventCache: eventCache,
                       eventRegistrations: eventRegistrations)
        generateEvents(&events,
                       forType: .childMoved,
                       changes: moves,
                       eventCache: eventCache,
                       eventRegistrations: eventRegistrations)
        generateEvents(&events,
                       forType: .childChanged,
                       changes: changes,
                       eventCache: eventCache,
                       eventRegistrations: eventRegistrations)
        generateEvents(&events,
                       forType: .value,
                       changes: changes,
                       eventCache: eventCache,
                       eventRegistrations: eventRegistrations)
        return events
    }

    private func generateEvents(_ events: inout [FEvent],
                                forType eventType: DataEventType,
                                changes: [FChange],
                                eventCache: FIndexedNode,
                                eventRegistrations: [FEventRegistration]) {
        var filteredChanges = changes.filter { $0.type == eventType }
        let index = query.index
        filteredChanges.sort { one, two in
            guard let childKeyOne = one.childKey, let childKeyTwo = two.childKey else {
                fatalError("Should only compare child_ events")
            }
            return index.compareKey(childKeyOne, andNode: one.indexedNode.node, toOtherKey: childKeyTwo, andNode: two.indexedNode.node) == .orderedAscending
        }
        for change in filteredChanges {
            for registration in eventRegistrations {
                if registration.responseTo(eventType) {
                    let event = generateEventForChange(change, registration: registration, eventCache: eventCache)
                    events.append(event)
                }
            }
        }
    }

    private func generateEventForChange(_ change: FChange, registration: FEventRegistration, eventCache: FIndexedNode) -> FEvent {
        let materializedChange: FChange
        if change.type == .value || change.type == .childRemoved {
            materializedChange = change
        } else {
            /// XXX TODO: FORCE UNWRAP. MUST A CHILD ADDED OR CHANGED ALWAYS HAVE A CHILD KEY?
            let prevChildKey = eventCache.predecessorForChildKey(change.childKey!, childNode: change.indexedNode.node, index: query.index)
            materializedChange = change.change(prevKey: prevChildKey)
        }
        return registration.createEventFrom(materializedChange, query: query)
    }
}
