/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FChildEventRegistration.h"
#import "FCancelEvent.h"
#import "FDataEvent.h"
#import "FIRDataSnapshot_Private.h"
#import "FIRDatabaseQuery_Private.h"
#import "FQueryParams.h"
#import "FQuerySpec.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

@interface FChildEventRegistration ()
@property(nonatomic, strong) FRepo *repo;
@property(nonatomic, copy, readwrite) NSDictionary *callbacks;
@property(nonatomic, copy, readwrite) fbt_void_nserror cancelCallback;
@property(nonatomic, readwrite) FIRDatabaseHandle handle;
@end

@implementation FChildEventRegistration

- (id)initWithRepo:(id)repo
            handle:(FIRDatabaseHandle)fHandle
         callbacks:(NSDictionary *)callbackBlocks
    cancelCallback:(fbt_void_nserror)cancelCallbackBlock {
    self = [super init];
    if (self) {
        self.repo = repo;
        self.handle = fHandle;
        self.callbacks = callbackBlocks;
        self.cancelCallback = cancelCallbackBlock;
    }
    return self;
}

- (BOOL)responseTo:(FIRDataEventType)eventType {
    return self.callbacks != nil &&
           [self.callbacks
               objectForKey:[NSNumber numberWithInteger:eventType]] != nil;
}

- (FDataEvent *)createEventFrom:(FChange *)change query:(FQuerySpec *)query {
    FIRDatabaseReference *ref = [[FIRDatabaseReference alloc]
        initWithRepo:self.repo
                path:[query.path childFromString:change.childKey]];
    FIRDataSnapshot *snapshot =
        [[FIRDataSnapshot alloc] initWithRef:ref
                                 indexedNode:change.indexedNode];

    FDataEvent *eventData =
        [[FDataEvent alloc] initWithEventType:change.type
                            eventRegistration:self
                                 dataSnapshot:snapshot
                                     prevName:change.prevKey];
    return eventData;
}

- (void)fireEvent:(id<FEvent>)event queue:(dispatch_queue_t)queue {
    if ([event isCancelEvent]) {
        FCancelEvent *cancelEvent = event;
        FFLog(@"I-RDB061001", @"Raising cancel value event on %@", event.path);
        NSAssert(
            self.cancelCallback != nil,
            @"Raising a cancel event on a listener with no cancel callback");
        dispatch_async(queue, ^{
          self.cancelCallback(cancelEvent.error);
        });
    } else if (self.callbacks != nil) {
        FDataEvent *dataEvent = event;
        FFLog(@"I-RDB061002", @"Raising event callback (%ld) on %@",
              (long)dataEvent.eventType, dataEvent.path);
        fbt_void_datasnapshot_nsstring callback = [self.callbacks
            objectForKey:[NSNumber numberWithInteger:dataEvent.eventType]];

        if (callback != nil) {
            dispatch_async(queue, ^{
              callback(dataEvent.snapshot, dataEvent.prevName);
            });
        }
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
