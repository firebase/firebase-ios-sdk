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

#import "FirebaseDatabase/Sources/Core/View/FKeepSyncedEventRegistration.h"

@interface FKeepSyncedEventRegistration ()

@end

@implementation FKeepSyncedEventRegistration

+ (FKeepSyncedEventRegistration *)instance {
    static dispatch_once_t onceToken;
    static FKeepSyncedEventRegistration *keepSynced;
    dispatch_once(&onceToken, ^{
      keepSynced = [[FKeepSyncedEventRegistration alloc] init];
    });
    return keepSynced;
}

- (BOOL)responseTo:(FIRDataEventType)eventType {
    return NO;
}

- (FDataEvent *)createEventFrom:(FChange *)change query:(FQuerySpec *)query {
    [NSException
         raise:NSInternalInconsistencyException
        format:@"Should never create event for FKeepSyncedEventRegistration"];
    return nil;
}

- (void)fireEvent:(id<FEvent>)event queue:(dispatch_queue_t)queue {
    [NSException
         raise:NSInternalInconsistencyException
        format:@"Should never raise event for FKeepSyncedEventRegistration"];
}

- (FCancelEvent *)createCancelEventFromError:(NSError *)error
                                        path:(FPath *)path {
    // Don't create cancel events....
    return nil;
}

- (FIRDatabaseHandle)handle {
    // TODO[offline]: returning arbitrary, can't return NSNotFound since that is
    // used to match other event registrations We should really redo this to
    // match on different kind of events (single observer, all observers,
    // cancelled) rather than on a NSNotFound handle...
    return NSNotFound - 1;
}

- (BOOL)matches:(id<FEventRegistration>)other {
    // Only matches singleton instance
    return self == other;
}

@end
