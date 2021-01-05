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
#import <XCTest/XCTest.h>

#import "FirebaseDatabase/Sources/Snapshot/FChildrenNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FLeafNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"

@interface FNodeTests : XCTestCase

@end

@implementation FNodeTests

- (void)testLeafNodeEqualsHashCode {
  id<FNode> falseNode = [FSnapshotUtilities nodeFrom:@NO];
  id<FNode> trueNode = [FSnapshotUtilities nodeFrom:@YES];
  id<FNode> stringOneNode = [FSnapshotUtilities nodeFrom:@"one"];
  id<FNode> stringTwoNode = [FSnapshotUtilities nodeFrom:@"two"];
  id<FNode> zeroNode = [FSnapshotUtilities nodeFrom:@0];
  id<FNode> oneNode = [FSnapshotUtilities nodeFrom:@1];
  id<FNode> emptyNode1 = [FSnapshotUtilities nodeFrom:nil];
  id<FNode> emptyNode2 = [FSnapshotUtilities nodeFrom:[NSNull null]];

  XCTAssertEqualObjects(falseNode, [FSnapshotUtilities nodeFrom:@NO]);
  XCTAssertEqual(falseNode.hash, [FSnapshotUtilities nodeFrom:@NO].hash);
  XCTAssertEqualObjects(trueNode, [FSnapshotUtilities nodeFrom:@YES]);
  XCTAssertEqual(trueNode.hash, [FSnapshotUtilities nodeFrom:@YES].hash);
  XCTAssertFalse([falseNode isEqual:trueNode]);
  XCTAssertFalse([falseNode isEqual:oneNode]);
  XCTAssertFalse([falseNode isEqual:stringOneNode]);
  XCTAssertFalse([falseNode isEqual:emptyNode1]);

  XCTAssertEqualObjects(stringOneNode, [FSnapshotUtilities nodeFrom:@"one"]);
  XCTAssertEqual(stringOneNode.hash, [FSnapshotUtilities nodeFrom:@"one"].hash);
  XCTAssertFalse([stringOneNode isEqual:stringTwoNode]);
  XCTAssertFalse([stringOneNode isEqual:emptyNode1]);
  XCTAssertFalse([stringOneNode isEqual:oneNode]);
  XCTAssertFalse([stringOneNode isEqual:trueNode]);

  XCTAssertEqualObjects(zeroNode, [FSnapshotUtilities nodeFrom:@0]);
  XCTAssertEqual(zeroNode.hash, [FSnapshotUtilities nodeFrom:@0].hash);
  XCTAssertFalse([zeroNode isEqual:oneNode]);
  XCTAssertFalse([zeroNode isEqual:emptyNode1]);
  XCTAssertFalse([zeroNode isEqual:falseNode]);

  XCTAssertEqualObjects(emptyNode1, emptyNode2);
  XCTAssertEqual(emptyNode1.hash, emptyNode2.hash);
}

- (void)testLeafNodePrioritiesEqualsHashCode {
  id<FNode> oneOne = [FSnapshotUtilities nodeFrom:@1 priority:@1];
  id<FNode> stringOne = [FSnapshotUtilities nodeFrom:@"value" priority:@1];
  id<FNode> oneString = [FSnapshotUtilities nodeFrom:@1 priority:@"value"];
  id<FNode> stringString = [FSnapshotUtilities nodeFrom:@"value" priority:@"value"];

  XCTAssertEqualObjects(oneOne, [FSnapshotUtilities nodeFrom:@1 priority:@1]);
  XCTAssertEqual(oneOne.hash, [FSnapshotUtilities nodeFrom:@1 priority:@1].hash);
  XCTAssertFalse([oneOne isEqual:stringOne]);
  XCTAssertFalse([oneOne isEqual:oneString]);
  XCTAssertFalse([oneOne isEqual:stringString]);

  XCTAssertEqualObjects(stringOne, [FSnapshotUtilities nodeFrom:@"value" priority:@1]);
  XCTAssertEqual(stringOne.hash, [FSnapshotUtilities nodeFrom:@"value" priority:@1].hash);
  XCTAssertFalse([stringOne isEqual:oneOne]);
  XCTAssertFalse([stringOne isEqual:oneString]);
  XCTAssertFalse([stringOne isEqual:stringString]);

  XCTAssertEqualObjects(oneString, [FSnapshotUtilities nodeFrom:@1 priority:@"value"]);
  XCTAssertEqual(oneString.hash, [FSnapshotUtilities nodeFrom:@1 priority:@"value"].hash);
  XCTAssertFalse([oneString isEqual:stringOne]);
  XCTAssertFalse([oneString isEqual:oneOne]);
  XCTAssertFalse([oneString isEqual:stringString]);

  XCTAssertEqualObjects(stringString, [FSnapshotUtilities nodeFrom:@"value" priority:@"value"]);
  XCTAssertEqual(stringString.hash, [FSnapshotUtilities nodeFrom:@"value" priority:@"value"].hash);
  XCTAssertFalse([stringString isEqual:stringOne]);
  XCTAssertFalse([stringString isEqual:oneString]);
  XCTAssertFalse([stringString isEqual:oneOne]);
}

- (void)testChildrenNodeEqualsHashCode {
  id<FNode> nodeOne =
      [FSnapshotUtilities nodeFrom:@{@"one" : @1, @"two" : @2, @".priority" : @"prio"}];
  id<FNode> nodeTwo =
      [[FEmptyNode emptyNode] updateImmediateChild:@"one"
                                      withNewChild:[FSnapshotUtilities nodeFrom:@1]];
  nodeTwo = [nodeTwo updateImmediateChild:@"two" withNewChild:[FSnapshotUtilities nodeFrom:@2]];
  nodeTwo = [nodeTwo updatePriority:[FSnapshotUtilities nodeFrom:@"prio"]];

  XCTAssertEqualObjects(nodeOne, nodeTwo);
  XCTAssertEqual(nodeOne.hash, nodeTwo.hash);
  XCTAssertFalse([[nodeOne updatePriority:[FEmptyNode emptyNode]] isEqual:nodeOne]);
  XCTAssertFalse([[nodeOne updateImmediateChild:@"one"
                                   withNewChild:[FEmptyNode emptyNode]] isEqual:nodeOne]);
  XCTAssertFalse([[nodeOne updateImmediateChild:@"one"
                                   withNewChild:[FSnapshotUtilities nodeFrom:@2]] isEqual:nodeOne]);
}

- (void)testLeadingZerosWorkCorrectly {
  NSDictionary *data = @{@"1" : @1, @"01" : @2, @"001" : @3, @"0001" : @4};

  id<FNode> node = [FSnapshotUtilities nodeFrom:data];
  XCTAssertEqualObjects([node getImmediateChild:@"1"].val, @1);
  XCTAssertEqualObjects([node getImmediateChild:@"01"].val, @2);
  XCTAssertEqualObjects([node getImmediateChild:@"001"].val, @3);
  XCTAssertEqualObjects([node getImmediateChild:@"0001"].val, @4);
}

- (void)testLeadindZerosArePreservedInValue {
  NSDictionary *data = @{@"1" : @1, @"01" : @2, @"001" : @3, @"0001" : @4};

  XCTAssertEqualObjects([FSnapshotUtilities nodeFrom:data].val, data);
}

- (void)testEmptyNodeEqualsEmptyChildrenNode {
  XCTAssertEqualObjects([FEmptyNode emptyNode], [[FChildrenNode alloc] init]);
  XCTAssertEqualObjects([[FChildrenNode alloc] init], [FEmptyNode emptyNode]);
  XCTAssertEqual([[FChildrenNode alloc] init].hash, [FEmptyNode emptyNode].hash);
}

- (void)testUpdatingEmptyChildrenDoesntOverwriteLeafNode {
  FLeafNode *node = [[FLeafNode alloc] initWithValue:@"value"];
  XCTAssertEqualObjects(node, [node updateChild:[FPath pathWithString:@".priority"]
                                   withNewChild:[FEmptyNode emptyNode]]);
  XCTAssertEqualObjects(node, [node updateChild:[FPath pathWithString:@"child"]
                                   withNewChild:[FEmptyNode emptyNode]]);
  XCTAssertEqualObjects(node, [node updateChild:[FPath pathWithString:@"child/.priority"]
                                   withNewChild:[FEmptyNode emptyNode]]);
  XCTAssertEqualObjects(node, [node updateImmediateChild:@"child"
                                            withNewChild:[FEmptyNode emptyNode]]);
  XCTAssertEqualObjects(node, [node updateImmediateChild:@".priority"
                                            withNewChild:[FEmptyNode emptyNode]]);
}

- (void)testUpdatingPrioritiesOnEmptyNodesIsANoOp {
  id<FNode> priority = [FSnapshotUtilities nodeFrom:@"prio"];
  XCTAssertTrue([[[[FEmptyNode emptyNode] updatePriority:priority] getPriority] isEmpty]);
  XCTAssertTrue([[[[FEmptyNode emptyNode] updateChild:[FPath pathWithString:@".priority"]
                                         withNewChild:priority] getPriority] isEmpty]);
  XCTAssertTrue([[[[FEmptyNode emptyNode] updateImmediateChild:@".priority"
                                                  withNewChild:priority] getPriority] isEmpty]);

  id<FNode> valueNode = [FSnapshotUtilities nodeFrom:@"value"];
  FPath *childPath = [FPath pathWithString:@"child"];
  id<FNode> reemptiedChildren = [[[FEmptyNode emptyNode]
       updateChild:childPath
      withNewChild:valueNode] updateChild:childPath withNewChild:[FEmptyNode emptyNode]];
  XCTAssertTrue([[[reemptiedChildren updatePriority:priority] getPriority] isEmpty]);
  XCTAssertTrue([[[reemptiedChildren updateChild:[FPath pathWithString:@".priority"]
                                    withNewChild:priority] getPriority] isEmpty]);
  XCTAssertTrue([[[reemptiedChildren updateImmediateChild:@".priority"
                                             withNewChild:priority] getPriority] isEmpty]);
}

- (void)testDeletingLastChildFromChildrenNodeRemovesPriority {
  id<FNode> priority = [FSnapshotUtilities nodeFrom:@"prio"];
  id<FNode> valueNode = [FSnapshotUtilities nodeFrom:@"value"];
  FPath *childPath = [FPath pathWithString:@"child"];
  id<FNode> withPriority = [[[FEmptyNode emptyNode] updateChild:childPath
                                                   withNewChild:valueNode] updatePriority:priority];
  XCTAssertEqualObjects(priority, [withPriority getPriority]);
  id<FNode> deletedChild = [withPriority updateChild:childPath withNewChild:[FEmptyNode emptyNode]];
  XCTAssertTrue([[deletedChild getPriority] isEmpty]);
}

- (void)testFromNodeReturnsEmptyNodesWithoutPriority {
  id<FNode> empty1 = [FSnapshotUtilities nodeFrom:@{@".priority" : @"prio"}];
  XCTAssertTrue([[empty1 getPriority] isEmpty]);

  id<FNode> empty2 =
      [FSnapshotUtilities nodeFrom:@{@"dummy" : [NSNull null], @".priority" : @"prio"}];
  XCTAssertTrue([[empty2 getPriority] isEmpty]);
}

@end
