#import <XCTest/XCTest.h>

#import "GDLLogger.h"

@interface GDLLoggerTest : XCTestCase

@end

@implementation GDLLoggerTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDLLogger alloc] initWithLogSource:1 logTransformers:nil logTarget:1]);
}

@end
