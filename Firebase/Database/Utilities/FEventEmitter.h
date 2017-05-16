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

#import "FIRDatabaseQuery.h"
#import "FIRDatabaseConfig.h"
#import "FTypedefs_Private.h"

@interface FEventEmitter : NSObject

- (id) initWithAllowedEvents:(NSArray *)theAllowedEvents queue:(dispatch_queue_t)queue;

- (id) getInitialEventForType:(NSString *)eventType;
- (void) triggerEventType:(NSString *)eventType data:(id)data;

- (FIRDatabaseHandle)observeEventType:(NSString *)eventType withBlock:(fbt_void_id)block;
- (void) removeObserverForEventType:(NSString *)eventType withHandle:(FIRDatabaseHandle)handle;

- (void) validateEventType:(NSString *)eventType;

@end
