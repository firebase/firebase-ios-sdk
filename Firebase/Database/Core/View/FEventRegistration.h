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

#import <Foundation/Foundation.h>
#import "FChange.h"
#import "FIRDataEventType.h"

@protocol FEvent;
@class FDataEvent;
@class FCancelEvent;
@class FQuerySpec;

@protocol FEventRegistration <NSObject>
- (BOOL) responseTo:(FIRDataEventType)eventType;
- (FDataEvent *) createEventFrom:(FChange *)change query:(FQuerySpec *)query;
- (void) fireEvent:(id<FEvent>)event queue:(dispatch_queue_t)queue;
- (FCancelEvent *) createCancelEventFromError:(NSError *)error path:(FPath *)path;
/**
* Used to figure out what event registration match the event registration that needs to be removed.
*/
- (BOOL) matches:(id<FEventRegistration>)other;
@property (nonatomic, readonly) FIRDatabaseHandle handle;
@end
