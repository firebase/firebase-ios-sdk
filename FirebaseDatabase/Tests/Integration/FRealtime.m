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

#import "FirebaseDatabase/Tests/Integration/FRealtime.h"
#import "FirebaseDatabase/Sources/Core/FRepoManager.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/Utilities/FParsedUrl.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleFirebase.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@implementation FRealtime

- (void)testUrlParsing {
  FParsedUrl *parsed = [FUtilities parseUrl:@"http://www.example.com:9000"];
  XCTAssertTrue([[parsed.path description] isEqualToString:@"/"], @"Got correct path");
  XCTAssertTrue([parsed.repoInfo.host isEqualToString:@"www.example.com:9000"],
                @"Got correct host");
  XCTAssertTrue([parsed.repoInfo.internalHost isEqualToString:@"www.example.com:9000"],
                @"Got correct host");
  XCTAssertFalse(parsed.repoInfo.secure, @"Should not be secure, there's a port");

  parsed = [FUtilities parseUrl:@"http://www.firebaseio.com/foo/bar"];
  XCTAssertTrue([[parsed.path description] isEqualToString:@"/foo/bar"], @"Got correct path");
  XCTAssertTrue([parsed.repoInfo.host isEqualToString:@"www.firebaseio.com"], @"Got correct host");
  XCTAssertTrue([parsed.repoInfo.internalHost isEqualToString:@"www.firebaseio.com"],
                @"Got correct host");
  XCTAssertTrue(parsed.repoInfo.secure, @"Should be secure, there's no port");
}

- (void)testCachingRedirects {
  NSString *host = @"host.example.com";
  NSString *host2 = @"host2.example.com";
  NSString *internalHost = @"internal.example.com";
  NSString *internalHost2 = @"internal2.example.com";

  // Set host on first repo info
  FRepoInfo *repoInfo = [[FRepoInfo alloc] initWithHost:host isSecure:YES withNamespace:host];
  XCTAssertTrue([repoInfo.host isEqualToString:host], @"Got correct host");
  XCTAssertTrue([repoInfo.internalHost isEqualToString:host], @"Got correct host");

  // Set internal host on first repo info
  repoInfo.internalHost = internalHost;
  XCTAssertTrue([repoInfo.host isEqualToString:host], @"Got correct host");
  XCTAssertTrue([repoInfo.internalHost isEqualToString:internalHost], @"Got correct host");

  // Set up a second unrelated repo info to make sure caching is keyspaced properly
  FRepoInfo *repoInfo2 = [[FRepoInfo alloc] initWithHost:host2 isSecure:YES withNamespace:host2];
  XCTAssertTrue([repoInfo2.host isEqualToString:host2], @"Got correct host");
  XCTAssertTrue([repoInfo2.internalHost isEqualToString:host2], @"Got correct host");

  repoInfo2.internalHost = internalHost2;
  XCTAssertTrue([repoInfo2.internalHost isEqualToString:internalHost2], @"Got correct host");

  // Setting host on this repo info should also set the right internal host
  FRepoInfo *repoInfoCached = [[FRepoInfo alloc] initWithHost:host isSecure:YES withNamespace:host];
  XCTAssertTrue([repoInfoCached.host isEqualToString:host], @"Got correct host");
  XCTAssertTrue([repoInfoCached.internalHost isEqualToString:internalHost], @"Got correct host");

  [repoInfo clearInternalHostCache];
  [repoInfo2 clearInternalHostCache];
  [repoInfoCached clearInternalHostCache];

  XCTAssertTrue([repoInfo.internalHost isEqualToString:host], @"Got correct host");
  XCTAssertTrue([repoInfo2.internalHost isEqualToString:host2], @"Got correct host");
  XCTAssertTrue([repoInfoCached.internalHost isEqualToString:host], @"Got correct host");
}

- (void)testOnDisconnectSetWorks {
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseConfig *readerCfg = [FTestHelpers configForName:@"reader"];

  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] childByAutoId];
  FIRDatabaseReference *reader =
      [[[FTestHelpers databaseForConfig:readerCfg] reference] child:writer.key];

  __block NSNumber *readValue = @0;
  __block NSNumber *writeValue = @0;
  [[reader child:@"disconnected"] observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           NSNumber *val = [snapshot value];
                                           if (![val isEqual:[NSNull null]]) {
                                             readValue = val;
                                           }
                                         }];

  [[writer child:@"disconnected"] observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           id val = [snapshot value];
                                           if (val != [NSNull null]) {
                                             writeValue = val;
                                           }
                                         }];

  [writer child:@"hello"];

  __block BOOL ready = NO;
  [[writer child:@"disconnected"]
      onDisconnectSetValue:@1
       withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
         ready = YES;
       }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  [writer child:@"s"];

  ready = NO;
  [[writer child:@"disconnected"]
      onDisconnectSetValue:@2
       withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
         ready = YES;
       }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    return [@2 isEqualToNumber:readValue] && [@2 isEqualToNumber:writeValue];
  }];

  [FRepoManager interrupt:readerCfg];

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
  [FRepoManager disposeRepos:readerCfg];
}

- (void)testOnDisconnectSetWithPriorityWorks {
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseConfig *readerCfg = [FTestHelpers configForName:@"reader"];

  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] childByAutoId];
  FIRDatabaseReference *reader =
      [[[FTestHelpers databaseForConfig:readerCfg] reference] child:writer.key];

  __block BOOL sawNewValue = NO;
  __block BOOL writerSawNewValue = NO;
  [[reader child:@"disconnected"] observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           id val = snapshot.value;
                                           id pri = snapshot.priority;
                                           if (val != [NSNull null] && pri != [NSNull null]) {
                                             sawNewValue = [(NSNumber *)val boolValue] &&
                                                           [pri isEqualToString:@"abcd"];
                                           }
                                         }];

  [[writer child:@"disconnected"] observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           id val = [snapshot value];
                                           id pri = snapshot.priority;
                                           if (val != [NSNull null] && pri != [NSNull null]) {
                                             writerSawNewValue = [(NSNumber *)val boolValue] &&
                                                                 [pri isEqualToString:@"abcd"];
                                           }
                                         }];

  __block BOOL ready = NO;
  [[writer child:@"disconnected"]
      onDisconnectSetValue:@YES
               andPriority:@"abcd"
       withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
         ready = YES;
       }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    return sawNewValue && writerSawNewValue;
  }];

  [FRepoManager interrupt:readerCfg];

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
  [FRepoManager disposeRepos:readerCfg];
}

- (void)testOnDisconnectRemoveWorks {
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseConfig *readerCfg = [FTestHelpers configForName:@"reader"];

  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] childByAutoId];
  FIRDatabaseReference *reader =
      [[[FTestHelpers databaseForConfig:readerCfg] reference] child:writer.key];

  __block BOOL ready = NO;
  [[writer child:@"foo"] setValue:@"bar"
              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                ready = YES;
              }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  __block BOOL sawRemove = NO;
  __block BOOL writerSawRemove = NO;
  [[reader child:@"foo"] observeEventType:FIRDataEventTypeValue
                                withBlock:^(FIRDataSnapshot *snapshot) {
                                  sawRemove = [[NSNull null] isEqual:snapshot.value];
                                }];

  [[writer child:@"foo"] observeEventType:FIRDataEventTypeValue
                                withBlock:^(FIRDataSnapshot *snapshot) {
                                  writerSawRemove = [[NSNull null] isEqual:snapshot.value];
                                }];

  ready = NO;
  [[writer child:@"foo"]
      onDisconnectRemoveValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];
  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    return sawRemove && writerSawRemove;
  }];

  [FRepoManager interrupt:readerCfg];

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
  [FRepoManager disposeRepos:readerCfg];
}

- (void)testOnDisconnectUpdateWorks {
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseConfig *readerCfg = [FTestHelpers configForName:@"reader"];

  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] childByAutoId];
  FIRDatabaseReference *reader =
      [[[FTestHelpers databaseForConfig:readerCfg] reference] child:writer.key];

  [self waitForCompletionOf:[writer child:@"foo"] setValue:@{@"bar" : @"a", @"baz" : @"b"}];

  __block BOOL sawNewValue = NO;
  __block BOOL writerSawNewValue = NO;
  [[reader child:@"foo"] observeEventType:FIRDataEventTypeValue
                                withBlock:^(FIRDataSnapshot *snapshot) {
                                  NSDictionary *val = [snapshot value];
                                  if (val) {
                                    sawNewValue = [@{@"bar" : @"a", @"baz" : @"c", @"bat" : @"d"}
                                        isEqualToDictionary:val];
                                  }
                                }];

  [[writer child:@"foo"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               NSDictionary *val = [snapshot value];
               if (val) {
                 writerSawNewValue =
                     [@{@"bar" : @"a", @"baz" : @"c", @"bat" : @"d"} isEqualToDictionary:val];
               }
             }];

  __block BOOL ready = NO;
  [[writer child:@"foo"]
      onDisconnectUpdateChildValues:@{@"baz" : @"c", @"bat" : @"d"}
                withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                  ready = YES;
                }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    return sawNewValue && writerSawNewValue;
  }];

  [FRepoManager interrupt:readerCfg];

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
  [FRepoManager disposeRepos:readerCfg];
}

- (void)testOnDisconnectTriggersSingleLocalValueEventForWriter {
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] childByAutoId];

  __block int calls = 0;
  [writer observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   calls++;
                   if (calls == 2) {
                     // second call, verify the data
                     NSDictionary *val = [snapshot value];
                     NSDictionary *expected = @{@"foo" : @{@"bar" : @"a", @"bam" : @"c"}};
                     XCTAssertTrue([val isEqualToDictionary:expected],
                                   @"Got all of the updates in one");
                   } else if (calls > 2) {
                     XCTFail(@"Extra calls");
                   }
                 }];

  [self waitUntil:^BOOL {
    return calls == 1;
  }];

  __block BOOL done = NO;
  FIRDatabaseReference *child = [writer child:@"foo"];
  [child onDisconnectSetValue:@{@"bar" : @"a", @"baz" : @"b"}];
  [child onDisconnectUpdateChildValues:@{@"bam" : @"c"}];
  [[child child:@"baz"]
      onDisconnectRemoveValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    return calls == 2;
  }];

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
}

- (void)testOnDisconnectTriggersSingleLocalValueEventForReader {
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseReference *reader = [FTestHelpers getRandomNode];
  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] child:reader.key];

  __block int calls = 0;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   calls++;
                   if (calls == 2) {
                     // second call, verify the data
                     NSDictionary *val = [snapshot value];
                     NSDictionary *expected = @{@"foo" : @{@"bar" : @"a", @"bam" : @"c"}};
                     XCTAssertTrue([val isEqualToDictionary:expected],
                                   @"Got all of the updates in one");
                   } else if (calls > 2) {
                     XCTFail(@"Extra calls");
                   }
                 }];

  [self waitUntil:^BOOL {
    return calls == 1;
  }];

  __block BOOL done = NO;
  FIRDatabaseReference *child = [writer child:@"foo"];
  [child onDisconnectSetValue:@{@"bar" : @"a", @"baz" : @"b"}];
  [child onDisconnectUpdateChildValues:@{@"bam" : @"c"}];
  [[child child:@"baz"]
      onDisconnectRemoveValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    return calls == 2;
  }];

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
}

- (void)testOnDisconnectTriggersSingleLocalValueEventForWriterWithQuery {
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] childByAutoId];

  __block int calls = 0;
  [[[writer child:@"foo"] queryLimitedToLast:2]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               calls++;
               if (calls == 2) {
                 // second call, verify the data
                 NSDictionary *val = [snapshot value];
                 NSDictionary *expected = @{@"bar" : @"a", @"bam" : @"c"};
                 XCTAssertTrue([val isEqualToDictionary:expected],
                               @"Got all of the updates in one");
               } else if (calls > 2) {
                 XCTFail(@"Extra calls");
               }
             }];

  [self waitUntil:^BOOL {
    return calls == 1;
  }];

  __block BOOL done = NO;
  FIRDatabaseReference *child = [writer child:@"foo"];
  [child onDisconnectSetValue:@{@"bar" : @"a", @"baz" : @"b"}];
  [child onDisconnectUpdateChildValues:@{@"bam" : @"c"}];
  [[child child:@"baz"]
      onDisconnectRemoveValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    return calls == 2;
  }];

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
}

- (void)testOnDisconnectTriggersSingleLocalValueEventForReaderWithQuery {
  FIRDatabaseReference *reader = [FTestHelpers getRandomNode];
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] child:reader.key];

  __block int calls = 0;
  [[[reader child:@"foo"] queryLimitedToLast:2]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               calls++;
               XCTAssertTrue([snapshot.key isEqualToString:@"foo"], @"Got the right snapshot");
               if (calls == 2) {
                 // second call, verify the data
                 NSDictionary *val = [snapshot value];
                 NSDictionary *expected = @{@"bar" : @"a", @"bam" : @"c"};
                 XCTAssertTrue([val isEqualToDictionary:expected],
                               @"Got all of the updates in one");
               } else if (calls > 2) {
                 XCTFail(@"Extra calls");
               }
             }];

  [self waitUntil:^BOOL {
    return calls == 1;
  }];

  __block BOOL done = NO;
  FIRDatabaseReference *child = [writer child:@"foo"];
  [child onDisconnectSetValue:@{@"bar" : @"a", @"baz" : @"b"}];
  [child onDisconnectUpdateChildValues:@{@"bam" : @"c"}];
  [[child child:@"baz"]
      onDisconnectRemoveValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    return calls == 2;
  }];

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
}

- (void)testOnDisconnectDeepMergeTriggersOnlyOneValueEventForReaderWithQuery {
  FIRDatabaseReference *reader = [FTestHelpers getRandomNode];
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] childByAutoId];

  __block BOOL done = NO;
  NSDictionary *toSet =
      @{@"a" : @1, @"b" : @{@"c" : @YES, @"d" : @"scalar", @"e" : @{@"f" : @"hooray"}}};
  [writer setValue:toSet];
  [[writer child:@"a"] onDisconnectSetValue:@2];
  [[writer child:@"b/d"]
      onDisconnectRemoveValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  WAIT_FOR(done);

  __block int count = 2;
  [[reader queryLimitedToLast:3]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               count++;
               if (count == 1) {
                 // Loaded the data, kill the writer connection
                 [FRepoManager interrupt:writerCfg];
               } else if (count == 2) {
                 NSDictionary *expected =
                     @{@"a" : @2,
                       @"b" : @{@"c" : @YES, @"e" : @{@"f" : @"hooray"}}};
                 XCTAssertTrue([snapshot.value isEqualToDictionary:expected],
                               @"Should see complete new snapshot");
               } else {
                 XCTFail(@"Too many calls");
               }
             }];

  WAIT_FOR(count == 2);

  // cleanup
  [reader removeAllObservers];
  [FRepoManager disposeRepos:writerCfg];
}

- (void)testOnDisconnectCancelWorks {
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseConfig *readerCfg = [FTestHelpers configForName:@"reader"];

  FIRDatabaseReference *writer =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] childByAutoId];
  FIRDatabaseReference *reader =
      [[[FTestHelpers databaseForConfig:readerCfg] reference] child:writer.key];

  __block BOOL ready = NO;
  [[writer child:@"foo"] setValue:@{@"bar" : @"a", @"baz" : @"b"}
              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                ready = YES;
              }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  __block BOOL sawNewValue = NO;
  __block BOOL writerSawNewValue = NO;
  [[reader child:@"foo"] observeEventType:FIRDataEventTypeValue
                                withBlock:^(FIRDataSnapshot *snapshot) {
                                  NSDictionary *val = [snapshot value];
                                  if (val) {
                                    sawNewValue = [@{@"bar" : @"a", @"baz" : @"b", @"bat" : @"d"}
                                        isEqualToDictionary:val];
                                  }
                                }];

  [[writer child:@"foo"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               NSDictionary *val = [snapshot value];
               if (val) {
                 writerSawNewValue =
                     [@{@"bar" : @"a", @"baz" : @"b", @"bat" : @"d"} isEqualToDictionary:val];
               }
             }];

  ready = NO;
  [[writer child:@"foo"] onDisconnectUpdateChildValues:@{@"baz" : @"c", @"bat" : @"d"}];
  [[writer child:@"foo/baz"]
      cancelDisconnectOperationsWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    return sawNewValue && writerSawNewValue;
  }];

  [FRepoManager interrupt:readerCfg];

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
  [FRepoManager disposeRepos:readerCfg];
}

- (void)testOnDisconnectWithServerValuesWithLocalEvents {
  FIRDatabaseConfig *writerCfg = [FTestHelpers configForName:@"writer"];
  FIRDatabaseReference *node =
      [[[FTestHelpers databaseForConfig:writerCfg] reference] childByAutoId];

  __block FIRDataSnapshot *snap = nil;
  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 snap = snapshot;
               }];

  NSDictionary *data = @{
    @"a" : @1,
    @"b" : @{@".value" : [FIRServerValue timestamp], @".priority" : [FIRServerValue timestamp]}
  };

  __block BOOL done = NO;
  [node onDisconnectSetValue:data
                 andPriority:[FIRServerValue timestamp]
         withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
           done = YES;
         }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;

  [node onDisconnectUpdateChildValues:@{
    @"a" : [FIRServerValue timestamp],
    @"c" : [FIRServerValue timestamp]
  }
                  withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                    done = YES;
                  }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;

  [FRepoManager interrupt:writerCfg];

  [self waitUntil:^BOOL {
    if ([snap value] != [NSNull null]) {
      NSDictionary *val = [snap value];
      done = (val[@"a"] && val[@"b"] && val[@"c"]);
    }
    return done;
  }];

  NSDictionary *value = [snap value];
  NSNumber *now = [NSNumber numberWithDouble:round([[NSDate date] timeIntervalSince1970] * 1000)];
  NSNumber *timestamp = [snap priority];
  XCTAssertTrue([[snap priority] isKindOfClass:[NSNumber class]], @"Should get back number");
  XCTAssertTrue([now doubleValue] - [timestamp doubleValue] < 2000,
                @"Number should be no more than 2 seconds ago");
  XCTAssertEqualObjects([snap priority], [value objectForKey:@"a"],
                        @"Should get back matching ServerValue.TIMESTAMP");
  XCTAssertEqualObjects([snap priority], [value objectForKey:@"b"],
                        @"Should get back matching ServerValue.TIMESTAMP");
  XCTAssertEqualObjects([snap priority], [[snap childSnapshotForPath:@"b"] priority],
                        @"Should get back matching ServerValue.TIMESTAMP");
  XCTAssertEqualObjects([NSNull null], [[snap childSnapshotForPath:@"d"] value],
                        @"Should get null for cancelled child");

  // cleanup
  [FRepoManager disposeRepos:writerCfg];
}

@end
