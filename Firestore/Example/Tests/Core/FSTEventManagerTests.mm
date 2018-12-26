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

#import "Firestore/Source/Core/FSTEventManager.h"

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSyncEngine.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/model/types.h"

using firebase::firestore::model::OnlineState;

NS_ASSUME_NONNULL_BEGIN

/**
 * Converts an OnlineState to an NSNumber, usually for the purpose of adding
 * it to an NSArray or similar container. There's no direct conversion from a
 * strongly-typed enum to an integral type that could be passed to an NSNumber
 * initializer.
 */
static NSNumber *ToNSNumber(OnlineState state) {
  return @(static_cast<std::underlying_type<OnlineState>::type>(state));
}

// FSTEventManager implements this delegate privately
@interface FSTEventManager () <FSTSyncEngineDelegate>
@end

@interface FSTEventManagerTests : XCTestCase
@end

@implementation FSTEventManagerTests

- (FSTQueryListener *)noopListenerForQuery:(FSTQuery *)query {
  return [[FSTQueryListener alloc]
            initWithQuery:query
                  options:[FSTListenOptions defaultOptions]
      viewSnapshotHandler:^(FSTViewSnapshot *_Nullable snapshot, NSError *_Nullable error){
      }];
}

- (void)testHandlesManyListenersPerQuery {
  FSTQuery *query = FSTTestQuery("foo/bar");
  FSTQueryListener *listener1 = [self noopListenerForQuery:query];
  FSTQueryListener *listener2 = [self noopListenerForQuery:query];

  FSTSyncEngine *syncEngineMock = OCMStrictClassMock([FSTSyncEngine class]);
  OCMExpect([syncEngineMock setSyncEngineDelegate:[OCMArg any]]);
  FSTEventManager *eventManager = [FSTEventManager eventManagerWithSyncEngine:syncEngineMock];

  OCMExpect([syncEngineMock listenToQuery:query]);
  [eventManager addListener:listener1];
  OCMVerifyAll((id)syncEngineMock);

  [eventManager addListener:listener2];
  [eventManager removeListener:listener2];

  OCMExpect([syncEngineMock stopListeningToQuery:query]);
  [eventManager removeListener:listener1];
  OCMVerifyAll((id)syncEngineMock);
}

- (void)testHandlesUnlistenOnUnknownListenerGracefully {
  FSTQuery *query = FSTTestQuery("foo/bar");
  FSTQueryListener *listener = [self noopListenerForQuery:query];

  FSTSyncEngine *syncEngineMock = OCMStrictClassMock([FSTSyncEngine class]);
  OCMExpect([syncEngineMock setSyncEngineDelegate:[OCMArg any]]);
  FSTEventManager *eventManager = [FSTEventManager eventManagerWithSyncEngine:syncEngineMock];

  [eventManager removeListener:listener];
  OCMVerifyAll((id)syncEngineMock);
}

- (FSTQueryListener *)makeMockListenerForQuery:(FSTQuery *)query
                           viewSnapshotHandler:(void (^)())handler {
  FSTQueryListener *listener = OCMClassMock([FSTQueryListener class]);
  OCMStub([listener query]).andReturn(query);
  OCMStub([listener queryDidChangeViewSnapshot:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
    handler();
  });
  return listener;
}

- (void)testNotifiesListenersInTheRightOrder {
  FSTQuery *query1 = FSTTestQuery("foo/bar");
  FSTQuery *query2 = FSTTestQuery("bar/baz");
  NSMutableArray *eventOrder = [NSMutableArray array];

  FSTQueryListener *listener1 = [self makeMockListenerForQuery:query1
                                           viewSnapshotHandler:^{
                                             [eventOrder addObject:@"listener1"];
                                           }];

  FSTQueryListener *listener2 = [self makeMockListenerForQuery:query2
                                           viewSnapshotHandler:^{
                                             [eventOrder addObject:@"listener2"];
                                           }];

  FSTQueryListener *listener3 = [self makeMockListenerForQuery:query1
                                           viewSnapshotHandler:^{
                                             [eventOrder addObject:@"listener3"];
                                           }];

  FSTSyncEngine *syncEngineMock = OCMClassMock([FSTSyncEngine class]);
  FSTEventManager *eventManager = [FSTEventManager eventManagerWithSyncEngine:syncEngineMock];

  [eventManager addListener:listener1];
  [eventManager addListener:listener2];
  [eventManager addListener:listener3];
  OCMVerify([syncEngineMock listenToQuery:query1]);
  OCMVerify([syncEngineMock listenToQuery:query2]);

  FSTViewSnapshot *snapshot1 = OCMClassMock([FSTViewSnapshot class]);
  OCMStub([snapshot1 query]).andReturn(query1);
  FSTViewSnapshot *snapshot2 = OCMClassMock([FSTViewSnapshot class]);
  OCMStub([snapshot2 query]).andReturn(query2);

  [eventManager handleViewSnapshots:@[ snapshot1, snapshot2 ]];

  NSArray *expected = @[ @"listener1", @"listener3", @"listener2" ];
  XCTAssertEqualObjects(eventOrder, expected);
}

- (void)testWillForwardOnlineStateChanges {
  FSTQuery *query = FSTTestQuery("foo/bar");
  FSTQueryListener *fakeListener = OCMClassMock([FSTQueryListener class]);
  NSMutableArray *events = [NSMutableArray array];
  OCMStub([fakeListener query]).andReturn(query);
  OCMStub([fakeListener applyChangedOnlineState:OnlineState::Unknown])
      .andDo(^(NSInvocation *invocation) {
        [events addObject:ToNSNumber(OnlineState::Unknown)];
      });
  OCMStub([fakeListener applyChangedOnlineState:OnlineState::Online])
      .andDo(^(NSInvocation *invocation) {
        [events addObject:ToNSNumber(OnlineState::Online)];
      });

  FSTSyncEngine *syncEngineMock = OCMClassMock([FSTSyncEngine class]);
  OCMExpect([syncEngineMock setSyncEngineDelegate:[OCMArg any]]);
  FSTEventManager *eventManager = [FSTEventManager eventManagerWithSyncEngine:syncEngineMock];

  [eventManager addListener:fakeListener];
  XCTAssertEqualObjects(events, @[ ToNSNumber(OnlineState::Unknown) ]);
  [eventManager applyChangedOnlineState:OnlineState::Online];
  XCTAssertEqualObjects(events,
                        (@[ ToNSNumber(OnlineState::Unknown), ToNSNumber(OnlineState::Online) ]));
}

@end

NS_ASSUME_NONNULL_END
