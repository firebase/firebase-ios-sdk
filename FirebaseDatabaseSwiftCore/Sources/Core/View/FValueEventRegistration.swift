//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

// NOTE: TOO SOON, REQUIRES FREPO...

//@objc public class FValueEventRegistration: NSObject, FEventRegistration {
//
//}
/*

 @import FirebaseDatabaseSwiftCore;

 @interface FValueEventRegistration ()
 @property(nonatomic, strong) FRepo *repo;
 @property(nonatomic, copy, readwrite) fbt_void_datasnapshot callback;
 @property(nonatomic, copy, readwrite) fbt_void_nserror cancelCallback;
 @property(nonatomic, readwrite) FIRDatabaseHandle handle;
 @end

 @implementation FValueEventRegistration

 - (id)initWithRepo:(FRepo *)repo
             handle:(FIRDatabaseHandle)fHandle
           callback:(fbt_void_datasnapshot)callbackBlock
     cancelCallback:(fbt_void_nserror)cancelCallbackBlock {
     self = [super init];
     if (self) {
         self.repo = repo;
         self.handle = fHandle;
         self.callback = callbackBlock;
         self.cancelCallback = cancelCallbackBlock;
     }
     return self;
 }

 - (BOOL)responseTo:(FIRDataEventType)eventType {
     return eventType == FIRDataEventTypeValue;
 }

 - (FDataEvent *)createEventFrom:(FChange *)change query:(FQuerySpec *)query {
     FIRDatabaseReference *ref =
         [[FIRDatabaseReference alloc] initWithRepo:self.repo path:query.path];
     FIRDataSnapshot *snapshot =
         [[FIRDataSnapshot alloc] initWithRef:ref
                                  indexedNode:change.indexedNode];
     FDataEvent *eventData =
         [[FDataEvent alloc] initWithEventType:FIRDataEventTypeValue
                             eventRegistration:self
                                  dataSnapshot:snapshot];
     return eventData;
 }

 - (void)fireEvent:(id<FEvent>)event queue:(dispatch_queue_t)queue {
     if ([event isCancelEvent]) {
         FCancelEvent *cancelEvent = event;
         FFLog(@"I-RDB065001", @"Raising cancel value event on %@", event.path);
         NSAssert(
             self.cancelCallback != nil,
             @"Raising a cancel event on a listener with no cancel callback");
         dispatch_async(queue, ^{
           self.cancelCallback(cancelEvent.error);
         });
     } else if (self.callback != nil) {
         FDataEvent *dataEvent = event;
         FFLog(@"I-RDB065002", @"Raising value event on %@",
               ((FIRDataSnapshot *)(dataEvent.snapshot)).key);
         dispatch_async(queue, ^{
           self.callback(dataEvent.snapshot);
         });
     }
 }

 - (FCancelEvent *)createCancelEventFromError:(NSError *)error
                                         path:(FPath *)path {
     if (self.cancelCallback != nil) {
         return [[FCancelEvent alloc] initWithEventRegistration:self
                                                          error:error
                                                           path:path];
     } else {
         return nil;
     }
 }

 - (BOOL)matches:(id<FEventRegistration>)other {
     return self.handle == NSNotFound || other.handle == NSNotFound ||
            self.handle == other.handle;
 }

 @end

 */
