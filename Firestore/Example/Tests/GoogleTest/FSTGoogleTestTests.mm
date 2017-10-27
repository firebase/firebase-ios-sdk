/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#include "gtest/gtest.h"

/**
 * An XCTest test case that finds GoogleTest test cases, runs them, and generates results suitable
 * for reporting failures back to Xcode. This allows tests written in C++ that don't rely on XCTest
 * to coexist in this project.
 *
 * Each GoogleTest TestCase is mapped to a dynamically generated XCTestCase class. Each GoogleTest
 * TEST() is mapped to a test method on that XCTestCase. An XCTestSuite is created for each
 * TestCase and added to the suite returned by +defaultTestSuite.
 */
@interface FSTGoogleTestTests : XCTestCase
@end

namespace {

/**
 * Finds the TestInfo corresponding to the test method corresponding to the given test case class
 * and selector. Fails the test and returns nullptr if the TestInfo cannot be found.
 */
const testing::TestInfo *_Nullable FindTestInfo(XCTestCase *self, SEL _cmd) {
  // Find the googletest TestCase name by removing the trailing "Tests"
  NSString *testClassName = NSStringFromClass([self class]);
  NSUInteger end = testClassName.length - 5;
  const char *testCaseName = [[testClassName substringToIndex:end] UTF8String];

  // Find the googletest TestInfo name by removing the leading "test"
  NSString *selectorName = NSStringFromSelector(_cmd);
  const char *testInfoName = [[selectorName substringFromIndex:4] UTF8String];

  // TODO(wilhuff): Avoid linear search here because it makes test execution overall O(n^2)
  const testing::UnitTest *master = testing::UnitTest::GetInstance();
  int testCases = master->total_test_case_count();
  for (int i = 0; i < testCases; i++) {
    const testing::TestCase *testCase = master->GetTestCase(i);
    if (strcmp(testCaseName, testCase->name()) != 0) {
      continue;
    }

    int testInfos = testCase->total_test_count();
    for (int j = 0; j < testInfos; j++) {
      const testing::TestInfo *testInfo = testCase->GetTestInfo(j);
      if (strcmp(testInfoName, testInfo->name()) == 0) {
        return testInfo;
      }
    }
  }

  XCTFail(@"Failed to find a TestInfo corresponding to class %@ method %@", testClassName,
          selectorName);
  return nullptr;
}

/** Finds the TestInfo corresponding to this test and reports it to XCTest */
void ReportTestResult(XCTestCase *self, SEL _cmd) {
  const testing::TestInfo *testInfo = FindTestInfo(self, _cmd);
  if (!testInfo) {
    return;
  }

  if (!testInfo->should_run()) {
    // Test was filtered out by gunit; nothing to report.
    return;
  }

  const testing::TestResult *result = testInfo->result();
  if (result->Passed()) {
    // Let XCode know that the test ran and succeeded.
    XCTAssertTrue(true);
    return;
  }

  // Test failed :-(. Record the failure such that XCode will navigate directly to the file:line.
  int parts = result->total_part_count();
  for (int i = 0; i < parts; i++) {
    const testing::TestPartResult &part = result->GetTestPartResult(i);

    NSString *message = [NSString stringWithCString:part.message() encoding:NSUTF8StringEncoding];
    NSString *fileName = @"";
    if (part.file_name()) {
      fileName = [NSString stringWithCString:part.file_name() encoding:NSUTF8StringEncoding];
    }
    NSUInteger lineNumber = 0;
    if (part.line_number() > 0) {
      lineNumber = part.line_number();
    }

    [self recordFailureWithDescription:message inFile:fileName atLine:lineNumber expected:YES];
  }
}

/**
 * Generates a new subclass of XCTestCase for the given GoogleTest TestCase. Each TestInfo (which
 * represents an indivudal test method execution) is translated into a method on the test case.
 *
 * @return A new Class that's a subclass of XCTestCase, that's been registered with the Objective-C
 *     runtime.
 */
Class CreateXCTestCaseClass(const testing::TestCase *testCase) {
  NSString *testCaseName = [NSString stringWithFormat:@"%sTests", testCase->name()];
  Class testClass = objc_allocateClassPair([XCTestCase class], [testCaseName UTF8String], 0);

  int testInfos = testCase->total_test_count();
  for (int j = 0; j < testInfos; j++) {
    const testing::TestInfo *testInfo = testCase->GetTestInfo(j);

    NSString *selectorName = [NSString stringWithFormat:@"test%s", testInfo->name()];
    SEL selector = sel_registerName([selectorName UTF8String]);
    IMP method = reinterpret_cast<IMP>(ReportTestResult);
    class_addMethod(testClass, selector, method, "v@:");
  }

  objc_registerClassPair(testClass);
  return testClass;
}

}  // namespace

@implementation FSTGoogleTestTests

+ (XCTestSuite *)defaultTestSuite {
  // XCTest calls +defaultTestSuite on any class that extends XCTestCase to generate the suite
  // for that class. Override that to contain a new parent suite containing the default test suite
  // containing test-methods in this class and an additional suite for each GoogleTest TestCase.
  XCTestSuite *suite = [XCTestSuite testSuiteWithName:@"GoogleTests"];

  // Make the default suite for this class run first since that actually runs the GoogleTest tests.
  // Note that this suite can't be used as the parent suite. The result is an XCTestCaseSuite and
  // it expects all of its children to be XCTestCases.
  [suite addTest:[XCTestSuite testSuiteForTestCaseClass:[FSTGoogleTestTests class]]];

  // Initialize GoogleTest but don't run the tests here. This allows XCTest to discover that the
  // tests exist but allows test case selection within Xcode to skip these tests if the user is
  // focusing on something else.
  int argc = 1;
  const char *argv[] = {[NSStringFromClass([FSTGoogleTestTests class]) UTF8String]};
  testing::InitGoogleTest(&argc, const_cast<char **>(argv));

  // Enumerate TestCases and create an XCTestSuite for each one.
  const testing::UnitTest *master = testing::UnitTest::GetInstance();
  int testCases = master->total_test_case_count();
  for (int i = 0; i < testCases; i++) {
    const testing::TestCase *testCase = master->GetTestCase(i);
    Class testClass = CreateXCTestCaseClass(testCase);
    XCTestSuite *subSuite = [XCTestSuite testSuiteForTestCaseClass:testClass];
    [suite addTest:subSuite];
  }

  return suite;
}

- (void)testRunGoogleTests {
  int result = RUN_ALL_TESTS();
  XCTAssertEqual(result, 0);

  // This whole mechanism is sufficiently tricky that we should verify that the build actually
  // plumbed this together correctly.
  const testing::UnitTest *master = testing::UnitTest::GetInstance();
  XCTAssertGreaterThan(master->total_test_case_count(), 0);
}

@end
