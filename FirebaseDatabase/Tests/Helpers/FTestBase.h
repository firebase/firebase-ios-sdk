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

#import <XCTest/XCTest.h>
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"
#import "FirebaseDatabase/Tests/Helpers/SenTest+FWaiter.h"

@interface FTestBase : XCTestCase {
  BOOL runPerfTests;
}

- (void)snapWaiter:(FIRDatabaseReference *)path withBlock:(fbt_void_datasnapshot)fn;
- (void)waitUntilConnected:(FIRDatabaseReference *)ref;
- (void)waitForQueue:(FIRDatabaseReference *)ref;
- (void)waitForEvents:(FIRDatabaseReference *)ref;
- (void)waitForRoundTrip:(FIRDatabaseReference *)ref;
- (void)waitForValueOf:(FIRDatabaseQuery *)ref toBe:(id)expected;
- (void)waitForExportValueOf:(FIRDatabaseQuery *)ref toBe:(id)expected;
- (void)waitForCompletionOf:(FIRDatabaseReference *)ref setValue:(id)value;
- (void)waitForCompletionOf:(FIRDatabaseReference *)ref setValue:(id)value andPriority:(id)priority;
- (void)waitForCompletionOf:(FIRDatabaseReference *)ref updateChildValues:(NSDictionary *)values;

@property(nonatomic, readonly) NSString *databaseURL;

@end
