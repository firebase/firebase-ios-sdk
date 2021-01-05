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

#import "FirebaseDatabase/Sources/Core/View/FEventRaiser.h"
#import "FirebaseDatabase/Sources/Core/FRepo.h"
#import "FirebaseDatabase/Sources/Core/FRepoManager.h"
#import "FirebaseDatabase/Sources/Core/View/FDataEvent.h"
#import "FirebaseDatabase/Sources/Utilities/FTypedefs.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleUserCallback.h"

@interface FEventRaiser ()

@property(nonatomic, strong) dispatch_queue_t queue;

@end

/**
 * This class exists for symmetry with other clients, but since events are
 * async, we don't need to do the complicated stuff the JS client does to
 * preserve event order.
 */
@implementation FEventRaiser

- (id)init {
    [NSException raise:NSInternalInconsistencyException
                format:@"Can't use default constructor"];
    return nil;
}

- (id)initWithQueue:(dispatch_queue_t)queue {
    self = [super init];
    if (self != nil) {
        self->_queue = queue;
    }
    return self;
}

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

@end
