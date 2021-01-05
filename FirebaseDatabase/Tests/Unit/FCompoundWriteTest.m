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
#import "FirebaseDatabase/Sources/FNamedNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FCompoundWrite.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FLeafNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"

@interface FCompoundWriteTest : XCTestCase

@end

@implementation FCompoundWriteTest

- (id<FNode>)leafNode {
  static id<FNode> node = nil;
  if (!node) {
    node = [FSnapshotUtilities nodeFrom:@"leaf-node"];
  }
  return node;
}

- (id<FNode>)priorityNode {
  static id<FNode> node = nil;
  if (!node) {
    node = [FSnapshotUtilities nodeFrom:@"prio"];
  }
  return node;
}

- (id<FNode>)baseNode {
  static id<FNode> node = nil;
  if (!node) {
    NSDictionary *base = @{@"child-1" : @"value-1", @"child-2" : @"value-2"};
    node = [FSnapshotUtilities nodeFrom:base];
  }
  return node;
}

- (void)assertAppliedCompoundWrite:(FCompoundWrite *)compoundWrite
                        equalsNode:(id<FNode>)node
                      withPriority:(id<FNode>)priority {
  id<FNode> updatedNode = [compoundWrite applyToNode:node];
  if (node.isEmpty) {
    XCTAssertEqualObjects([FEmptyNode emptyNode], updatedNode,
                          @"Applied compound write should be empty. %@", updatedNode);
  } else {
    XCTAssertEqualObjects([node updatePriority:priority], updatedNode,
                          @"Applied compound write should equal node with priority. %@",
                          updatedNode);
  }
}

- (void)testEmptyMergeIsEmpty {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  XCTAssertTrue(compoundWrite.isEmpty, @"Empty write should be empty %@", compoundWrite);
}

- (void)testCompoundWriteWithPriorityUpdateIsNotEmpty {
  FCompoundWrite *compoundWrite = [[FCompoundWrite emptyWrite] addWrite:self.priorityNode
                                                                  atKey:@".priority"];
  XCTAssertFalse(compoundWrite.isEmpty, @"Priority update should not be empty %@", compoundWrite);
}

- (void)testCompoundWriteWithUpdateIsNotEmpty {
  FCompoundWrite *compoundWrite =
      [[FCompoundWrite emptyWrite] addWrite:self.leafNode
                                     atPath:[[FPath alloc] initWith:@"foo/bar"]];
  XCTAssertFalse(compoundWrite.isEmpty, @"Update should not be empty %@", compoundWrite);
}

- (void)testCompoundWriteWithRootUpdateIsNotEmpty {
  FCompoundWrite *compoundWrite = [[FCompoundWrite emptyWrite] addWrite:self.leafNode
                                                                 atPath:[FPath empty]];
  XCTAssertFalse(compoundWrite.isEmpty, @"Update at root should not be empty %@", compoundWrite);
}

- (void)testCompoundWriteWithEmptyRootUpdateIsNotEmpty {
  FCompoundWrite *compoundWrite = [[FCompoundWrite emptyWrite] addWrite:[FEmptyNode emptyNode]
                                                                 atPath:[FPath empty]];
  XCTAssertFalse(compoundWrite.isEmpty, @"Empty root update should not be empty %@", compoundWrite);
}

- (void)testCompoundWriteWithRootPriorityUpdateAndChildMergeIsNotEmpty {
  FCompoundWrite *compoundWrite = [[FCompoundWrite emptyWrite] addWrite:self.priorityNode
                                                                  atKey:@".priority"];
  compoundWrite = [compoundWrite childCompoundWriteAtPath:[[FPath alloc] initWith:@".priority"]];
  XCTAssertFalse(compoundWrite.isEmpty,
                 @"Compound write with root priority update and child merge should not be empty.");
}

- (void)testAppliesLeafOverwrite {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.leafNode atPath:[FPath empty]];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  XCTAssertEqualObjects(updatedNode, self.leafNode, @"Should get leaf node once applied %@",
                        updatedNode);
}

- (void)testAppliesChildrenOverwrite {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> childNode = [[FEmptyNode emptyNode] updateImmediateChild:@"child"
                                                        withNewChild:self.leafNode];
  compoundWrite = [compoundWrite addWrite:childNode atPath:[FPath empty]];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  XCTAssertEqualObjects(updatedNode, childNode, @"Child overwrite should work");
}

- (void)testAddsChildNode {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> expectedNode = [[FEmptyNode emptyNode] updateImmediateChild:@"child"
                                                           withNewChild:self.leafNode];
  compoundWrite = [compoundWrite addWrite:self.leafNode atKey:@"child"];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Adding child node should work %@",
                        updatedNode);
}

- (void)testAddsDeepChildNode {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  FPath *path = [[FPath alloc] initWith:@"deep/deep/node"];
  id<FNode> expectedNode = [[FEmptyNode emptyNode] updateChild:path withNewChild:self.leafNode];
  compoundWrite = [compoundWrite addWrite:self.leafNode atPath:path];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Should add deep child node correctly");
}

- (void)testOverwritesExistingChild {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  FPath *path = [[FPath alloc] initWith:@"child-1"];
  compoundWrite = [compoundWrite addWrite:self.leafNode atPath:path];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  id<FNode> expectedNode = [self.baseNode updateImmediateChild:[path getFront]
                                                  withNewChild:self.leafNode];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Overwriting existing child should work.");
}

- (void)testUpdatesExistingChild {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  FPath *path = [[FPath alloc] initWith:@"child-1/foo"];
  compoundWrite = [compoundWrite addWrite:self.leafNode atPath:path];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  id<FNode> expectedNode = [self.baseNode updateChild:path withNewChild:self.leafNode];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Updating existing child should work");
}

- (void)testDoesntUpdatePriorityOnEmptyNode {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode atKey:@".priority"];
  [self assertAppliedCompoundWrite:compoundWrite
                        equalsNode:[FEmptyNode emptyNode]
                      withPriority:[FEmptyNode emptyNode]];
}

- (void)testUpdatesPriorityOnNode {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode atKey:@".priority"];
  id<FNode> node = [FSnapshotUtilities nodeFrom:@"value"];
  [self assertAppliedCompoundWrite:compoundWrite equalsNode:node withPriority:self.priorityNode];
}

- (void)testUpdatesPriorityOfChild {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  FPath *path = [[FPath alloc] initWith:@"child-1/.priority"];
  compoundWrite = [compoundWrite addWrite:self.priorityNode atPath:path];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  id<FNode> expectedNode = [self.baseNode updateChild:path withNewChild:self.priorityNode];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Updating priority of child should work.");
}

- (void)testDoesntUpdatePriorityOfNonExistentChild {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  FPath *path = [[FPath alloc] initWith:@"child-3/.priority"];
  compoundWrite = [compoundWrite addWrite:self.priorityNode atPath:path];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  XCTAssertEqualObjects(updatedNode, self.baseNode,
                        @"Should not update priority of nonexistent child");
}

- (void)testDeepUpdateExistingUpdates {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> update1 = [FSnapshotUtilities nodeFrom:@{@"foo" : @"foo-value", @"bar" : @"bar-value"}];
  id<FNode> update2 = [FSnapshotUtilities nodeFrom:@"baz-value"];
  id<FNode> update3 = [FSnapshotUtilities nodeFrom:@"new-foo-value"];
  compoundWrite = [compoundWrite addWrite:update1 atPath:[[FPath alloc] initWith:@"child-1"]];
  compoundWrite = [compoundWrite addWrite:update2 atPath:[[FPath alloc] initWith:@"child-1/baz"]];
  compoundWrite = [compoundWrite addWrite:update3 atPath:[[FPath alloc] initWith:@"child-1/foo"]];
  NSDictionary *expectedChild1 =
      @{@"foo" : @"new-foo-value", @"bar" : @"bar-value", @"baz" : @"baz-value"};
  id<FNode> expectedNode =
      [self.baseNode updateImmediateChild:@"child-1"
                             withNewChild:[FSnapshotUtilities nodeFrom:expectedChild1]];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  XCTAssertEqualObjects(updatedNode, expectedNode,
                        @"Deep update with existing updates should work.");
}

- (void)testShallowUpdateRemovesDeepUpdate {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> update1 = [FSnapshotUtilities nodeFrom:@"new-foo-value"];
  id<FNode> update2 = [FSnapshotUtilities nodeFrom:@"baz-value"];
  id<FNode> update3 = [FSnapshotUtilities nodeFrom:@{@"foo" : @"foo-value", @"bar" : @"bar-value"}];
  compoundWrite = [compoundWrite addWrite:update1 atPath:[[FPath alloc] initWith:@"child-1/foo"]];
  compoundWrite = [compoundWrite addWrite:update2 atPath:[[FPath alloc] initWith:@"child-1/baz"]];
  compoundWrite = [compoundWrite addWrite:update3 atPath:[[FPath alloc] initWith:@"child-1"]];
  NSDictionary *expectedChild1 = @{@"foo" : @"foo-value", @"bar" : @"bar-value"};
  id<FNode> expectedNode =
      [self.baseNode updateImmediateChild:@"child-1"
                             withNewChild:[FSnapshotUtilities nodeFrom:expectedChild1]];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Shallow update should remove deep udpates.");
}

- (void)testChildPriorityDoesntUpdateEmptyNodePriorityOnChildMerge {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode
                                   atPath:[[FPath alloc] initWith:@"child-1/.priority"]];
  compoundWrite = [compoundWrite childCompoundWriteAtPath:[[FPath alloc] initWith:@"child-1"]];
  [self assertAppliedCompoundWrite:compoundWrite
                        equalsNode:[FEmptyNode emptyNode]
                      withPriority:[FEmptyNode emptyNode]];
}

- (void)testChildPriorityUpdatesPriorityOnChildMerge {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode
                                   atPath:[[FPath alloc] initWith:@"child-1/.priority"]];
  id<FNode> node = [FSnapshotUtilities nodeFrom:@"value"];
  compoundWrite = [compoundWrite childCompoundWriteAtPath:[[FPath alloc] initWith:@"child-1"]];
  [self assertAppliedCompoundWrite:compoundWrite equalsNode:node withPriority:self.priorityNode];
}

- (void)testChildPriorityUpdatesEmptyPriorityOnChildMerge {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:[FEmptyNode emptyNode]
                                   atPath:[[FPath alloc] initWith:@"child-1/.priority"]];
  id<FNode> node = [[FLeafNode alloc] initWithValue:@"foo" withPriority:self.priorityNode];
  compoundWrite = [compoundWrite childCompoundWriteAtPath:[[FPath alloc] initWith:@"child-1"]];
  [self assertAppliedCompoundWrite:compoundWrite
                        equalsNode:node
                      withPriority:[FEmptyNode emptyNode]];
}

- (void)testDeepPrioritySetWorksOnEmptyNodeWhenOtherSetIsAvailable {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode
                                   atPath:[[FPath alloc] initWith:@"foo/.priority"]];
  compoundWrite = [compoundWrite addWrite:self.leafNode
                                   atPath:[[FPath alloc] initWith:@"foo/child"]];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  id<FNode> updatedPriority = [updatedNode getChild:[[FPath alloc] initWith:@"foo"]].getPriority;
  XCTAssertEqualObjects(updatedPriority, self.priorityNode, @"Should get priority");
}

- (void)testChildMergeLooksIntoUpdateNode {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> update = [FSnapshotUtilities nodeFrom:@{@"foo" : @"foo-value", @"bar" : @"bar-value"}];
  compoundWrite = [compoundWrite addWrite:update atPath:[FPath empty]];
  compoundWrite = [compoundWrite childCompoundWriteAtPath:[[FPath alloc] initWith:@"foo"]];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  id<FNode> expectedNode = [FSnapshotUtilities nodeFrom:@"foo-value"];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Child merge should get updates.");
}

- (void)testChildMergeRemovesNodeOnDeeperPaths {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> update = [FSnapshotUtilities nodeFrom:@{@"foo" : @"foo-value", @"bar" : @"bar-value"}];
  compoundWrite = [compoundWrite addWrite:update atPath:[FPath empty]];
  compoundWrite =
      [compoundWrite childCompoundWriteAtPath:[[FPath alloc] initWith:@"foo/not/existing"]];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.leafNode];
  id<FNode> expectedNode = [FEmptyNode emptyNode];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Should not have node.");
}

- (void)testChildMergeWithEmptyPathIsSameMerge {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> update = [FSnapshotUtilities nodeFrom:@{@"foo" : @"foo-value", @"bar" : @"bar-value"}];
  compoundWrite = [compoundWrite addWrite:update atPath:[FPath empty]];
  XCTAssertEqualObjects([compoundWrite childCompoundWriteAtPath:[FPath empty]], compoundWrite,
                        @"Child merge with empty path should be the same merge.");
}

- (void)testRootUpdateRemovesRootPriority {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode
                                   atPath:[[FPath alloc] initWith:@".priority"]];
  id<FNode> update = [FSnapshotUtilities nodeFrom:@"foo"];
  compoundWrite = [compoundWrite addWrite:update atPath:[FPath empty]];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  XCTAssertEqualObjects(updatedNode, update, @"Root update should remove root priority");
}

- (void)testDeepUpdateRemovesPriorityThere {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode
                                   atPath:[[FPath alloc] initWith:@"foo/.priority"]];
  id<FNode> update = [FSnapshotUtilities nodeFrom:@"bar"];
  compoundWrite = [compoundWrite addWrite:update atPath:[[FPath alloc] initWith:@"foo"]];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  id<FNode> expectedNode = [FSnapshotUtilities nodeFrom:@{@"foo" : @"bar"}];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Deep update should remove priority there");
}

- (void)testAddingUpdatesAtPathWorks {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  NSMutableDictionary *updateDictionary = [[NSMutableDictionary alloc] init];
  [updateDictionary setObject:@"foo-value" forKey:@"foo"];
  [updateDictionary setObject:@"bar-value" forKey:@"bar"];
  FCompoundWrite *updates = [FCompoundWrite compoundWriteWithValueDictionary:updateDictionary];
  compoundWrite = [compoundWrite addCompoundWrite:updates
                                           atPath:[[FPath alloc] initWith:@"child-1"]];

  NSDictionary *expectedChild1 = @{@"foo" : @"foo-value", @"bar" : @"bar-value"};
  id<FNode> expectedNode =
      [self.baseNode updateImmediateChild:@"child-1"
                             withNewChild:[FSnapshotUtilities nodeFrom:expectedChild1]];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Adding updates at a path should work.");
}

- (void)testAddingUpdatesAtRootWorks {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  NSMutableDictionary *updateDictionary = [[NSMutableDictionary alloc] init];
  [updateDictionary setObject:@"new-value-1" forKey:@"child-1"];
  [updateDictionary setObject:[NSNull null] forKey:@"child-2"];
  [updateDictionary setObject:@"value-3" forKey:@"child-3"];
  FCompoundWrite *updates = [FCompoundWrite compoundWriteWithValueDictionary:updateDictionary];
  compoundWrite = [compoundWrite addCompoundWrite:updates atPath:[FPath empty]];

  NSDictionary *expected = @{@"child-1" : @"new-value-1", @"child-3" : @"value-3"};
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  id<FNode> expectedNode = [FSnapshotUtilities nodeFrom:expected];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Adding updates at root should work.");
}

- (void)testChildMergeOfRootPriorityWorks {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode
                                   atPath:[[FPath alloc] initWith:@".priority"]];
  compoundWrite = [compoundWrite childCompoundWriteAtPath:[[FPath alloc] initWith:@".priority"]];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  XCTAssertEqualObjects(updatedNode, self.priorityNode,
                        @"Child merge of root priority should work.");
}

- (void)testCompleteChildrenOnlyReturnsCompleteOverwrites {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.leafNode atPath:[[FPath alloc] initWith:@"child-1"]];
  NSArray *expectedChildren = @[ [[FNamedNode alloc] initWithName:@"child-1"
                                                          andNode:self.leafNode] ];
  NSArray *completeChildren = [compoundWrite completeChildren];
  XCTAssertEqualObjects(completeChildren, expectedChildren,
                        @"Complete children should only return on complete overwrites.");
}

- (void)testCompleteChildrenOnlyReturnsEmptyOverwrites {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:[FEmptyNode emptyNode]
                                   atPath:[[FPath alloc] initWith:@"child-1"]];
  NSArray *expectedChildren = @[ [[FNamedNode alloc] initWithName:@"child-1"
                                                          andNode:[FEmptyNode emptyNode]] ];
  NSArray *completeChildren = [compoundWrite completeChildren];
  XCTAssertEqualObjects(completeChildren, expectedChildren,
                        @"Complete children should return list with empty on empty overwrites.");
}

- (void)testCompleteChildrenDoesntReturnDeepOverwrites {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.leafNode
                                   atPath:[[FPath alloc] initWith:@"child-1/deep/path"]];
  NSArray *expectedChildren = @[];
  NSArray *completeChildren = [compoundWrite completeChildren];
  XCTAssertEqualObjects(completeChildren, expectedChildren,
                        @"Should not get complete children on deep overwrites.");
}

- (void)testCompleteChildrenReturnAllCompleteChildrenButNoIncomplete {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.leafNode
                                   atPath:[[FPath alloc] initWith:@"child-1/deep/path"]];
  compoundWrite = [compoundWrite addWrite:self.leafNode atPath:[[FPath alloc] initWith:@"child-2"]];
  compoundWrite = [compoundWrite addWrite:[FEmptyNode emptyNode]
                                   atPath:[[FPath alloc] initWith:@"child-3"]];
  NSDictionary *expected = @{@"child-2" : self.leafNode, @"child-3" : [FEmptyNode emptyNode]};
  NSMutableDictionary *actual = [[NSMutableDictionary alloc] init];
  for (FNamedNode *node in compoundWrite.completeChildren) {
    [actual setObject:node.node forKey:node.name];
  }
  XCTAssertEqualObjects(actual, expected,
                        @"Complete children should get returned, but not incomplete ones.");
}

- (void)testCompleteChildrenReturnAllChildrenForRootSet {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.baseNode atPath:[FPath empty]];

  NSDictionary *expected = @{
    @"child-1" : [FSnapshotUtilities nodeFrom:@"value-1"],
    @"child-2" : [FSnapshotUtilities nodeFrom:@"value-2"]
  };

  NSMutableDictionary *actual = [[NSMutableDictionary alloc] init];
  for (FNamedNode *node in compoundWrite.completeChildren) {
    [actual setObject:node.node forKey:node.name];
  }
  XCTAssertEqualObjects(actual, expected,
                        @"Complete children should return all children on root set.");
}

- (void)testEmptyMergeHasNoShadowingWrite {
  XCTAssertFalse([[FCompoundWrite emptyWrite] hasCompleteWriteAtPath:[FPath empty]],
                 @"Empty merge has no shadowing write.");
}

- (void)testCompoundWriteWithEmptyRootHasShadowingWrite {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:[FEmptyNode emptyNode] atPath:[FPath empty]];
  XCTAssertTrue([compoundWrite hasCompleteWriteAtPath:[FPath empty]],
                @"Empty write should have shadowing write at root.");
  XCTAssertTrue([compoundWrite hasCompleteWriteAtPath:[[FPath alloc] initWith:@"child"]],
                @"Empty write should have complete write at child.");
}

- (void)testCompoundWriteWithRootHasShadowingWrite {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.leafNode atPath:[FPath empty]];
  XCTAssertTrue([compoundWrite hasCompleteWriteAtPath:[FPath empty]],
                @"Root write should have shadowing write at root.");
  XCTAssertTrue([compoundWrite hasCompleteWriteAtPath:[[FPath alloc] initWith:@"child"]],
                @"Root write should have complete write at child.");
}

- (void)testCompoundWriteWithDeepUpdateHasShadowingWrite {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.leafNode
                                   atPath:[[FPath alloc] initWith:@"deep/update"]];
  XCTAssertFalse([compoundWrite hasCompleteWriteAtPath:[FPath empty]],
                 @"Deep write should not have complete write at root.");
  XCTAssertFalse([compoundWrite hasCompleteWriteAtPath:[[FPath alloc] initWith:@"deep"]],
                 @"Deep write should not have should have complete write at child.");
  XCTAssertTrue([compoundWrite hasCompleteWriteAtPath:[[FPath alloc] initWith:@"deep/update"]],
                @"Deep write should have complete write at deep child.");
}

- (void)testCompoundWriteWithPriorityUpdateHasShadowingWrite {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode
                                   atPath:[[FPath alloc] initWith:@".priority"]];
  XCTAssertFalse([compoundWrite hasCompleteWriteAtPath:[FPath empty]],
                 @"Write with priority at root should not have complete write at root.");
  XCTAssertTrue([compoundWrite hasCompleteWriteAtPath:[[FPath alloc] initWith:@".priority"]],
                @"Write with priority at root should have complete priority.");
}

- (void)testUpdatesCanBeRemoved {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> update = [FSnapshotUtilities nodeFrom:@{@"foo" : @"foo-value", @"bar" : @"bar-value"}];
  compoundWrite = [compoundWrite addWrite:update atPath:[[FPath alloc] initWith:@"child-1"]];
  compoundWrite = [compoundWrite removeWriteAtPath:[[FPath alloc] initWith:@"child-1"]];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  XCTAssertEqualObjects(updatedNode, self.baseNode, @"Updates should be removed.");
}

- (void)testDeepRemovesHasNoEffectOnOverlayingSet {
  // TODO I don't get this one.
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> update1 = [FSnapshotUtilities nodeFrom:@{@"foo" : @"foo-value", @"bar" : @"bar-value"}];
  id<FNode> update2 = [FSnapshotUtilities nodeFrom:@"baz-value"];
  id<FNode> update3 = [FSnapshotUtilities nodeFrom:@"new-foo-value"];
  compoundWrite = [compoundWrite addWrite:update1 atPath:[[FPath alloc] initWith:@"child-1"]];
  compoundWrite = [compoundWrite addWrite:update2 atPath:[[FPath alloc] initWith:@"child-1/baz"]];
  compoundWrite = [compoundWrite addWrite:update3 atPath:[[FPath alloc] initWith:@"child-1/foo"]];
  compoundWrite = [compoundWrite removeWriteAtPath:[[FPath alloc] initWith:@"child-1/foo"]];
  NSDictionary *expected =
      @{@"foo" : @"new-foo-value", @"bar" : @"bar-value", @"baz" : @"baz-value"};
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  id<FNode> expectedNode =
      [self.baseNode updateImmediateChild:@"child-1"
                             withNewChild:[FSnapshotUtilities nodeFrom:expected]];
  XCTAssertEqualObjects(updatedNode, expectedNode,
                        @"Deep removes should have no effect on overlaying set.");
}

- (void)testRemoveAtPathWithoutSetIsWithoutEffect {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> update1 = [FSnapshotUtilities nodeFrom:@{@"foo" : @"foo-value", @"bar" : @"bar-value"}];
  id<FNode> update2 = [FSnapshotUtilities nodeFrom:@"baz-value"];
  id<FNode> update3 = [FSnapshotUtilities nodeFrom:@"new-foo-value"];
  compoundWrite = [compoundWrite addWrite:update1 atPath:[[FPath alloc] initWith:@"child-1"]];
  compoundWrite = [compoundWrite addWrite:update2 atPath:[[FPath alloc] initWith:@"child-1/baz"]];
  compoundWrite = [compoundWrite addWrite:update3 atPath:[[FPath alloc] initWith:@"child-1/foo"]];
  compoundWrite = [compoundWrite removeWriteAtPath:[[FPath alloc] initWith:@"child-2"]];
  NSDictionary *expected =
      @{@"foo" : @"new-foo-value", @"bar" : @"bar-value", @"baz" : @"baz-value"};
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  id<FNode> expectedNode =
      [self.baseNode updateImmediateChild:@"child-1"
                             withNewChild:[FSnapshotUtilities nodeFrom:expected]];
  XCTAssertEqualObjects(updatedNode, expectedNode,
                        @"Removing at path without a set should have no effect.");
}

- (void)testCanRemovePriority {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.priorityNode
                                   atPath:[[FPath alloc] initWith:@".priority"]];
  compoundWrite = [compoundWrite removeWriteAtPath:[[FPath alloc] initWith:@".priority"]];
  [self assertAppliedCompoundWrite:compoundWrite
                        equalsNode:self.leafNode
                      withPriority:[FEmptyNode emptyNode]];
}

- (void)testRemovingOnlyAffectsRemovedPath {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  NSDictionary *updateDictionary =
      @{@"child-1" : @"new-value-1", @"child-2" : [NSNull null], @"child-3" : @"value-3"};
  FCompoundWrite *updates = [FCompoundWrite compoundWriteWithValueDictionary:updateDictionary];
  compoundWrite = [compoundWrite addCompoundWrite:updates atPath:[FPath empty]];
  compoundWrite = [compoundWrite removeWriteAtPath:[[FPath alloc] initWith:@"child-2"]];

  NSDictionary *expected =
      @{@"child-1" : @"new-value-1", @"child-2" : @"value-2", @"child-3" : @"value-3"};
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  id<FNode> expectedNode = [FSnapshotUtilities nodeFrom:expected];
  XCTAssertEqualObjects(updatedNode, expectedNode, @"Removing should only affected removed paths");
}

- (void)testRemoveRemovesAllDeeperSets {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  id<FNode> update2 = [FSnapshotUtilities nodeFrom:@"baz-value"];
  id<FNode> update3 = [FSnapshotUtilities nodeFrom:@"new-foo-value"];
  compoundWrite = [compoundWrite addWrite:update2 atPath:[[FPath alloc] initWith:@"child-1/baz"]];
  compoundWrite = [compoundWrite addWrite:update3 atPath:[[FPath alloc] initWith:@"child-1/foo"]];
  compoundWrite = [compoundWrite removeWriteAtPath:[[FPath alloc] initWith:@"child-1"]];
  id<FNode> updatedNode = [compoundWrite applyToNode:self.baseNode];
  XCTAssertEqualObjects(updatedNode, self.baseNode, @"Remove should remove deeper sets.");
}

- (void)testRemoveAtRootAlsoRemovesPriority {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:[[FLeafNode alloc] initWithValue:@"foo"
                                                              withPriority:self.priorityNode]
                                   atPath:[FPath empty]];
  compoundWrite = [compoundWrite removeWriteAtPath:[FPath empty]];
  id<FNode> node = [FSnapshotUtilities nodeFrom:@"value"];
  [self assertAppliedCompoundWrite:compoundWrite
                        equalsNode:node
                      withPriority:[FEmptyNode emptyNode]];
}

- (void)testUpdatingPriorityDoesntOverwriteLeafNode {
  // TODO I don't get this one.
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.leafNode atPath:[FPath empty]];
  compoundWrite = [compoundWrite addWrite:self.priorityNode
                                   atPath:[[FPath alloc] initWith:@"child/.priority"]];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  XCTAssertEqualObjects(updatedNode, self.leafNode,
                        @"Updating priority should not overwrite leaf node.");
}

- (void)testUpdatingEmptyChildNodeDoesntOverwriteLeafNode {
  FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
  compoundWrite = [compoundWrite addWrite:self.leafNode atPath:[FPath empty]];
  compoundWrite = [compoundWrite addWrite:[FEmptyNode emptyNode]
                                   atPath:[[FPath alloc] initWith:@"child"]];
  id<FNode> updatedNode = [compoundWrite applyToNode:[FEmptyNode emptyNode]];
  XCTAssertEqualObjects(updatedNode, self.leafNode,
                        @"Updating empty node should not overwrite leaf node.");
}

@end
