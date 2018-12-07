#import <XCTest/XCTest.h>

#import "GDLLogEvent.h"

@interface GDLLogEventTest : XCTestCase

@end

@implementation GDLLogEventTest

- (void)testInit {
  XCTAssertNotNil([[GDLLogEvent alloc] init]);
}

@end
