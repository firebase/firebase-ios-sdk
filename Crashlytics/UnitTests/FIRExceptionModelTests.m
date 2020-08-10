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

#import "Crashlytics/Crashlytics/Private/FIRExceptionModel_Private.h"
#import "Crashlytics/Crashlytics/Private/FIRStackFrame_Private.h"

@interface FIRExceptionModelTests : XCTestCase

@end

@implementation FIRExceptionModelTests

- (void)testBasicOwnership {
  NSArray *stackTrace = @[
    [FIRStackFrame stackFrameWithSymbol:@"CrashyFunc" file:@"AppLib.m" line:504],
    [FIRStackFrame stackFrameWithSymbol:@"ApplicationMain" file:@"AppleLib" line:1],
    [FIRStackFrame stackFrameWithSymbol:@"main()" file:@"main.m" line:201],
  ];
  NSString *name = @"FIRExceptionModelTestsCrash";
  NSString *reason = @"Programmer made an error";

  FIRExceptionModel *model = [FIRExceptionModel exceptionModelWithName:name reason:reason];
  model.stackTrace = stackTrace;

  name = @"NewName";
  reason = nil;
  stackTrace = @[];

  XCTAssertEqualObjects(model.name, @"FIRExceptionModelTestsCrash");
  XCTAssertEqualObjects(model.reason, @"Programmer made an error");
  XCTAssertEqual(model.stackTrace.count, 3);
  XCTAssertEqualObjects(model.stackTrace[0].symbol, @"CrashyFunc");
  XCTAssertEqualObjects(model.stackTrace[2].fileName, @"main.m");
}

- (void)testMutableArrayOwnership {
  NSMutableArray<FIRStackFrame *> *stackTrace = [[NSMutableArray alloc] initWithArray:@[
    [FIRStackFrame stackFrameWithSymbol:@"CrashyFunc" file:@"AppLib.m" line:504],
    [FIRStackFrame stackFrameWithSymbol:@"ApplicationMain" file:@"AppleLib" line:1],
    [FIRStackFrame stackFrameWithSymbol:@"main()" file:@"main.m" line:201],
  ]];
  NSString *name = @"FIRExceptionModelTestsCrash";
  NSString *reason = @"Programmer made an error";

  FIRExceptionModel *model = [FIRExceptionModel exceptionModelWithName:name reason:reason];
  model.stackTrace = stackTrace;

  stackTrace[0].symbol = @"NewSymbol";

  FIRStackFrame *newFrame = [FIRStackFrame stackFrameWithSymbol:@"NewMain"
                                                           file:@"below_main.m"
                                                           line:300];
  [stackTrace addObject:newFrame];
  [stackTrace insertObject:newFrame atIndex:1];

  XCTAssertEqual(model.stackTrace.count, 3);

  // Modifying underlying frames in the stack trace will be reflected in the Exception Model's copy
  // because we only shallow copy the array and not the contents.
  XCTAssertEqualObjects(model.stackTrace[0].symbol, @"NewSymbol");

  // Inserted frames into the mutable array after the fact do not impact the array passed to the
  // Exception Model.
  XCTAssertEqualObjects(model.stackTrace[1].symbol, @"ApplicationMain");
}

@end
