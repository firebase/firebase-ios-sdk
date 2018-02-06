// Copyright 2018 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FIRTestCase.h"

#import <FirebaseCore/FIRReachabilityChecker+Internal.h>
#import <FirebaseCore/FIRReachabilityChecker.h>

@interface FIRReachabilityCheckerTest : FIRTestCase <FIRReachabilityDelegate> {
 @private
  FIRReachabilityChecker *checker_;
  NSMutableArray *statuses_;
  BOOL createFail_;
  BOOL setCallbackFail_;
  BOOL scheduleUnscheduleFail_;
}

- (void *)createReachabilityWithAllocator:(CFAllocatorRef)allocator withName:(const char *)hostname;
- (BOOL)reachability:(const void *)reachability
         setCallback:(SCNetworkReachabilityCallBack)callback
         withContext:(SCNetworkReachabilityContext *)context;
- (BOOL)scheduleReachability:(const void *)reachability
                     runLoop:(CFRunLoopRef)runLoop
                 runLoopMode:(CFStringRef)runLoopMode;
- (BOOL)unscheduleReachability:(const void *)reachability
                       runLoop:(CFRunLoopRef)runLoop
                   runLoopMode:(CFStringRef)runLoopMode;
- (void)releaseReachability:(const void *)reachability;
@end

static NSString *const kHostname = @"www.google.com";
static const void *kFakeReachabilityObject = (const void *)0x8badf00d;

static FIRReachabilityCheckerTest *FakeReachabilityTest = nil;

static struct {
  int callsMade;
  int createCall;
  int setCallbackCall;
  int scheduleCall;
  int unscheduleCall;
  int releaseCall;
  void (*callback)(SCNetworkReachabilityRef, SCNetworkReachabilityFlags, void *info);
  void *callbackInfo;
} FakeReachability;

static SCNetworkReachabilityRef ReachabilityCreateWithName(CFAllocatorRef allocator,
                                                           const char *hostname) {
  return (SCNetworkReachabilityRef)
      [FakeReachabilityTest createReachabilityWithAllocator:allocator withName:hostname];
}

static Boolean ReachabilitySetCallback(SCNetworkReachabilityRef reachability,
                                       SCNetworkReachabilityCallBack callback,
                                       SCNetworkReachabilityContext *context) {
  return [FakeReachabilityTest reachability:reachability setCallback:callback withContext:context];
}

static Boolean ReachabilityScheduleWithRunLoop(SCNetworkReachabilityRef reachability,
                                               CFRunLoopRef runLoop,
                                               CFStringRef runLoopMode) {
  return [FakeReachabilityTest scheduleReachability:reachability
                                            runLoop:runLoop
                                        runLoopMode:runLoopMode];
}

static Boolean ReachabilityUnscheduleFromRunLoop(SCNetworkReachabilityRef reachability,
                                                 CFRunLoopRef runLoop,
                                                 CFStringRef runLoopMode) {
  return [FakeReachabilityTest unscheduleReachability:reachability
                                              runLoop:runLoop
                                          runLoopMode:runLoopMode];
}

static void ReachabilityRelease(CFTypeRef reachability) {
  [FakeReachabilityTest releaseReachability:reachability];
}

static const struct FIRReachabilityApi kTestReachabilityApi = {
    ReachabilityCreateWithName,        ReachabilitySetCallback, ReachabilityScheduleWithRunLoop,
    ReachabilityUnscheduleFromRunLoop, ReachabilityRelease,
};

@implementation FIRReachabilityCheckerTest

- (void)resetFakeReachability {
  FakeReachabilityTest = self;
  FakeReachability.callsMade = 0;
  FakeReachability.createCall = -1;
  FakeReachability.setCallbackCall = -1;
  FakeReachability.scheduleCall = -1;
  FakeReachability.unscheduleCall = -1;
  FakeReachability.releaseCall = -1;
  FakeReachability.callback = NULL;
  FakeReachability.callbackInfo = NULL;
}

- (void)setUp {
  [super setUp];

  [self resetFakeReachability];
  createFail_ = NO;
  setCallbackFail_ = NO;
  scheduleUnscheduleFail_ = NO;

  checker_ = [[FIRReachabilityChecker alloc] initWithReachabilityDelegate:self
                                                           loggerDelegate:nil
                                                                 withHost:kHostname];
  statuses_ = [[NSMutableArray alloc] init];
}

- (void *)createReachabilityWithAllocator:(CFAllocatorRef)allocator
                                 withName:(const char *)hostname {
  XCTAssertTrue(allocator == kCFAllocatorDefault, @"");
  XCTAssertEqual(strcmp(hostname, [kHostname UTF8String]), 0, @"");
  XCTAssertEqual(FakeReachability.callsMade, 0, @"create call must always come first.");
  XCTAssertEqual(FakeReachability.createCall, -1, @"create call must only be called once.");
  FakeReachability.createCall = ++FakeReachability.callsMade;
  return createFail_ ? NULL : (void *)kFakeReachabilityObject;
}

- (BOOL)reachability:(const void *)reachability
         setCallback:(SCNetworkReachabilityCallBack)callback
         withContext:(SCNetworkReachabilityContext *)context {
  XCTAssertEqual(reachability, kFakeReachabilityObject, @"got bad object");
  XCTAssertEqual((int)context->version, 0, @"");
  XCTAssertEqual(context->info, (__bridge void *)checker_, @"");
  XCTAssertEqual((void *)context->retain, NULL, @"");
  XCTAssertEqual((void *)context->release, NULL, @"");
  XCTAssertEqual((void *)context->copyDescription, NULL, @"");
  XCTAssertEqual(FakeReachability.setCallbackCall, -1, @"setCallback should only be called once.");
  FakeReachability.setCallbackCall = ++FakeReachability.callsMade;
  XCTAssertTrue(callback != NULL, @"");
  FakeReachability.callback = callback;
  XCTAssertTrue(context->info != NULL, @"");
  FakeReachability.callbackInfo = context->info;
  return setCallbackFail_ ? NO : YES;
}

- (BOOL)scheduleReachability:(const void *)reachability
                     runLoop:(CFRunLoopRef)runLoop
                 runLoopMode:(CFStringRef)runLoopMode {
  XCTAssertEqual(reachability, kFakeReachabilityObject, @"got bad object");
  XCTAssertEqual(runLoop, CFRunLoopGetMain(), @"bad run loop");
  XCTAssertEqualObjects((__bridge NSString *)runLoopMode,
                        (__bridge NSString *)kCFRunLoopCommonModes, @"bad run loop mode");
  XCTAssertEqual(FakeReachability.scheduleCall, -1,
                 @"scheduleWithRunLoop should only be called once.");
  FakeReachability.scheduleCall = ++FakeReachability.callsMade;
  return scheduleUnscheduleFail_ ? NO : YES;
}

- (BOOL)unscheduleReachability:(const void *)reachability
                       runLoop:(CFRunLoopRef)runLoop
                   runLoopMode:(CFStringRef)runLoopMode {
  XCTAssertEqual(reachability, kFakeReachabilityObject, @"got bad object");
  XCTAssertEqual(runLoop, CFRunLoopGetMain(), @"bad run loop");
  XCTAssertEqualObjects((__bridge NSString *)runLoopMode,
                        (__bridge NSString *)kCFRunLoopCommonModes, @"bad run loop mode");
  XCTAssertEqual(FakeReachability.unscheduleCall, -1,
                 @"unscheduleFromRunLoop should only be called once.");
  FakeReachability.unscheduleCall = ++FakeReachability.callsMade;
  return scheduleUnscheduleFail_ ? NO : YES;
}

- (void)releaseReachability:(const void *)reachability {
  XCTAssertEqual(reachability, kFakeReachabilityObject, @"got bad object");
  XCTAssertEqual(FakeReachability.releaseCall, -1, @"release should only be called once.");
  FakeReachability.releaseCall = ++FakeReachability.callsMade;
}

- (void)reachability:(FIRReachabilityChecker *)reachability
       statusChanged:(FIRReachabilityStatus)status {
  [statuses_ addObject:[NSNumber numberWithInt:(int)status]];
}

#pragma mark - Test

- (void)testApiHappyPath {
  [checker_ setReachabilityApi:&kTestReachabilityApi];
  XCTAssertEqual([checker_ reachabilityApi], &kTestReachabilityApi, @"");

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  XCTAssertTrue([checker_ start], @"");

  XCTAssertTrue(checker_.isActive, @"");
  XCTAssertEqual([statuses_ count], (NSUInteger)0, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  FakeReachability.callback(kFakeReachabilityObject, 0, FakeReachability.callbackInfo);

  XCTAssertEqual([statuses_ count], (NSUInteger)1, @"");
  XCTAssertEqual([(NSNumber *)[statuses_ objectAtIndex:0] intValue],
                 (int)kFIRReachabilityNotReachable, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityNotReachable, @"");

  FakeReachability.callback(kFakeReachabilityObject, kSCNetworkReachabilityFlagsReachable,
                            FakeReachability.callbackInfo);

  XCTAssertEqual([statuses_ count], (NSUInteger)2, @"");
  XCTAssertEqual([(NSNumber *)[statuses_ objectAtIndex:1] intValue], (int)kFIRReachabilityViaWifi,
                 @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityViaWifi, @"");

  FakeReachability.callback(
      kFakeReachabilityObject,
      kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsConnectionRequired,
      FakeReachability.callbackInfo);

  XCTAssertEqual([statuses_ count], (NSUInteger)3, @"");
  XCTAssertEqual([(NSNumber *)[statuses_ objectAtIndex:2] intValue],
                 (int)kFIRReachabilityNotReachable, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityNotReachable, @"");

#if TARGET_OS_IOS || TARGET_OS_TV
  FakeReachability.callback(
      kFakeReachabilityObject,
      kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsWWAN,
      FakeReachability.callbackInfo);

  XCTAssertEqual([statuses_ count], (NSUInteger)4, @"");
  XCTAssertEqual([(NSNumber *)[statuses_ objectAtIndex:3] intValue],
                 (int)kFIRReachabilityViaCellular, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityViaCellular, @"");

  FakeReachability.callback(kFakeReachabilityObject, kSCNetworkReachabilityFlagsIsWWAN,
                            FakeReachability.callbackInfo);

  XCTAssertEqual([statuses_ count], (NSUInteger)5, @"");
  XCTAssertEqual([(NSNumber *)[statuses_ objectAtIndex:4] intValue],
                 (int)kFIRReachabilityNotReachable, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityNotReachable, @"");
#endif

  [checker_ stop];

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  XCTAssertEqual(FakeReachability.callsMade, 5, @"");

  XCTAssertEqual(FakeReachability.createCall, 1, @"");
  XCTAssertEqual(FakeReachability.setCallbackCall, 2, @"");
  XCTAssertEqual(FakeReachability.scheduleCall, 3, @"");
  XCTAssertEqual(FakeReachability.unscheduleCall, 4, @"");
  XCTAssertEqual(FakeReachability.releaseCall, 5, @"");
}

- (void)testApiCreateFail {
  [checker_ setReachabilityApi:&kTestReachabilityApi];
  XCTAssertEqual([checker_ reachabilityApi], &kTestReachabilityApi, @"");

  createFail_ = YES;

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  XCTAssertFalse([checker_ start], @"");

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  [checker_ stop];

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  XCTAssertEqual(FakeReachability.callsMade, 1, @"");

  XCTAssertEqual(FakeReachability.createCall, 1, @"");
  XCTAssertEqual(FakeReachability.setCallbackCall, -1, @"");
  XCTAssertEqual(FakeReachability.scheduleCall, -1, @"");
  XCTAssertEqual(FakeReachability.unscheduleCall, -1, @"");
  XCTAssertEqual(FakeReachability.releaseCall, -1, @"");

  XCTAssertEqual([statuses_ count], (NSUInteger)0, @"");
}

- (void)testApiCallbackFail {
  [checker_ setReachabilityApi:&kTestReachabilityApi];
  XCTAssertEqual([checker_ reachabilityApi], &kTestReachabilityApi, @"");

  setCallbackFail_ = YES;

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  XCTAssertFalse([checker_ start], @"");

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  [checker_ stop];

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  XCTAssertEqual(FakeReachability.callsMade, 3, @"");

  XCTAssertEqual(FakeReachability.createCall, 1, @"");
  XCTAssertEqual(FakeReachability.setCallbackCall, 2, @"");
  XCTAssertEqual(FakeReachability.scheduleCall, -1, @"");
  XCTAssertEqual(FakeReachability.unscheduleCall, -1, @"");
  XCTAssertEqual(FakeReachability.releaseCall, 3, @"");

  XCTAssertEqual([statuses_ count], (NSUInteger)0, @"");
}

- (void)testApiScheduleFail {
  [checker_ setReachabilityApi:&kTestReachabilityApi];
  XCTAssertEqual([checker_ reachabilityApi], &kTestReachabilityApi, @"");

  scheduleUnscheduleFail_ = YES;

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  XCTAssertFalse([checker_ start], @"");

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  [checker_ stop];

  XCTAssertFalse(checker_.isActive, @"");
  XCTAssertEqual(checker_.reachabilityStatus, kFIRReachabilityUnknown, @"");

  XCTAssertEqual(FakeReachability.callsMade, 4, @"");

  XCTAssertEqual(FakeReachability.createCall, 1, @"");
  XCTAssertEqual(FakeReachability.setCallbackCall, 2, @"");
  XCTAssertEqual(FakeReachability.scheduleCall, 3, @"");
  XCTAssertEqual(FakeReachability.unscheduleCall, -1, @"");
  XCTAssertEqual(FakeReachability.releaseCall, 4, @"");

  XCTAssertEqual([statuses_ count], (NSUInteger)0, @"");
}

- (void)testBadHost {
  XCTAssertNil([[FIRReachabilityChecker alloc]
                   initWithReachabilityDelegate:self
                                 loggerDelegate:(id<FIRNetworkLoggerDelegate>)self
                                       withHost:nil],
               @"Creating a checker with nil hostname must fail.");
  XCTAssertNil([[FIRReachabilityChecker alloc]
                   initWithReachabilityDelegate:self
                                 loggerDelegate:(id<FIRNetworkLoggerDelegate>)self
                                       withHost:@""],
               @"Creating a checker with empty hostname must fail.");
}

@end
