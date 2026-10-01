/*
 * Copyright 2026 Google LLC
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

#import "FirebaseDatabase/Sources/Api/FIRDatabaseConfig.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FPersistentConnection.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FPersistentConnectionTestDouble : FPersistentConnection

@property(nonatomic, strong) NSMutableArray<NSString *> *interruptedReasons;
@property(nonatomic, strong) NSMutableArray<NSString *> *resumedReasons;

@end

@implementation FPersistentConnectionTestDouble

- (void)interruptForReason:(NSString *)reason {
  [self.interruptedReasons addObject:reason];
}

- (void)resumeForReason:(NSString *)reason {
  [self.resumedReasons addObject:reason];
}

@end

@interface FPersistentConnection (Testing)

- (void)systemClockDidChange:(NSNotification *)notification;
- (void)onDataPushWithAction:(NSString *)action andBody:(NSDictionary *)body;

@end

@interface FPersistentConnectionTests : XCTestCase

@property(nonatomic, strong) FPersistentConnectionTestDouble *connection;
@property(nonatomic, strong) dispatch_queue_t connectionQueue;

@end

@implementation FPersistentConnectionTests

- (void)setUp {
  [super setUp];
  self.connectionQueue = dispatch_queue_create(
      "com.google.firebase.database.PersistentConnectionTests", DISPATCH_QUEUE_SERIAL);
  FRepoInfo *repoInfo = [[FRepoInfo alloc] initWithHost:@"example.firebaseio.com"
                                               isSecure:YES
                                          withNamespace:@"example"];
  self.connection =
      [[FPersistentConnectionTestDouble alloc] initWithRepoInfo:repoInfo
                                                  dispatchQueue:self.connectionQueue
                                                         config:[FTestHelpers defaultConfig]];
  self.connection.interruptedReasons = [NSMutableArray array];
  self.connection.resumedReasons = [NSMutableArray array];
}

- (void)testSystemClockChangeRestartsConnection {
  [self.connection systemClockDidChange:nil];
  [self waitForConnectionQueue];

  [self assertConnectionRestartedForSystemClockChange];
}

- (void)testSystemClockDidChangeNotificationRestartsConnection {
  [[NSNotificationCenter defaultCenter] postNotificationName:NSSystemClockDidChangeNotification
                                                      object:nil];
  [self waitForConnectionQueue];

  [self assertConnectionRestartedForSystemClockChange];
}

// A server frame is parsed straight from JSON, so a malformed message (wrong
// JSON type for the envelope, the push body, or a nested field) must be ignored
// rather than crash the client with an unrecognized selector.
- (void)testNonDictionaryDataMessageIsIgnored {
  XCTAssertNoThrow([self.connection onDataMessage:nil withMessage:(id) @[ @1, @2 ]]);
  XCTAssertNoThrow([self.connection onDataMessage:nil withMessage:(id) @"not a dict"]);
}

- (void)testMalformedServerPushIsIgnored {
  // Body is not a JSON object.
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerDataUpdate
                                                 andBody:(id) @"not a dict"]);
  // Action is not a string.
  XCTAssertNoThrow([self.connection onDataPushWithAction:(id) @5 andBody:@{}]);
  // Data update with a non-string path.
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerDataUpdate
                                                 andBody:@{
                                                   kFWPAsyncServerDataUpdateBodyPath : @42,
                                                   kFWPAsyncServerDataUpdateBodyData : @"value"
                                                 }]);
  // Range merge whose ranges are not an array.
  XCTAssertNoThrow([self.connection
      onDataPushWithAction:kFWPAsyncServerDataRangeMerge
                   andBody:@{
                     kFWPAsyncServerDataUpdateBodyPath : @"/",
                     kFWPAsyncServerDataUpdateBodyData : @"not an array"
                   }]);
  // Range merge whose range elements are not dictionaries.
  XCTAssertNoThrow([self.connection
      onDataPushWithAction:kFWPAsyncServerDataRangeMerge
                   andBody:@{
                     kFWPAsyncServerDataUpdateBodyPath : @"/",
                     kFWPAsyncServerDataUpdateBodyData : @[ @"not a dict" ]
                   }]);
  // Listen cancel with a non-string path.
  XCTAssertNoThrow([self.connection
      onDataPushWithAction:kFWPASyncServerListenCancelled
                   andBody:@{kFWPAsyncServerDataUpdateBodyPath : @99}]);
}

- (void)waitForConnectionQueue {
  dispatch_sync(self.connectionQueue, ^{
                });
}

- (void)assertConnectionRestartedForSystemClockChange {
  XCTAssertEqualObjects(self.connection.interruptedReasons,
                        (@[ kFInterruptReasonSystemClockChange ]));
  XCTAssertEqualObjects(self.connection.resumedReasons, (@[ kFInterruptReasonSystemClockChange ]));
}

@end
