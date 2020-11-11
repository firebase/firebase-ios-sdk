//
//  FIRCLSConstantsTest.m
//  FirebaseCrashlytics-iOS-Unit-unit
//
//  Created by Tejas Deshpande on 11/11/20.
//

#import <XCTest/XCTest.h>

#import "Crashlytics/Shared/FIRCLSConstants.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

@interface FIRCLSConstantsTest : XCTestCase

@end

@implementation FIRCLSConstantsTest

- (void)testGeneratorName {
  NSString *expectedGeneratorName =
      [NSString stringWithFormat:@"%s/%s", STR(CLS_SDK_NAME), FIRCLSSDKVersion().UTF8String];
  XCTAssertEqualObjects(expectedGeneratorName, FIRCLSSDKGeneratorName());
}

- (void)testSdkVersion {
#ifdef CRASHLYTICS_1P
  NSString *expectedSdkVersion = [FIRFirebaseVersion() stringByAppendingString:@"_1P"];
#else
  NSString *expectedSdkVersion = FIRFirebaseVersion();
#endif
  XCTAssertEqualObjects(expectedSdkVersion, FIRCLSSDKVersion());
}

@end
