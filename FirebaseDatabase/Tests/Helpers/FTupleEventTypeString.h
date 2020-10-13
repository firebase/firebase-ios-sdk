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
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDataEventType.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseReference.h"
#import "FirebaseDatabase/Sources/Utilities/FTypedefs.h"

@interface FTupleEventTypeString : NSObject

- (id)initWithFirebase:(FIRDatabaseReference *)f
             withEvent:(FIRDataEventType)evt
            withString:(NSString *)str;
- (BOOL)isEqualTo:(FTupleEventTypeString *)other;

@property(nonatomic, strong) FIRDatabaseReference *firebase;
@property(readwrite) FIRDataEventType eventType;
@property(nonatomic, strong) NSString *string;
@property(nonatomic, copy) fbt_void_void vvcallback;
@property(nonatomic) BOOL initialized;

@end
