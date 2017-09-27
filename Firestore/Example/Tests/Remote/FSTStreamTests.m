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

#import "Remote/FSTDatastore.h"

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "Auth/FSTEmptyCredentialsProvider.h"
#import "Core/FSTDatabaseInfo.h"
#import "Model/FSTDatabaseID.h"
#import "Protos/objc/google/firestore/v1beta1/Firestore.pbrpc.h"
#import "Util/FSTDispatchQueue.h"

/** Expose otherwise private methods for testing. */
@interface FSTStream (Testing)

- (void)writesFinishedWithError:(NSError *_Nullable)error;

@end

@interface FSTStreamTests : XCTestCase
@end

@implementation FSTStreamTests {
  dispatch_queue_t _testQueue;
  FSTDatabaseInfo *_databaseInfo;
  FSTDispatchQueue *_workerDispatchQueue;
  id<FSTCredentialsProvider> _credentials;
}

- (void)setUp {
  [super setUp];

  FSTDatabaseID *databaseID =
      [FSTDatabaseID databaseIDWithProject:@"project" database:kDefaultDatabaseID];
  _databaseInfo = [FSTDatabaseInfo databaseInfoWithDatabaseID:databaseID
                                               persistenceKey:@"test"
                                                         host:@"test-host"
                                                   sslEnabled:NO];

  _testQueue = dispatch_queue_create("com.firebase.testing", DISPATCH_QUEUE_SERIAL);
  _workerDispatchQueue = [FSTDispatchQueue queueWith:_testQueue];
  _credentials = [[FSTEmptyCredentialsProvider alloc] init];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testWatchStreamStop {
  id delegate = OCMStrictProtocolMock(@protocol(FSTWatchStreamDelegate));

  FSTWatchStream *stream =
      OCMPartialMock([[FSTWatchStream alloc] initWithDatabase:_databaseInfo
                                          workerDispatchQueue:_workerDispatchQueue
                                                  credentials:_credentials
                                         responseMessageClass:[GCFSWriteResponse class]
                                                     delegate:delegate]);
  OCMStub([stream createRPCWithRequestsWriter:[OCMArg any]]).andReturn(nil);

  // Start the stream up but that's not really the interesting bit. This is complicated by the fact
  // that startup involves redispatching after credentials are returned.
  dispatch_semaphore_t openCompleted = dispatch_semaphore_create(0);
  OCMStub([delegate watchStreamDidOpen]).andDo(^(NSInvocation *invocation) {
    dispatch_semaphore_signal(openCompleted);
  });
  dispatch_async(_testQueue, ^{
    [stream start];
  });
  dispatch_semaphore_wait(openCompleted, DISPATCH_TIME_FOREVER);
  OCMVerifyAll(delegate);

  // Stop must not call watchStreamDidClose because the full implementation of the delegate could
  // attempt to restart the stream in the event it had pending watches.
  dispatch_sync(_testQueue, ^{
    [stream stop];
  });
  OCMVerifyAll(delegate);

  // Simulate a final callback from GRPC
  [stream writesFinishedWithError:nil];
  // Drain queue
  dispatch_sync(_testQueue, ^{
                });
  OCMVerifyAll(delegate);
}

- (void)testWriteStreamStop {
  id delegate = OCMStrictProtocolMock(@protocol(FSTWriteStreamDelegate));

  FSTWriteStream *stream =
      OCMPartialMock([[FSTWriteStream alloc] initWithDatabase:_databaseInfo
                                          workerDispatchQueue:_workerDispatchQueue
                                                  credentials:_credentials
                                         responseMessageClass:[GCFSWriteResponse class]
                                                     delegate:delegate]);
  OCMStub([stream createRPCWithRequestsWriter:[OCMArg any]]).andReturn(nil);

  // Start the stream up but that's not really the interesting bit.
  dispatch_semaphore_t openCompleted = dispatch_semaphore_create(0);
  OCMStub([delegate writeStreamDidOpen]).andDo(^(NSInvocation *invocation) {
    dispatch_semaphore_signal(openCompleted);
  });
  dispatch_async(_testQueue, ^{
    [stream start];
  });
  dispatch_semaphore_wait(openCompleted, DISPATCH_TIME_FOREVER);
  OCMVerifyAll(delegate);

  // Stop must not call writeStreamDidClose because the full implementation of this delegate could
  // attempt to restart the stream in the event it had pending writes.
  dispatch_sync(_testQueue, ^{
    [stream stop];
  });
  OCMVerifyAll(delegate);

  // Simulate a final callback from GRPC
  [stream writesFinishedWithError:nil];
  // Drain queue
  dispatch_sync(_testQueue, ^{
                });
  OCMVerifyAll(delegate);
}

@end
