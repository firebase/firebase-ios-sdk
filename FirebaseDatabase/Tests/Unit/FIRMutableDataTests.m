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

#import "FirebaseDatabase/Tests/Unit/FIRMutableDataTests.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRMutableData_Private.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"

@implementation FIRMutableDataTests

- (FIRMutableData*)dataFor:(id)input {
  id<FNode> node = [FSnapshotUtilities nodeFrom:input];
  return [[FIRMutableData alloc] initWithNode:node];
}

- (void)testDataForInWorksAlphaPriorities {
  FIRMutableData* data = [self dataFor:@{
    @"a" : @{@".value" : @1, @".priority" : @"first"},
    @"z" : @{@".value" : @26, @".priority" : @"second"},
    @"m" : @{@".value" : @13, @".priority" : @"third"},
    @"n" : @{@".value" : @14, @".priority" : @"fourth"},
    @"c" : @{@".value" : @3, @".priority" : @"fifth"},
    @"b" : @{@".value" : @2, @".priority" : @"sixth"},
    @"e" : @{@".value" : @5, @".priority" : @"seventh"},
  }];

  NSMutableString* output = [[NSMutableString alloc] init];
  NSMutableArray* priorities = [[NSMutableArray alloc] init];
  for (FIRMutableData* child in data.children) {
    [output appendFormat:@"%@:%@:", child.key, child.value];
    [priorities addObject:child.priority];
  }

  XCTAssertTrue([output isEqualToString:@"c:3:a:1:n:14:z:26:e:5:b:2:m:13:"], @"Proper order");
  NSArray* expected = @[ @"fifth", @"first", @"fourth", @"second", @"seventh", @"sixth", @"third" ];
  XCTAssertTrue([priorities isEqualToArray:expected], @"Correct priorities");
  XCTAssertTrue(data.childrenCount == 7, @"Got correct children count");
}

- (void)testWritingMutableData {
  FIRMutableData* data = [self dataFor:@{}];

  data.value = @{@"a" : @1, @"b" : @2};
  XCTAssertTrue([data hasChildren], @"Should have children node");
  XCTAssertTrue(data.childrenCount == 2, @"Counts both children");
  XCTAssertTrue([data hasChildAtPath:@"a"], @"Can see the children individually");

  FIRMutableData* childData = [data childDataByAppendingPath:@"b"];
  XCTAssertTrue([childData.value isEqualToNumber:@2], @"Get the correct child data");
  childData.value = @3;

  NSDictionary* expected = @{@"a" : @1, @"b" : @3};
  XCTAssertTrue([data.value isEqualToDictionary:expected], @"Updates the parent");

  int count = 0;
  for (FIRDataSnapshot* __unused child in data.children) {
    count++;
    if (count == 1) {
      [data childDataByAppendingPath:@"c"].value = @4;
    }
  }
  XCTAssertTrue(count == 2, @"Should not iterate nodes added while iterating");
  XCTAssertTrue(data.childrenCount == 3, @"Got the new node we added while iterating");
  XCTAssertTrue([[data childDataByAppendingPath:@"c"].value isEqualToNumber:@4],
                @"Can see the value of the new node");
}

- (void)testMutableDataNavigation {
  FIRMutableData* data = [self dataFor:@{@"a" : @1, @"b" : @2}];

  XCTAssertNil(data.key, @"Root data has no key");

  // Can get a child
  FIRMutableData* childData = [data childDataByAppendingPath:@"b"];
  XCTAssertTrue([childData.key isEqualToString:@"b"], @"Child has correct key");

  // Can get a non-existent child
  childData = [data childDataByAppendingPath:@"c"];
  XCTAssertTrue(childData != nil, @"Wrapper should not be nil");
  XCTAssertTrue([childData.key isEqualToString:@"c"], @"Child should have correct key");
  XCTAssertTrue(childData.value == [NSNull null], @"Non-existent data has no value");
  childData.value = @{@"d" : @4};

  NSDictionary* expected = @{@"a" : @1, @"b" : @2, @"c" : @{@"d" : @4}};
  XCTAssertTrue([data.value isEqualToDictionary:expected],
                @"Setting non-existent child updates parent");
}

- (void)testPriorities {
  FIRMutableData* data = [self dataFor:@{@"a" : @1, @"b" : @2}];

  XCTAssertTrue(data.priority == [NSNull null], @"Should not be a priority");
  data.priority = @"foo";
  XCTAssertTrue([data.priority isEqualToString:@"foo"], @"Should now have a priority");
  data.value = @3;
  XCTAssertTrue(data.priority == [NSNull null], @"Setting a value overrides a priority");
  data.priority = @4;
  data.value = nil;
  XCTAssertTrue(data.priority == [NSNull null], @"Removing the value does remove the priority");
}

@end
