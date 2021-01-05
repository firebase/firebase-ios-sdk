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

#import "FirebaseDatabase/Sources/Utilities/FEventEmitter.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Core/FRepoManager.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"

@interface FEventListener : NSObject

@property(nonatomic, copy) fbt_void_id userCallback;
@property(nonatomic) FIRDatabaseHandle handle;

@end

@implementation FEventListener

@synthesize userCallback;
@synthesize handle;

@end

@interface FEventEmitter ()

@property(nonatomic, strong) NSArray *allowedEvents;
@property(nonatomic, strong) NSMutableDictionary *listeners;
@property(nonatomic, strong) dispatch_queue_t queue;

@end

@implementation FEventEmitter

@synthesize allowedEvents;
@synthesize listeners;

- (id)initWithAllowedEvents:(NSArray *)theAllowedEvents
                      queue:(dispatch_queue_t)queue {
    if (theAllowedEvents == nil || [theAllowedEvents count] == 0) {
        @throw [NSException
            exceptionWithName:@"AllowedEventsValidation"
                       reason:@"FEventEmitters must be initialized with at "
                              @"least one valid event."
                     userInfo:nil];
    }

    self = [super init];

    if (self) {
        self.allowedEvents = [theAllowedEvents copy];
        self.listeners = [[NSMutableDictionary alloc] init];
        self.queue = queue;
    }

    return self;
}

- (id)getInitialEventForType:(NSString *)eventType {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"You must override getInitialEvent: "
                                          @"when subclassing FEventEmitter"
                                 userInfo:nil];
}

- (void)triggerEventType:(NSString *)eventType data:(id)data {
    [self validateEventType:eventType];
    NSMutableDictionary *eventTypeListeners =
        [self.listeners objectForKey:eventType];
    for (FEventListener *listener in eventTypeListeners) {
        [self triggerListener:listener withData:data];
    }
}

- (void)triggerListener:(FEventListener *)listener withData:(id)data {
    // TODO, should probably get this from FRepo or something although it ends
    // up being the same. (Except maybe for testing)
    if (listener.userCallback) {
        dispatch_async(self.queue, ^{
          listener.userCallback(data);
        });
    }
}

- (FIRDatabaseHandle)observeEventType:(NSString *)eventType
                            withBlock:(fbt_void_id)block {
    [self validateEventType:eventType];

    // Create listener
    FEventListener *listener = [[FEventListener alloc] init];
    listener.handle = [[FUtilities LUIDGenerator] integerValue];
    listener.userCallback = block; // copies block automatically

    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      [self addEventListener:listener forEventType:eventType];
    });

    return listener.handle;
}

- (void)addEventListener:(FEventListener *)listener
            forEventType:(NSString *)eventType {
    // Get or initializer listeners map [FIRDatabaseHandle -> callback block]
    // for eventType
    NSMutableArray *eventTypeListeners =
        [self.listeners objectForKey:eventType];
    if (eventTypeListeners == nil) {
        eventTypeListeners = [[NSMutableArray alloc] init];
        [self.listeners setObject:eventTypeListeners forKey:eventType];
    }

    // Add listener and fire the current event for this listener
    [eventTypeListeners addObject:listener];
    id initialData = [self getInitialEventForType:eventType];
    [self triggerListener:listener withData:initialData];
}

- (void)removeObserverForEventType:(NSString *)eventType
                        withHandle:(FIRDatabaseHandle)handle {
    [self validateEventType:eventType];

    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      [self removeEventListenerWithHandle:handle forEventType:eventType];
    });
}

- (void)removeEventListenerWithHandle:(FIRDatabaseHandle)handle
                         forEventType:(NSString *)eventType {
    NSMutableArray *eventTypeListeners =
        [self.listeners objectForKey:eventType];
    for (FEventListener *listener in [eventTypeListeners copy]) {
        if (handle == NSNotFound || handle == listener.handle) {
            [eventTypeListeners removeObject:listener];
        }
    }
}

- (void)validateEventType:(NSString *)eventType {
    if ([self.allowedEvents indexOfObject:eventType] == NSNotFound) {
        @throw [NSException
            exceptionWithName:@"InvalidEventType"
                       reason:[NSString stringWithFormat:
                                            @"%@ is not a valid event type. %@ "
                                            @"is the list of valid events.",
                                            eventType, self.allowedEvents]
                     userInfo:nil];
    }
}

@end
