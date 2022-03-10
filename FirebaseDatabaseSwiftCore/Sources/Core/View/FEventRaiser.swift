//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FEventRaiser: NSObject {
    @objc public let queue: DispatchQueue
    @objc public init(queue: DispatchQueue) {
        self.queue = queue
    }
    @objc public func raiseEvents(_ eventDataList: [FEvent]) {
        for event in eventDataList {
            event.fireEventOnQueue(queue)
        }
    }

    @objc public func raiseCallback(_ callback: @escaping () -> Void) {
        queue.async {
            callback()
        }
    }

    // XXX TODO: Can't be converted to Obj-C, so we move the iteration to the callsite
    // until ported

    public func raiseCallbacks(_ callbackList: [() -> Void]) {
        for callback in callbackList {
            queue.async {
                callback()
            }
        }
    }
}

/*
 - (void)raiseEvents:(NSArray *)eventDataList {
     for (id<FEvent> event in eventDataList) {
         [event fireEventOnQueue:self.queue];
     }
 }

 - (void)raiseCallback:(fbt_void_void)callback {
     dispatch_async(self.queue, callback);
 }

 - (void)raiseCallbacks:(NSArray *)callbackList {
     for (fbt_void_void callback in callbackList) {
         dispatch_async(self.queue, callback);
     }
 }

 + (void)raiseCallbacks:(NSArray *)callbackList queue:(dispatch_queue_t)queue {
     for (fbt_void_void callback in callbackList) {
         dispatch_async(queue, callback);
     }
 }

 */
