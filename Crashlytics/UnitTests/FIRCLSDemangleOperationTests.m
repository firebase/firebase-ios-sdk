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

#import "Crashlytics/Crashlytics/Operations/Symbolication/FIRCLSDemangleOperation.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Private/FIRStackFrame_Private.h"

@interface FIRCLSDemangleOperationTests : XCTestCase

@end

@implementation FIRCLSDemangleOperationTests

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

- (NSString *)demangle:(const char *)symbol {
  return [FIRCLSDemangleOperation demangleSymbol:symbol];
}

- (void)testDemangleUnmangledSymbol {
  XCTAssertNil([self demangle:"unmangledSymbol"], @"");
}

- (void)testDemangleCppSymbols {
  XCTAssertEqualObjects([self demangle:"_Z7monitorP8NSStringlS0_"],
                        @"monitor(NSString*, long, NSString*)", @"");
}

- (void)testDemangleSwiftSymbolsNoHandler {
  XCTAssertEqualObjects(
      [self
          demangle:
              "$ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF"],
      nil, @"");
}

- (void)testDemangleCppSymbolsWithBlockInvoke {
  XCTAssertEqualObjects([self demangle:"__Z7monitorP8NSStringlS0__block_invoke"],
                        @"monitor(NSString*, long, NSString*)_block_invoke", @"");
  XCTAssertEqualObjects([self demangle:"__Z7monitorP8NSStringlS0__block_invoke_2"],
                        @"monitor(NSString*, long, NSString*)_block_invoke_2", @"");
  XCTAssertNil([self demangle:"__Zt_block_invoke"], @"Invalid Cpp symbol");
  XCTAssertNil([self demangle:"__Zinvalid_block_invoke"], @"Invalid Cpp symbol");
}

- (void)testOperation {
  NSMutableArray *frameArray = [[NSMutableArray alloc] init];
  [frameArray addObject:[FIRStackFrame stackFrameWithSymbol:@"_Z7monitorP8NSStringlS0_"]];
  [frameArray addObject:[FIRStackFrame stackFrameWithSymbol:@"_ZN9wikipedia7article6formatEv"]];
  [frameArray addObject:[FIRStackFrame stackFrameWithSymbol:@"unmangledSymbol"]];
  [frameArray
      addObject:[FIRStackFrame stackFrameWithSymbol:
                                   @"$ss17_assertionFailure__"
                                   @"4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF"]];

  FIRCLSDemangleOperation *op = [[FIRCLSDemangleOperation alloc] init];
  [op setThreadArray:@[ frameArray ]];

  [op start];

  XCTAssertEqual([frameArray count], 4, @"");
  XCTAssertEqualObjects([frameArray[0] symbol], @"monitor(NSString*, long, NSString*)", @"");
  XCTAssertEqualObjects([frameArray[1] symbol], @"wikipedia::article::format()", @"");
  XCTAssertEqualObjects([frameArray[2] symbol], @"unmangledSymbol", @"");

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
  XCTAssertEqualObjects(
      [frameArray[3] symbol],
      @"Swift._assertionFailure(_: Swift.StaticString, _: Swift.String, file: Swift.StaticString, "
      @"line: Swift.UInt, flags: Swift.UInt32) -> Swift.Never",
      @"");
#endif
}

@end
