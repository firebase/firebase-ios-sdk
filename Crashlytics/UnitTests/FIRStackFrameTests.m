// Copyright 2020 Google LLC
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

#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Private/FIRStackFrame_Private.h"

@interface FIRStackFrameTests : XCTestCase

@end

@implementation FIRStackFrameTests

- (void)testBasicSymbolicatedCheck {
  FIRStackFrame *stackFrame = [FIRStackFrame stackFrameWithSymbol:@"SYMBOL"
                                                             file:@"FILE"
                                                             line:54321];
  XCTAssertEqualObjects(stackFrame.symbol, @"SYMBOL");
  XCTAssertEqualObjects(stackFrame.fileName, @"FILE");
  XCTAssertEqual(stackFrame.lineNumber, 54321);
}

- (void)testOwnership {
  NSString *symbol = @"SYMBOL";
  NSString *file = @"FILE";
  FIRStackFrame *stackFrame = [FIRStackFrame stackFrameWithSymbol:symbol file:file line:54321];
  symbol = @"NEW_SYMBOL";
  file = nil;
  XCTAssertEqualObjects(stackFrame.symbol, @"SYMBOL");
  XCTAssertEqualObjects(stackFrame.fileName, @"FILE");
  XCTAssertEqual(stackFrame.lineNumber, 54321);
}

- (void)testIntUIntConversion {
  FIRStackFrame *stackFrame = [FIRStackFrame stackFrameWithSymbol:@"SYMBOL" file:@"FILE" line:100];
  XCTAssertEqual(stackFrame.lineNumber, 100);

  FIRStackFrame *stackFrame2 = [FIRStackFrame stackFrameWithSymbol:@"SYMBOL"
                                                              file:@"FILE"
                                                              line:-100];
  XCTAssertEqual(stackFrame2.lineNumber, 4294967196);
}

- (void)testDescription {
  FIRStackFrame *stackFrame = [FIRStackFrame stackFrameWithSymbol:@"FIRStackFrameTests"
                                                             file:@"testDescription"
                                                             line:35];
  XCTAssertEqualObjects([stackFrame description], @"{testDescription - FIRStackFrameTests:35}");
}

@end
