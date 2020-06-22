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

#import "FirebaseDatabase/Sources/Core/View/FEvent.h"
#import "FirebaseDatabase/Sources/Public/FIRDataSnapshot.h"
#import "FirebaseDatabase/Sources/Public/FIRDatabaseReference.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleUserCallback.h"
#import <Foundation/Foundation.h>

@protocol FEventRegistration;
@protocol FIndex;

@interface FDataEvent : NSObject <FEvent>

- initWithEventType:(FIRDataEventType)type
    eventRegistration:(id<FEventRegistration>)eventRegistration
         dataSnapshot:(FIRDataSnapshot *)dataSnapshot;
- initWithEventType:(FIRDataEventType)type
    eventRegistration:(id<FEventRegistration>)eventRegistration
         dataSnapshot:(FIRDataSnapshot *)snapshot
             prevName:(NSString *)prevName;

@property(nonatomic, strong, readonly) id<FEventRegistration> eventRegistration;
@property(nonatomic, strong, readonly) FIRDataSnapshot *snapshot;
@property(nonatomic, strong, readonly) NSString *prevName;
@property(nonatomic, readonly) FIRDataEventType eventType;

@end
