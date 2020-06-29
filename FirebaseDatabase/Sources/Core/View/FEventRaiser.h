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

#import "FirebaseDatabase/Sources/Utilities/FTypedefs.h"

@class FPath;
@class FRepo;
@class FIRDatabaseConfig;

/**
 * Left as instance methods rather than class methods so that we could
 * potentially callback on different queues for different repos. This is
 * semi-parallel to JS's FEventQueue
 */
@interface FEventRaiser : NSObject

- (id)initWithQueue:(dispatch_queue_t)queue;

- (void)raiseEvents:(NSArray *)eventDataList;
- (void)raiseCallback:(fbt_void_void)callback;
- (void)raiseCallbacks:(NSArray *)callbackList;

@end
