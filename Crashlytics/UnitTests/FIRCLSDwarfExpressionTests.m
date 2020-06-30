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

#import <XCTest/XCTest.h>

#include "Crashlytics/Crashlytics/Unwind/Dwarf/FIRCLSDwarfExpressionMachine.h"

@interface FIRCLSDwarfExpressionTests : XCTestCase

@end

@implementation FIRCLSDwarfExpressionTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the
  // class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

#if CLS_DWARF_UNWINDING_SUPPORTED

- (void)testDwarfStackPushAndPop {
  FIRCLSDwarfExpressionStack stack;

  FIRCLSDwarfExpressionStackInit(&stack);

  XCTAssert(FIRCLSDwarfExpressionStackIsValid(&stack));

  XCTAssert(FIRCLSDwarfExpressionStackPush(&stack, 1));
  XCTAssert(FIRCLSDwarfExpressionStackPush(&stack, 2));
  XCTAssert(FIRCLSDwarfExpressionStackPush(&stack, 3));

  XCTAssert(FIRCLSDwarfExpressionStackIsValid(&stack));

  XCTAssertEqual(FIRCLSDwarfExpressionStackPop(&stack), (intptr_t)3);
  XCTAssertEqual(FIRCLSDwarfExpressionStackPop(&stack), (intptr_t)2);
  XCTAssertEqual(FIRCLSDwarfExpressionStackPop(&stack), (intptr_t)1);

  XCTAssert(FIRCLSDwarfExpressionStackIsValid(&stack));
}

- (void)testDwarfStackPeek {
  FIRCLSDwarfExpressionStack stack;

  FIRCLSDwarfExpressionStackInit(&stack);

  XCTAssert(FIRCLSDwarfExpressionStackIsValid(&stack));

  XCTAssert(FIRCLSDwarfExpressionStackPush(&stack, 1));
  XCTAssert(FIRCLSDwarfExpressionStackPush(&stack, 2));

  XCTAssertEqual(FIRCLSDwarfExpressionStackPeek(&stack), (intptr_t)2);
  XCTAssertEqual(FIRCLSDwarfExpressionStackPeek(&stack), (intptr_t)2);

  XCTAssertEqual(FIRCLSDwarfExpressionStackPop(&stack), (intptr_t)2);

  XCTAssertEqual(FIRCLSDwarfExpressionStackPeek(&stack), (intptr_t)1);

  XCTAssertEqual(FIRCLSDwarfExpressionStackPop(&stack), (intptr_t)1);
}

- (void)testDwarfStackPushMaxNumberOfValues {
  FIRCLSDwarfExpressionStack stack;

  FIRCLSDwarfExpressionStackInit(&stack);

  for (uint32_t i = 0; i < CLS_DWARF_EXPRESSION_STACK_SIZE; ++i) {
    XCTAssert(FIRCLSDwarfExpressionStackPush(&stack, i));
  }

  XCTAssert(FIRCLSDwarfExpressionStackIsValid(&stack));
  XCTAssertEqual(FIRCLSDwarfExpressionStackPop(&stack),
                 (intptr_t)(CLS_DWARF_EXPRESSION_STACK_SIZE - 1));
}

- (void)testDwarfStackOverflow {
  FIRCLSDwarfExpressionStack stack;

  FIRCLSDwarfExpressionStackInit(&stack);

  for (uint32_t i = 0; i < CLS_DWARF_EXPRESSION_STACK_SIZE; ++i) {
    XCTAssert(FIRCLSDwarfExpressionStackPush(&stack, i));
  }

  XCTAssert(FIRCLSDwarfExpressionStackIsValid(&stack));

  XCTAssertFalse(FIRCLSDwarfExpressionStackPush(&stack, 42),
                 @"Should not be able to push more than the max number of values");
  XCTAssertFalse(FIRCLSDwarfExpressionStackIsValid(&stack));
}

- (void)testDwarfStackPopUnderflow {
  FIRCLSDwarfExpressionStack stack;

  FIRCLSDwarfExpressionStackInit(&stack);

  XCTAssert(FIRCLSDwarfExpressionStackIsValid(&stack));
  XCTAssertEqual(FIRCLSDwarfExpressionStackPop(&stack), 0);
  XCTAssertFalse(FIRCLSDwarfExpressionStackIsValid(&stack));
}

- (void)testDwarfStackPeekUnderflow {
  FIRCLSDwarfExpressionStack stack;

  FIRCLSDwarfExpressionStackInit(&stack);

  XCTAssert(FIRCLSDwarfExpressionStackIsValid(&stack));
  XCTAssertEqual(FIRCLSDwarfExpressionStackPeek(&stack), 0);
  XCTAssertFalse(FIRCLSDwarfExpressionStackIsValid(&stack));
}

- (void)testDwarfExpressionMachineInit {
  FIRCLSDwarfExpressionMachine machine;
  uint8_t fakeData;
  FIRCLSThreadContext registers;

  XCTAssert(FIRCLSDwarfExpressionMachineInit(&machine, (void*)&fakeData, &registers, 42));
  XCTAssert(FIRCLSDwarfExpressionStackIsValid(&machine.stack));

  XCTAssertEqual(FIRCLSDwarfExpressionStackPeek(&machine.stack), 42);
}

#endif

@end
