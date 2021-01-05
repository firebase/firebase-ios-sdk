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

#import "FirebaseDatabase/Sources/Core/View/FDataEvent.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Core/View/FEventRegistration.h"
#import "FirebaseDatabase/Sources/FIndex.h"

@interface FDataEvent ()
@property(nonatomic, strong, readwrite) id<FEventRegistration>
    eventRegistration;
@property(nonatomic, strong, readwrite) FIRDataSnapshot *snapshot;
@property(nonatomic, strong, readwrite) NSString *prevName;
@property(nonatomic, readwrite) FIRDataEventType eventType;
@end

@implementation FDataEvent

@synthesize eventRegistration;
@synthesize snapshot;
@synthesize prevName;
@synthesize eventType;

- (id)initWithEventType:(FIRDataEventType)type
      eventRegistration:(id<FEventRegistration>)registration
           dataSnapshot:(FIRDataSnapshot *)dataSnapshot {
    return [self initWithEventType:type
                 eventRegistration:registration
                      dataSnapshot:dataSnapshot
                          prevName:nil];
}

- (id)initWithEventType:(FIRDataEventType)type
      eventRegistration:(id<FEventRegistration>)registration
           dataSnapshot:(FIRDataSnapshot *)dataSnapshot
               prevName:(NSString *)previousName {
    self = [super init];
    if (self) {
        self.eventRegistration = registration;
        self.snapshot = dataSnapshot;
        self.prevName = previousName;
        self.eventType = type;
    }
    return self;
}

- (FPath *)path {
    // Used for logging, so delay calculation
    FIRDatabaseReference *ref = self.snapshot.ref;
    if (self.eventType == FIRDataEventTypeValue) {
        return ref.path;
    } else {
        return ref.parent.path;
    }
}

- (void)fireEventOnQueue:(dispatch_queue_t)queue {
    [self.eventRegistration fireEvent:self queue:queue];
}

- (BOOL)isCancelEvent {
    return NO;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"event %d, data: %@", (int)eventType,
                                      [snapshot value]];
}

@end
