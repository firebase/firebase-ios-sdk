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

#import "Crashlytics/Crashlytics/Operations/Symbolication/FIRCLSSymbolicationOperation.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Private/FIRStackFrame_Private.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSymbolResolver.h"

@interface FIRCLSSymbolicationOperationTests : XCTestCase

@end

@implementation FIRCLSSymbolicationOperationTests

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testOperation {
  FIRCLSMockSymbolResolver* resolver = [[FIRCLSMockSymbolResolver alloc] init];

  FIRStackFrame* frame = nil;

  frame = [FIRStackFrame stackFrameWithSymbol:@"testSymbolA"];
  [frame setLibrary:@"libA"];
  [frame setOffset:10];

  [resolver addMockFrame:frame atAddress:100];

  frame = [FIRStackFrame stackFrameWithSymbol:@"testSymbolB"];
  [frame setLibrary:@"libB"];
  [frame setOffset:20];

  [resolver addMockFrame:frame atAddress:200];

  NSMutableArray* frameArray = [[NSMutableArray alloc] init];
  [frameArray addObject:[FIRStackFrame stackFrameWithAddress:100]];
  [frameArray addObject:[FIRStackFrame stackFrameWithAddress:200]];

  FIRCLSSymbolicationOperation* op = [[FIRCLSSymbolicationOperation alloc] init];

  [op setSymbolResolver:resolver];
  [op setThreadArray:@[ frameArray ]];

  [op start];

  XCTAssertEqual([frameArray count], 2, @"");
  XCTAssertEqualObjects([frameArray[0] symbol], @"testSymbolA", @"");
  XCTAssertEqualObjects([frameArray[0] library], @"libA", @"");
  XCTAssertEqual([((FIRStackFrame*)frameArray[0]) offset], 10, @"");
  XCTAssertEqualObjects([frameArray[1] symbol], @"testSymbolB", @"");
  XCTAssertEqualObjects([frameArray[1] library], @"libB", @"");
  XCTAssertEqual([((FIRStackFrame*)frameArray[1]) offset], 20, @"");
}

@end
