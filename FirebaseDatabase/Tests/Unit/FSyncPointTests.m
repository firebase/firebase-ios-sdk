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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseDatabase/Sources/Api/Private/FIRDataSnapshot_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Core/FListenProvider.h"
#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Core/FSyncTree.h"
#import "FirebaseDatabase/Sources/Core/View/FCancelEvent.h"
#import "FirebaseDatabase/Sources/Core/View/FChange.h"
#import "FirebaseDatabase/Sources/Core/View/FDataEvent.h"
#import "FirebaseDatabase/Sources/Core/View/FEventRegistration.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/FKeyIndex.h"
#import "FirebaseDatabase/Sources/FPathIndex.h"
#import "FirebaseDatabase/Sources/FPriorityIndex.h"
#import "FirebaseDatabase/Sources/Snapshot/FCompoundWrite.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Tests/Helpers/FTestClock.h"
#import "FirebaseDatabase/Tests/Unit/FSyncPointTests.h"

typedef NSDictionary * (^fbt_nsdictionary_void)(void);

@interface FTestEventRegistration : NSObject <FEventRegistration>
@property(nonatomic, strong) NSDictionary *spec;
@property(nonatomic, strong) FQuerySpec *query;
@end

@implementation FTestEventRegistration
- (id)initWithSpec:(NSDictionary *)eventSpec query:(FQuerySpec *)query {
  self = [super init];
  if (self) {
    self.spec = eventSpec;
    self.query = query;
  }
  return self;
}

- (BOOL)responseTo:(FIRDataEventType)eventType {
  return YES;
}
- (FDataEvent *)createEventFrom:(FChange *)change query:(FQuerySpec *)query {
  FIRDataSnapshot *snap = nil;
  FIRDatabaseReference *ref = [[FIRDatabaseReference alloc] initWithRepo:nil path:query.path];
  if (change.type == FIRDataEventTypeValue) {
    snap = [[FIRDataSnapshot alloc] initWithRef:ref indexedNode:change.indexedNode];
  } else {
    snap = [[FIRDataSnapshot alloc] initWithRef:[ref child:change.childKey]
                                    indexedNode:change.indexedNode];
  }
  return [[FDataEvent alloc] initWithEventType:change.type
                             eventRegistration:self
                                  dataSnapshot:snap
                                      prevName:change.prevKey];
}

- (BOOL)matches:(id<FEventRegistration>)other {
  if (![other isKindOfClass:[FTestEventRegistration class]]) {
    return NO;
  } else {
    FTestEventRegistration *otherRegistration = other;
    if (self.spec[@"callbackId"] && otherRegistration.spec[@"callbackId"] &&
        [self.spec[@"callbackId"] isEqualToNumber:otherRegistration.spec[@"callbackId"]]) {
      return YES;
    } else {
      return NO;
    }
  }
}

- (void)fireEvent:(id<FEvent>)event queue:(dispatch_queue_t)queue {
  [NSException raise:@"NotImplementedError" format:@"Method not implemented."];
}
- (FCancelEvent *)createCancelEventFromError:(NSError *)error path:(FPath *)path {
  [NSException raise:@"NotImplementedError" format:@"Method not implemented."];
  return nil;
}

- (FIRDatabaseHandle)handle {
  [NSException raise:@"NotImplementedError" format:@"Method not implemented."];
  return 0;
}
@end

@implementation FSyncPointTests

- (NSString *)queryKeyForQuery:(FQuerySpec *)query tagId:(NSNumber *)tagId {
  return [NSString stringWithFormat:@"%@|%@|%@", query.path, query.params, tagId];
}

- (void)actualEvent:(FDataEvent *)actual equalsExpected:(NSDictionary *)expected {
  XCTAssertEqual(actual.eventType, [self stringToEventType:expected[@"type"]],
                 @"Event type should be equal");
  if (actual.eventType != FIRDataEventTypeValue) {
    NSString *childName = actual.snapshot.key;
    XCTAssertEqualObjects(childName, expected[@"name"], @"Snapshot name should be equal");
    if (expected[@"prevName"] == [NSNull null]) {
      XCTAssertNil(actual.prevName, @"prevName should be nil");
    } else {
      XCTAssertEqualObjects(actual.prevName, expected[@"prevName"], @"prevName should be equal");
    }
  }
  NSString *actualHash = [actual.snapshot.node.node dataHash];
  NSString *expectedHash = [[FSnapshotUtilities nodeFrom:expected[@"data"]] dataHash];
  XCTAssertEqualObjects(actualHash, expectedHash, @"Data hash should be equal");
}

/**
 * @param actual is an array of id<FEvent>
 * @param expected is an array of dictionaries?
 */
- (void)actualEvents:(NSArray *)actual exactMatchesExpected:(NSArray *)expected {
  if ([expected count] < [actual count]) {
    XCTFail(@"Got extra events: %@", actual);
  } else if ([expected count] > [actual count]) {
    XCTFail(@"Missing events: %@", actual);
  } else {
    NSUInteger i = 0;
    for (i = 0; i < [expected count]; i++) {
      FDataEvent *actualEvent = actual[i];
      NSDictionary *expectedEvent = expected[i];
      [self actualEvent:actualEvent equalsExpected:expectedEvent];
    }
  }
}

- (void)assertOrderedFirstEvent:(FIRDataEventType)e1 secondEvent:(FIRDataEventType)e2 {
  static NSArray *eventOrdering = nil;
  if (!eventOrdering) {
    eventOrdering = @[
      [NSNumber numberWithInteger:FIRDataEventTypeChildRemoved],
      [NSNumber numberWithInteger:FIRDataEventTypeChildAdded],
      [NSNumber numberWithInteger:FIRDataEventTypeChildMoved],
      [NSNumber numberWithInteger:FIRDataEventTypeChildChanged],
      [NSNumber numberWithInteger:FIRDataEventTypeValue]
    ];
  }
  NSUInteger idx1 = [eventOrdering indexOfObject:[NSNumber numberWithInteger:e1]];
  NSUInteger idx2 = [eventOrdering indexOfObject:[NSNumber numberWithInteger:e2]];
  if (idx1 > idx2) {
    XCTFail(@"Received %d after %d", (int)e2, (int)e1);
  }
}

- (FIRDataEventType)stringToEventType:(NSString *)stringType {
  if ([stringType isEqualToString:@"child_added"]) {
    return FIRDataEventTypeChildAdded;
  } else if ([stringType isEqualToString:@"child_removed"]) {
    return FIRDataEventTypeChildRemoved;
  } else if ([stringType isEqualToString:@"child_changed"]) {
    return FIRDataEventTypeChildChanged;
  } else if ([stringType isEqualToString:@"child_moved"]) {
    return FIRDataEventTypeChildMoved;
  } else if ([stringType isEqualToString:@"value"]) {
    return FIRDataEventTypeValue;
  } else {
    XCTFail(@"Unknown event type %@", stringType);
    return FIRDataEventTypeValue;
  }
}

- (void)actualEventSet:(id)actual matchesExpected:(id)expected atBasePath:(NSString *)basePathStr {
  // don't worry about order for now
  XCTAssertEqual([expected count], [actual count], @"Mismatched lengths.\nExpected: %@\nActual: %@",
                 expected, actual);

  NSArray *currentExpected = expected;
  NSArray *currentActual = actual;
  FPath *basePath = basePathStr != nil ? [[FPath alloc] initWith:basePathStr] : [FPath empty];
  while ([currentExpected count] > 0) {
    // Step 1: find location range in expected
    // we expect all events for a particular path to be in a group
    FPath *currentPath = [basePath childFromString:currentExpected[0][@"path"]];
    NSUInteger i = 1;
    while (i < [currentExpected count]) {
      FPath *otherPath = [basePath childFromString:currentExpected[i][@"path"]];
      if ([currentPath isEqual:otherPath]) {
        i++;
      } else {
        break;
      }
    }

    // Step 2: foreach in actual, asserting location
    NSUInteger j = 0;
    for (j = 0; j < i; j++) {
      FDataEvent *actualEventData = currentActual[j];
      FTestEventRegistration *eventRegistration = actualEventData.eventRegistration;
      NSDictionary *specStep = eventRegistration.spec;
      FPath *actualPath = [basePath childFromString:specStep[@"path"]];
      if (![currentPath isEqual:actualPath]) {
        XCTFail(@"Expected path %@ to equal %@", actualPath, currentPath);
      }
    }

    // Step 3: slice each array
    NSMutableArray *expectedSlice =
        [[currentExpected subarrayWithRange:NSMakeRange(0, i)] mutableCopy];
    NSArray *actualSlice = [currentActual subarrayWithRange:NSMakeRange(0, i)];

    // foreach in actual, stack up to enforce ordering, find in expected
    NSMutableDictionary *actualMap = [[NSMutableDictionary alloc] init];
    for (FDataEvent *actualEvent in actualSlice) {
      FTestEventRegistration *eventRegistration = actualEvent.eventRegistration;
      FQuerySpec *query = eventRegistration.query;
      NSDictionary *spec = eventRegistration.spec;
      NSString *listenId =
          [NSString stringWithFormat:@"%@|%@", [basePath childFromString:spec[@"path"]], query];
      if (actualMap[listenId]) {
        // stack this event up, and make sure it obeys ordering constraints
        NSMutableArray *eventStack = actualMap[listenId];
        FDataEvent *prevEvent = eventStack[[eventStack count] - 1];
        [self assertOrderedFirstEvent:prevEvent.eventType secondEvent:actualEvent.eventType];
        [eventStack addObject:actualEvent];
      } else {
        // this is the first event for this listen, just initialize it
        actualMap[listenId] = [[NSMutableArray alloc] initWithObjects:actualEvent, nil];
      }
      // Ordering has been enforced, make sure we can find this in the expected events
      __block NSUInteger indexToRemove = NSNotFound;
      [expectedSlice enumerateObjectsUsingBlock:^(NSDictionary *expectedEvent, NSUInteger idx,
                                                  BOOL *stop) {
        if ([self stringToEventType:expectedEvent[@"type"]] == actualEvent.eventType) {
          if ([self stringToEventType:expectedEvent[@"type"]] != FIRDataEventTypeValue) {
            if (![expectedEvent[@"name"] isEqualToString:actualEvent.snapshot.key]) {
              return;  // short circuit, not a match
            }
            if ([self stringToEventType:expectedEvent[@"type"]] != FIRDataEventTypeChildRemoved &&
                !(expectedEvent[@"prevName"] == [NSNull null] && actualEvent.prevName == nil) &&
                !(expectedEvent[@"prevName"] != [NSNull null] &&
                  [expectedEvent[@"prevName"] isEqualToString:actualEvent.prevName])) {
              return;  // short circuit, not a match
            }
          }
          // make sure the snapshots match
          NSString *snapHash = [actualEvent.snapshot.node.node dataHash];
          NSString *expectedHash = [[FSnapshotUtilities nodeFrom:expectedEvent[@"data"]] dataHash];
          if ([snapHash isEqualToString:expectedHash]) {
            indexToRemove = idx;
            *stop = YES;
          }
        }
      }];
      XCTAssertFalse(indexToRemove == NSNotFound, @"Could not find matching expected event for %@",
                     actualEvent);
      [expectedSlice removeObjectAtIndex:indexToRemove];
    }
    currentExpected =
        [currentExpected subarrayWithRange:NSMakeRange(i, [currentExpected count] - i)];
    currentActual = [currentActual subarrayWithRange:NSMakeRange(i, [currentActual count] - i)];
  }
}

- (FQuerySpec *)parseParams:(NSDictionary *)specParams forPath:(FPath *)path {
  FQueryParams *query = [[FQueryParams alloc] init];
  NSMutableDictionary *params;

  if (specParams) {
    params = [specParams mutableCopy];
    if (!params[@"tag"]) {
      XCTFail(@"Error: Non-default queries must have tag");
    }
  } else {
    params = [NSMutableDictionary dictionary];
  }

  if (params[@"orderBy"]) {
    FPath *indexPath = [FPath pathWithString:params[@"orderBy"]];
    id<FIndex> index = [[FPathIndex alloc] initWithPath:indexPath];
    query = [query orderBy:index];
    [params removeObjectForKey:@"orderBy"];
  }
  if (params[@"orderByKey"]) {
    query = [query orderBy:[FKeyIndex keyIndex]];
    [params removeObjectForKey:@"orderByKey"];
  }
  if (params[@"orderByPriority"]) {
    query = [query orderBy:[FPriorityIndex priorityIndex]];
    [params removeObjectForKey:@"orderByPriority"];
  }

  if (params[@"startAt"]) {
    id<FNode> node = [FSnapshotUtilities nodeFrom:params[@"startAt"][@"index"]];
    if (params[@"startAt"][@"name"]) {
      query = [query startAt:node childKey:params[@"startAt"][@"name"]];
    } else {
      query = [query startAt:node];
    }
    [params removeObjectForKey:@"startAt"];
  }
  if (params[@"endAt"]) {
    id<FNode> node = [FSnapshotUtilities nodeFrom:params[@"endAt"][@"index"]];
    if (params[@"endAt"][@"name"]) {
      query = [query endAt:node childKey:params[@"endAt"][@"name"]];
    } else {
      query = [query endAt:node];
    }
    [params removeObjectForKey:@"endAt"];
  }
  if (params[@"equalTo"]) {
    id<FNode> node = [FSnapshotUtilities nodeFrom:params[@"equalTo"][@"index"]];
    if (params[@"equalTo"][@"name"]) {
      NSString *name = params[@"equalTo"][@"name"];
      query = [[query startAt:node childKey:name] endAt:node childKey:name];
    } else {
      query = [[query startAt:node] endAt:node];
    }
    [params removeObjectForKey:@"equalTo"];
  }

  if (params[@"limitToFirst"]) {
    query = [query limitToFirst:[params[@"limitToFirst"] integerValue]];
    [params removeObjectForKey:@"limitToFirst"];
  }
  if (params[@"limitToLast"]) {
    query = [query limitToLast:[params[@"limitToLast"] integerValue]];
    [params removeObjectForKey:@"limitToLast"];
  }

  [params removeObjectForKey:@"tag"];
  if ([params count] > 0) {
    XCTFail(@"Unsupported query parameter: %@", params);
  }
  return [[FQuerySpec alloc] initWithPath:path params:query];
}

- (void)runTest:(NSDictionary *)testSpec atBasePath:(NSString *)basePath {
  NSMutableDictionary *listens = [[NSMutableDictionary alloc] init];
  __weak FSyncPointTests *weakSelf = self;

  FListenProvider *listenProvider = [[FListenProvider alloc] init];
  listenProvider.startListening = ^(FQuerySpec *query, NSNumber *tagId, id<FSyncTreeHash> hash,
                                    fbt_nsarray_nsstring onComplete) {
    FQueryParams *queryParams = query.params;
    FPath *path = query.path;
    NSString *logTag = [NSString stringWithFormat:@"%@ (%@)", queryParams, tagId];
    NSString *key = [weakSelf queryKeyForQuery:query tagId:tagId];
    FFLog(@"I-RDB143001", @"Listening at %@ for %@", path, logTag);
    id existing = listens[key];
    NSAssert(existing == nil, @"Duplicate listen");
    listens[key] = @YES;
    return @[];
  };

  listenProvider.stopListening = ^(FQuerySpec *query, NSNumber *tagId) {
    FQueryParams *queryParams = query.params;
    FPath *path = query.path;
    NSString *logTag = [NSString stringWithFormat:@"%@ (%@)", queryParams, tagId];
    NSString *key = [weakSelf queryKeyForQuery:query tagId:tagId];
    FFLog(@"I-RDB143002", @"Stop listening at %@ for %@", path, logTag);
    id existing = listens[key];
    XCTAssertTrue(existing != nil, @"Missing record of query that we're removing");
    [listens removeObjectForKey:key];
  };

  FSyncTree *syncTree = [[FSyncTree alloc] initWithListenProvider:listenProvider];

  NSLog(@"Running %@", testSpec[@"name"]);
  NSInteger currentWriteId = 0;
  for (NSDictionary *step in testSpec[@"steps"]) {
    NSMutableDictionary *spec = [step mutableCopy];
    if (spec[@".comment"]) {
      NSLog(@" > %@", spec[@".comment"]);
    }
    if (spec[@"debug"] != nil) {
      // TODO: Ideally we'd pause the debugger somehow (like "debugger;" in JS).
      NSLog(@"Start debugging");
    }
    // Almost everything has a path...
    FPath *path = [FPath empty];
    if (basePath != nil) {
      path = [path childFromString:basePath];
    }
    if (spec[@"path"] != nil) {
      path = [path childFromString:spec[@"path"]];
    }
    NSArray *events;
    if ([spec[@"type"] isEqualToString:@"listen"]) {
      FQuerySpec *query = [self parseParams:spec[@"params"] forPath:path];
      FTestEventRegistration *eventRegistration =
          [[FTestEventRegistration alloc] initWithSpec:spec query:query];
      events = [syncTree addEventRegistration:eventRegistration forQuery:query];
      [self actualEvents:events exactMatchesExpected:spec[@"events"]];

    } else if ([spec[@"type"] isEqualToString:@"unlisten"]) {
      FQuerySpec *query = [self parseParams:spec[@"params"] forPath:path];
      FTestEventRegistration *eventRegistration =
          [[FTestEventRegistration alloc] initWithSpec:spec query:query];
      events = [syncTree removeEventRegistration:eventRegistration forQuery:query cancelError:nil];
      [self actualEvents:events exactMatchesExpected:spec[@"events"]];

    } else if ([spec[@"type"] isEqualToString:@"serverUpdate"]) {
      id<FNode> update = [FSnapshotUtilities nodeFrom:spec[@"data"]];
      if (spec[@"tag"]) {
        events = [syncTree applyTaggedQueryOverwriteAtPath:path newData:update tagId:spec[@"tag"]];
      } else {
        events = [syncTree applyServerOverwriteAtPath:path newData:update];
      }
      [self actualEventSet:events matchesExpected:spec[@"events"] atBasePath:basePath];

    } else if ([spec[@"type"] isEqualToString:@"serverMerge"]) {
      FCompoundWrite *compoundWrite =
          [FCompoundWrite compoundWriteWithValueDictionary:spec[@"data"]];
      if (spec[@"tag"]) {
        events = [syncTree applyTaggedQueryMergeAtPath:path
                                       changedChildren:compoundWrite
                                                 tagId:spec[@"tag"]];
      } else {
        events = [syncTree applyServerMergeAtPath:path changedChildren:compoundWrite];
      }
      [self actualEventSet:events matchesExpected:spec[@"events"] atBasePath:basePath];

    } else if ([spec[@"type"] isEqualToString:@"set"]) {
      id<FNode> toSet = [FSnapshotUtilities nodeFrom:spec[@"data"]];
      BOOL visible = (spec[@"visible"] != nil) ? [spec[@"visible"] boolValue] : YES;
      events = [syncTree applyUserOverwriteAtPath:path
                                          newData:toSet
                                          writeId:currentWriteId++
                                        isVisible:visible];
      [self actualEventSet:events matchesExpected:spec[@"events"] atBasePath:basePath];

    } else if ([spec[@"type"] isEqualToString:@"update"]) {
      FCompoundWrite *compoundWrite =
          [FCompoundWrite compoundWriteWithValueDictionary:spec[@"data"]];
      events = [syncTree applyUserMergeAtPath:path
                              changedChildren:compoundWrite
                                      writeId:currentWriteId++];
      [self actualEventSet:events matchesExpected:spec[@"events"] atBasePath:basePath];
    } else if ([spec[@"type"] isEqualToString:@"ackUserWrite"]) {
      NSInteger writeId = [spec[@"writeId"] integerValue];
      BOOL revert = [spec[@"revert"] boolValue];
      events = [syncTree ackUserWriteWithWriteId:writeId
                                          revert:revert
                                         persist:YES
                                           clock:[[FTestClock alloc] init]];
      [self actualEventSet:events matchesExpected:spec[@"events"] atBasePath:basePath];
    } else if ([spec[@"type"] isEqualToString:@"suppressWarning"]) {
      // Do nothing. This is a hack so JS's Jasmine tests don't throw warnings for "expect no
      // errors" tests.
    } else {
      XCTFail(@"Unknown step: %@", spec[@"type"]);
    }
  }
}

- (NSArray *)loadSpecs {
  static NSArray *json;
#if SWIFT_PACKAGE
  NSBundle *bundle = Firebase_DatabaseUnit_SWIFTPM_MODULE_BUNDLE();
#else
  NSBundle *bundle = [NSBundle bundleForClass:[FSyncPointTests class]];
#endif
  if (json == nil) {
    NSString *syncPointSpec = [bundle pathForResource:@"syncPointSpec" ofType:@"json"];
    NSLog(@"%@", syncPointSpec);
    NSData *specData = [NSData dataWithContentsOfFile:syncPointSpec];
    NSError *error = nil;
    json = [NSJSONSerialization JSONObjectWithData:specData options:kNilOptions error:&error];

    if (error) {
      XCTFail(@"Error occurred parsing JSON: %@", error);
    }
  }

  return json;
}

- (NSDictionary *)specsForName:(NSString *)name {
  for (NSDictionary *spec in [self loadSpecs]) {
    if ([name isEqualToString:spec[@"name"]]) {
      return spec;
    }
  }

  XCTFail(@"No such test: %@", name);
  return nil;
}

- (void)runTestForName:(NSString *)name {
  NSDictionary *spec = [self specsForName:name];
  [self runTest:spec atBasePath:nil];
  // run again at a deeper location
  [self runTest:spec atBasePath:@"/foo/bar/baz"];
}

- (void)testAll {
  NSArray *specs = [self loadSpecs];
  for (NSDictionary *spec in specs) {
    [self runTest:spec atBasePath:nil];
    // run again at a deeper location
    [self runTest:spec atBasePath:@"/foo/bar/baz"];
  }
}

- (void)testDefaultListenHandlesParentSet {
  [self runTestForName:@"Default listen handles a parent set"];
}

- (void)testDefaultListenHandlesASetAtTheSameLevel {
  [self runTestForName:@"Default listen handles a set at the same level"];
}

- (void)testAQueryCanGetACompleteCacheThenAMerge {
  [self runTestForName:@"A query can get a complete cache then a merge"];
}

- (void)testServerMergeOnListenerWithCompleteChildren {
  [self runTestForName:@"Server merge on listener with complete children"];
}

- (void)testDeepMergeOnListenerWithCompleteChildren {
  [self runTestForName:@"Deep merge on listener with complete children"];
}

- (void)testUpdateChildListenerTwice {
  [self runTestForName:@"Update child listener twice"];
}

- (void)testChildOfDefaultListenThatAlreadyHasACompleteCache {
  [self runTestForName:@"Update child of default listen that already has a complete cache"];
}

- (void)testUpdateChildOfDefaultListenThatHasNoCache {
  [self runTestForName:@"Update child of default listen that has no cache"];
}

// failing
- (void)testUpdateTheChildOfACoLocatedDefaultListenerAndQuery {
  [self runTestForName:@"Update (via set) the child of a co-located default listener and query"];
}

- (void)testUpdateTheChildOfAQueryWithAFullCache {
  [self runTestForName:@"Update (via set) the child of a query with a full cache"];
}

- (void)testUpdateAChildBelowAnEmptyQuery {
  [self runTestForName:@"Update (via set) a child below an empty query"];
}

- (void)testUpdateDescendantOfDefaultListenerWithFullCache {
  [self runTestForName:@"Update descendant of default listener with full cache"];
}

- (void)testDescendantSetBelowAnEmptyDefaultLIstenerIsIgnored {
  [self runTestForName:@"Descendant set below an empty default listener is ignored"];
}

- (void)testUpdateOfAChild {
  [self runTestForName:
            @"Update of a child. This can happen if a child listener is added and removed"];
}

- (void)testRevertSetWithOnlyChildCaches {
  [self runTestForName:@"Revert set with only child caches"];
}

- (void)testCanRevertADuplicateChildSet {
  [self runTestForName:@"Can revert a duplicate child set"];
}

- (void)testCanRevertAChildSetAndSeeTheUnderlyingData {
  [self runTestForName:@"Can revert a child set and see the underlying data"];
}

- (void)testRevertChildSetWithNoServerData {
  [self runTestForName:@"Revert child set with no server data"];
}

- (void)testRevertDeepSetWithNoServerData {
  [self runTestForName:@"Revert deep set with no server data"];
}

- (void)testRevertSetCoveredByNonvisibleTransaction {
  [self runTestForName:@"Revert set covered by non-visible transaction"];
}

- (void)testClearParentShadowingServerValuesSetWithServerChildren {
  [self runTestForName:@"Clear parent shadowing server values set with server children"];
}

- (void)testClearChildShadowingServerValuesSetWithServerChildren {
  [self runTestForName:@"Clear child shadowing server values set with server children"];
}

- (void)testUnrelatedMergeDoesntShadowServerUpdates {
  [self runTestForName:@"Unrelated merge doesn't shadow server updates"];
}

- (void)testCanSetAlongsideARemoteMerge {
  [self runTestForName:@"Can set alongside a remote merge"];
}

- (void)testSetPriorityOnALocationWithNoCache {
  [self runTestForName:@"setPriority on a location with no cache"];
}

- (void)testDeepUpdateDeletesChildFromLimitWindowAndPullsInNewChild {
  [self runTestForName:@"deep update deletes child from limit window and pulls in new child"];
}

- (void)testDeepSetDeletesChildFromLimitWindowAndPullsInNewChild {
  [self runTestForName:@"deep set deletes child from limit window and pulls in new child"];
}

- (void)testEdgeCaseInNewChildForChange {
  [self runTestForName:@"Edge case in newChildForChange_"];
}

- (void)testRevertSetInQueryWindow {
  [self runTestForName:@"Revert set in query window"];
}

- (void)testHandlesAServerValueMovingAChildOutOfAQueryWindow {
  [self runTestForName:@"Handles a server value moving a child out of a query window"];
}

- (void)testUpdateOfIndexedChildWorks {
  [self runTestForName:@"Update of indexed child works"];
}

- (void)testMergeAppliedToEmptyLimit {
  [self runTestForName:@"Merge applied to empty limit"];
}

- (void)testLimitIsRefilledFromServerDataAfterMerge {
  [self runTestForName:@"Limit is refilled from server data after merge"];
}

- (void)testHandleRepeatedListenWithMergeAsFirstUpdate {
  [self runTestForName:@"Handle repeated listen with merge as first update"];
}

- (void)testLimitIsRefilledFromServerDataAfterSet {
  [self runTestForName:@"Limit is refilled from server data after set"];
}

- (void)testQueryOnWeirdPath {
  [self runTestForName:@"query on weird path."];
}

- (void)testRunsRound2 {
  [self runTestForName:@"runs, round2"];
}

- (void)testHandlesNestedListens {
  [self runTestForName:@"handles nested listens"];
}

- (void)testHandlesASetBelowAListen {
  [self runTestForName:@"Handles a set below a listen"];
}

- (void)testDoesNonDefaultQueries {
  [self runTestForName:@"does non-default queries"];
}

- (void)testHandlesCoLocatedDefaultListenerAndQuery {
  [self runTestForName:@"handles a co-located default listener and query"];
}

- (void)testDefaultAndNonDefaultListenerAtSameLocationWithServerUpdate {
  [self runTestForName:@"Default and non-default listener at same location with server update"];
}

- (void)testAddAParentListenerToACompleteChildListenerExpectChildEvent {
  [self runTestForName:@"Add a parent listener to a complete child listener, expect child event"];
}

- (void)testAddListensToASetExpectCorrectEventsIncludingAChildEvent {
  [self runTestForName:@"Add listens to a set, expect correct events, including a child event"];
}

- (void)testServerUpdateToAChildListenerRaisesChildEventsAtParent {
  [self runTestForName:@"ServerUpdate to a child listener raises child events at parent"];
}

- (void)testServerUpdateToAChildListenerRaisesChildEventsAtParentQuery {
  [self runTestForName:@"ServerUpdate to a child listener raises child events at parent query"];
}

- (void)testMultipleCompleteChildrenAreHandleProperly {
  [self runTestForName:@"Multiple complete children are handled properly"];
}

- (void)testWriteLeafNodeOverwriteAtParentNode {
  [self runTestForName:@"Write leaf node, overwrite at parent node"];
}

- (void)testConfirmCompleteChildrenFromTheServer {
  [self runTestForName:@"Confirm complete children from the server"];
}

- (void)testWriteLeafOverwriteFromParent {
  [self runTestForName:@"Write leaf, overwrite from parent"];
}

- (void)testBasicUpdateTest {
  [self runTestForName:@"Basic update test"];
}

- (void)testNoDoubleValueEventsForUserAck {
  [self runTestForName:@"No double value events for user ack"];
}

- (void)testBasicKeyIndexSanityCheck {
  [self runTestForName:@"Basic key index sanity check"];
}

- (void)testCollectCorrectSubviewsToListenOn {
  [self runTestForName:@"Collect correct subviews to listen on"];
}

- (void)testLimitToFirstOneOnOrderedQuery {
  [self runTestForName:@"Limit to first one on ordered query"];
}

- (void)testLimitToLastOneOnOrderedQuery {
  [self runTestForName:@"Limit to last one on ordered query"];
}

- (void)testUpdateIndexedValueOnExistingChildFromLimitedQuery {
  [self runTestForName:@"Update indexed value on existing child from limited query"];
}

- (void)testCanCreateStartAtEndAtEqualToQueriesWithBool {
  [self runTestForName:@"Can create startAt, endAt, equalTo queries with bool"];
}

- (void)testQueryWithExistingServerSnap {
  [self runTestForName:@"Query with existing server snap"];
}

- (void)testServerDataIsNotPurgedForNonServerIndexedQueries {
  [self runTestForName:@"Server data is not purged for non-server-indexed queries"];
}

- (void)testStartAtEndAtDominatesLimit {
  [self runTestForName:@"startAt/endAt dominates limit"];
}

- (void)testUpdateToSingleChildThatMovesOutOfWindow {
  [self runTestForName:@"Update to single child that moves out of window"];
}

- (void)testLimitedQueryDoesntPullInOutOfRangeChild {
  [self runTestForName:@"Limited query doesn't pull in out of range child"];
}

- (void)testWithCustomOrderByIsRefilledWithCorrectItem {
  [self runTestForName:@"Limit with custom orderBy is refilled with correct item"];
}

- (void)testMergeForLocationWithDefaultAndLimitedListener {
  [self runTestForName:@"Merge for location with default and limited listener"];
}

- (void)testUserMergePullsInCorrectValues {
  [self runTestForName:@"User merge pulls in correct values"];
}

- (void)testUserDeepSetPullsInCorrectValues {
  [self runTestForName:@"User deep set pulls in correct values"];
}

- (void)testQueriesWithEqualToNullWork {
  [self runTestForName:@"Queries with equalTo(null) work"];
}

- (void)testRevertedWritesUpdateQuery {
  [self runTestForName:@"Reverted writes update query"];
}

- (void)testDeepSetForNonLocalDataDoesntRaiseEvents {
  [self runTestForName:@"Deep set for non-local data doesn't raise events"];
}

- (void)testUserUpdateWithNewChildrenTriggersEvents {
  [self runTestForName:@"User update with new children triggers events"];
}

- (void)testUserWriteWithDeepOverwrite {
  [self runTestForName:@"User write with deep user overwrite"];
}

- (void)testServerUpdatesPriority {
  [self runTestForName:@"Server updates priority"];
}

- (void)testRevertFullUnderlyingWrite {
  [self runTestForName:@"Revert underlying full overwrite"];
}

- (void)testUserChildOverwriteForNonexistentServerNode {
  [self runTestForName:@"User child overwrite for non-existent server node"];
}

- (void)testRevertUserOverwriteOfChildOnLeafNode {
  [self runTestForName:@"Revert user overwrite of child on leaf node"];
}

- (void)testServerOverwriteWithDeepUserDelete {
  [self runTestForName:@"Server overwrite with deep user delete"];
}

- (void)testUserOverwritesLeafNodeWithPriority {
  [self runTestForName:@"User overwrites leaf node with priority"];
}

- (void)testUserOverwritesInheritPriorityValuesFromLeafNodes {
  [self runTestForName:@"User overwrites inherit priority values from leaf nodes"];
}

- (void)testUserUpdateOnUserSetLeafNodeWithPriorityAfterServerUpdate {
  [self runTestForName:@"User update on user set leaf node with priority after server update"];
}

- (void)testServerDeepDeleteOnLeafNode {
  [self runTestForName:@"Server deep delete on leaf node"];
}

- (void)testUserSetsRootPriority {
  [self runTestForName:@"User sets root priority"];
}

- (void)testUserUpdatesPriorityOnEmptyRoot {
  [self runTestForName:@"User updates priority on empty root"];
}

- (void)testRevertSetAtRootWithPriority {
  [self runTestForName:@"Revert set at root with priority"];
}

- (void)testServerUpdatesPriorityAfterUserSetsPriority {
  [self runTestForName:@"Server updates priority after user sets priority"];
}

- (void)testEmptySetDoesntPreventServerUpdates {
  [self runTestForName:@"Empty set doesn't prevent server updates"];
}

- (void)testUserUpdatesPriorityTwiceFirstIsReverted {
  [self runTestForName:@"User updates priority twice, first is reverted"];
}

- (void)testServerAcksRootPrioritySetAfterUserDeletesRootNode {
  [self runTestForName:@"Server acks root priority set after user deletes root node"];
}

- (void)testADeleteInAMergeDoesntPushOutNodes {
  [self runTestForName:@"A delete in a merge doesn't push out nodes"];
}

- (void)testATaggedQueryFiresEventsEventually {
  [self runTestForName:@"A tagged query fires events eventually"];
}

- (void)testUserWriteOutsideOfLimitIsIgnoredForTaggedQueries {
  [self runTestForName:@"User write outside of limit is ignored for tagged queries"];
}

- (void)testAckForMergeDoesntRaiseValueEventForLaterListen {
  [self runTestForName:@"Ack for merge doesn't raise value event for later listen"];
}

- (void)testClearParentShadowingServerValuesMergeWithServerChildren {
  [self runTestForName:@"Clear parent shadowing server values merge with server children"];
}

- (void)testPrioritiesDontMakeMeSick {
  [self runTestForName:@"Priorities don't make me sick"];
}

- (void)testMergeThatMovesChildFromWindowToBoundaryDoesNotCauseChildToBeReadded {
  [self runTestForName:
            @"Merge that moves child from window to boundary does not cause child to be readded"];
}

- (void)testDeepMergeAckIsHandledCorrectly {
  [self runTestForName:@"Deep merge ack is handled correctly."];
}

- (void)testDeepMergeAckOnIncompleteDataAndWithServerValues {
  [self runTestForName:@"Deep merge ack (on incomplete data, and with server values)"];
}

- (void)testLimitQueryHandlesDeepServerMergeForOutOfViewItem {
  [self runTestForName:@"Limit query handles deep server merge for out-of-view item."];
}

- (void)testLimitQueryHandlesDeepUserMergeForOutOfViewItem {
  [self runTestForName:@"Limit query handles deep user merge for out-of-view item."];
}

- (void)testLimitQueryHandlesDeepUserMergeForOutOfViewItemFollowedByServerUpdate {
  [self runTestForName:
            @"Limit query handles deep user merge for out-of-view item followed by server update."];
}

- (void)testUnrelatedUntaggedUpdateIsNotCachedInTaggedListen {
  [self runTestForName:@"Unrelated, untagged update is not cached in tagged listen"];
}

- (void)testUnrelatedAckedSetIsNotCachedInTaggedListen {
  [self runTestForName:@"Unrelated, acked set is not cached in tagged listen"];
}

- (void)testUnrelatedAckedUpdateIsNotCachedInTaggedListen {
  [self runTestForName:@"Unrelated, acked update is not cached in tagged listen"];
}

- (void)testdeepUpdateRaisesImmediateEventsOnlyIfHasCompleteData {
  [self runTestForName:@"Deep update raises immediate events only if has complete data"];
}

- (void)testdeepUpdateReturnsMinimumDataRequired {
  [self runTestForName:@"Deep update returns minimum data required"];
}

- (void)testdeepUpdateRaisesAllEvents {
  [self runTestForName:@"Deep update raises all events"];
}

@end
