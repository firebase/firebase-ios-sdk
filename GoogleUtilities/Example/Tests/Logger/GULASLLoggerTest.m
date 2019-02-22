// Copyright 2019 Google
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

#import <GoogleUtilities/GULASLLogger.h>
#import <GoogleUtilities/GULLogger.h>

#import <asl.h>

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

// TODO(bstpierre): Use a C function redirect to mock asl_* methods like GULOSLoggerTest.

static NSString *const kService = @"my service";
static NSString *const kCode = @"I-COR000001";

// Redefine class property as readwrite for testing.
@interface GULLogger (ForTesting)
@property(nonatomic, class, readwrite) id<GULLoggerSystem> logger;
@end

// Surface aslclient and dispatchQueues for tests.
@interface GULASLLogger (ForTesting)
@property(nonatomic) aslclient aslClient;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@end

#pragma mark -

@interface GULASLLoggerTest : XCTestCase
@property(nonatomic) GULASLLogger *logger;
@end

@implementation GULASLLoggerTest

#pragma mark Helper Methods

// TODO(bstpierre): Replace this with a XCTestExpectation like GULOSLoggerTest.
- (BOOL)messageWasLogged:(NSString *)message {
  // Format the message as it's expected.
  message = [NSString stringWithFormat:@"%@[%@] %@", kService, kCode, message];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  aslmsg query = asl_new(ASL_TYPE_QUERY);
  asl_set_query(query, ASL_KEY_FACILITY, "com.google.utilities.logger", ASL_QUERY_OP_EQUAL);
  aslresponse response = asl_search(self.logger.aslClient, query);
  asl_release(query);
  aslmsg msg;
  const char *responseMsg;
  BOOL messageFound = NO;
  while ((msg = asl_next(response)) != NULL) {
    responseMsg = asl_get(msg, ASL_KEY_MSG);
    if ([message isEqualToString:[NSString stringWithUTF8String:responseMsg]]) {
      messageFound = YES;
      break;
    }
  }
  asl_release(msg);
  asl_release(response);
#pragma clang pop
  return messageFound;
}

#pragma mark Testing

- (void)setUp {
  [super setUp];
  self.logger = [[GULASLLogger alloc] init];
  GULLogger.logger = self.logger;
}

- (void)tearDown {
  GULLogger.logger = nil;
  self.logger = nil;
  [super tearDown];
}

- (void)testMessageCodeFormat {
  // Valid case.
  XCTAssertNoThrow(GULLogError(kService, NO, @"I-APP000001", @"Message."));

  // An extra dash or missing dash should fail.
  XCTAssertThrows(GULLogError(kService, NO, @"I-APP-000001", @"Message."));
  XCTAssertThrows(GULLogError(kService, NO, @"IAPP000001", @"Message."));

  // Wrong number of digits should fail.
  XCTAssertThrows(GULLogError(kService, NO, @"I-APP00001", @"Message."));
  XCTAssertThrows(GULLogError(kService, NO, @"I-APP0000001", @"Message."));

  // Lowercase should fail.
  XCTAssertThrows(GULLogError(kService, NO, @"I-app000001", @"Message."));

  // nil or empty message code should fail.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertThrows(GULLogError(kService, NO, nil, @"Message."));
#pragma clang diagnostic pop

  XCTAssertThrows(GULLogError(kService, NO, @"", @"Message."));

  // Android message code should fail.
  XCTAssertThrows(GULLogError(kService, NO, @"A-APP000001", @"Message."));
}

- (void)testLoggerInterface {
  XCTAssertNoThrow(GULLogError(kService, NO, kCode, @"Message."));
  XCTAssertNoThrow(GULLogError(kService, NO, kCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(GULLogWarning(kService, NO, kCode, @"Message."));
  XCTAssertNoThrow(GULLogWarning(kService, NO, kCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(GULLogNotice(kService, NO, kCode, @"Message."));
  XCTAssertNoThrow(GULLogNotice(kService, NO, kCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(GULLogInfo(kService, NO, kCode, @"Message."));
  XCTAssertNoThrow(GULLogInfo(kService, NO, kCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(GULLogDebug(kService, NO, kCode, @"Message."));
  XCTAssertNoThrow(GULLogDebug(kService, NO, kCode, @"Configure %@.", @"blah"));
}

// The GULLoggerLevel enum must match the ASL_LEVEL_* constants, but we manually redefine
// them in GULLoggerLevel.h since we cannot include <asl.h> (see b/34976089 for more details).
// This test ensures the constants match.
- (void)testGULLoggerLevelValues {
  XCTAssertEqual(GULLoggerLevelError, ASL_LEVEL_ERR);
  XCTAssertEqual(GULLoggerLevelWarning, ASL_LEVEL_WARNING);
  XCTAssertEqual(GULLoggerLevelNotice, ASL_LEVEL_NOTICE);
  XCTAssertEqual(GULLoggerLevelInfo, ASL_LEVEL_INFO);
  XCTAssertEqual(GULLoggerLevelDebug, ASL_LEVEL_DEBUG);
}

// TODO(bstpierre): Add tests for logWithLevel:withService:isForced:withCode:withMessage:

@end

NS_ASSUME_NONNULL_END
