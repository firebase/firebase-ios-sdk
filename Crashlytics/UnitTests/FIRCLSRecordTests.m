// Copyright 2020 Google
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "FIRCLSRecordAdapter.h"
#import "FIRCLSRecordAdapter_Private.h"
#import "FIRCLSRecordApplication.h"
#import "FIRCLSRecordBase.h"
#import "FIRCLSRecordBinaryImage.h"
#import "FIRCLSRecordExecutable.h"
#import "FIRCLSRecordFrame.h"
#import "FIRCLSRecordHost.h"
#import "FIRCLSRecordIdentity.h"
#import "FIRCLSRecordKeyValue.h"
#import "FIRCLSRecordProcessStats.h"
#import "FIRCLSRecordRegister.h"
#import "FIRCLSRecordRuntime.h"
#import "FIRCLSRecordSignal.h"
#import "FIRCLSRecordStorage.h"
#import "FIRCLSRecordThread.h"

//@interface FIRCLSURLBuilder (Testing)
//- (NSString *)escapeString:(NSString *)string;
//@end

@interface FIRCLSRecordTests : XCTestCase

@end

@implementation FIRCLSRecordTests

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

/// It is important that crashes do not occur when reading persisted crash files before uploading
/// Verify various invalid input cases
- (void)testInvalidRecordCases {
    id adapter __unused = [[FIRCLSRecordAdapter alloc] initWithPath:@"nonExistentPath"];
    
    id application __unused = [[FIRCLSRecordApplication alloc] initWithDict:nil];
    id base __unused = [[FIRCLSRecordBase alloc] initWithDict:nil];
    id binaryImage __unused = [[FIRCLSRecordBinaryImage alloc] initWithDict:nil];
    id executable __unused = [[FIRCLSRecordExecutable alloc] initWithDict:nil];
    id frame __unused = [[FIRCLSRecordFrame alloc] initWithDict:nil];
    id host __unused = [[FIRCLSRecordHost alloc] initWithDict:nil];
    id identity __unused = [[FIRCLSRecordIdentity alloc] initWithDict:nil];
    id keyValues __unused = [[FIRCLSRecordKeyValue alloc] initWithDict:nil];
    id processStats __unused = [[FIRCLSRecordProcessStats alloc] initWithDict:nil];
    id reg __unused = [[FIRCLSRecordRegister alloc] initWithDict:nil];
    id runtime __unused = [[FIRCLSRecordRuntime alloc] initWithDict:nil];
    id signal __unused = [[FIRCLSRecordSignal alloc] initWithDict:nil];
    id storage __unused = [[FIRCLSRecordStorage alloc] initWithDict:nil];
    id thread __unused = [[FIRCLSRecordThread alloc] initWithDict:nil];
    
    NSDictionary *emptyDict = [[NSDictionary alloc] init];
    id application2 __unused = [[FIRCLSRecordApplication alloc] initWithDict:emptyDict];
    id base2 __unused = [[FIRCLSRecordBase alloc] initWithDict:emptyDict];
    id binaryImage2 __unused = [[FIRCLSRecordBinaryImage alloc] initWithDict:emptyDict];
    id executable2 __unused = [[FIRCLSRecordExecutable alloc] initWithDict:emptyDict];
    id frame2 __unused = [[FIRCLSRecordFrame alloc] initWithDict:emptyDict];
    id host2 __unused = [[FIRCLSRecordHost alloc] initWithDict:emptyDict];
    id identity2 __unused = [[FIRCLSRecordIdentity alloc] initWithDict:emptyDict];
    id keyValues2 __unused = [[FIRCLSRecordKeyValue alloc] initWithDict:emptyDict];
    id processStats2 __unused = [[FIRCLSRecordProcessStats alloc] initWithDict:emptyDict];
    id reg2 __unused = [[FIRCLSRecordRegister alloc] initWithDict:emptyDict];
    id runtime2 __unused = [[FIRCLSRecordRuntime alloc] initWithDict:emptyDict];
    id signal2 __unused = [[FIRCLSRecordSignal alloc] initWithDict:emptyDict];
    id storage2 __unused = [[FIRCLSRecordStorage alloc] initWithDict:emptyDict];
    id thread2 __unused = [[FIRCLSRecordThread alloc] initWithDict:emptyDict];
}

- (void)testHexDecoding {
    NSString *str = @"Hello world!";
    
    // Hex encode the string
    const char *utf8 = [str UTF8String];
    NSMutableString *hex = [NSMutableString string];
    while ( *utf8 ) [hex appendFormat:@"%02X" , *utf8++ & 0x00FF];
    NSString *hexEncodedString = [NSString stringWithFormat:@"%@", hex];
    
    NSString *hexDecodedString = [FIRCLSRecordBase decodedHexStringWithValue:hexEncodedString];
    
    XCTAssertTrue([str isEqualToString:hexDecodedString]);
}

- (void)testRecordBinaryImagesFile {
    FIRCLSRecordAdapter *adapter = [[FIRCLSRecordAdapter alloc] initWithPath:[FIRCLSRecordTests persistedCrashFolder]];
    XCTAssertEqual(adapter.binaryImages.count, 453);
    
    // Verify first binary
    FIRCLSRecordBinaryImage *firstImage = adapter.binaryImages[0];
    XCTAssertTrue([firstImage.path isEqualToString:@"/private/var/containers/Bundle/Application/C49F1179-0088-4882-A60D-13ACDA2AF8B3/Crashlytics-iOS-App.app/Crashlytics-iOS-App"]);
    XCTAssertTrue([firstImage.uuid isEqualToString:@"0341c4166f253830a94a5698cee7fea7"]);
    XCTAssertEqual(firstImage.base, 4305256448);
    XCTAssertEqual(firstImage.size, 1392640);
    
    // Verify last binary
    FIRCLSRecordBinaryImage *lastImage = adapter.binaryImages[452];
    XCTAssertTrue([lastImage.path isEqualToString:@"/System/Library/Frameworks/Accelerate.framework/Frameworks/vImage.framework/Libraries/libCGInterfaces.dylib"]);
    XCTAssertTrue([lastImage.uuid isEqualToString:@"f4421e9313fa386fbd568035eb1d35be"]);
    XCTAssertEqual(lastImage.base, 7226896384);
    XCTAssertEqual(lastImage.size, 86016);
}

+ (NSString *)persistedCrashFolder {
    return [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"ios_crash"];
}

@end
