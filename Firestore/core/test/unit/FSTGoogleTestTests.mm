/*
 * Copyright 2017 Google LLC
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
 * An XCTest test case that finds C++ test cases written in the GoogleTest
 * framework, runs them, and reports the results back to Xcode. This allows
 * tests written in C++ that don't rely on XCTest to coexist in this project.
 *
 * As an extra feature, you can run all C++ tests by focusing on the GoogleTests
 * class.
 *
 * Each GoogleTest TestCase is mapped to a dynamically generated XCTestCase
 * class. Each GoogleTest TEST() is mapped to a test method on that XCTestCase.
 */
@interface GoogleTests : XCTestCase
@end

namespace {

// A testing::TestCase named "Foo" corresponds to an XCTestCase named
// "FooTests".
NSString* const kTestCaseSuffix = @"Tests";

// A testing::TestInfo named "Foo" corresponds to test method named "testFoo".
NSString* const kTestMethodPrefix = @"test";

// A map of keys created by TestInfoKey to the corresponding testing::TestInfo
// (wrapped in an NSValue). The generated XCTestCase classes are discovered and
// instantiated by XCTest so this is the only means of plumbing per-test-method
// state into these methods.
NSDictionary<NSString*, NSValue*>* testInfosByKey;

// If the user focuses on GoogleTests itself, this means force all C++ tests to
// run.
bool forceAllTests = false;

void RunGoogleTestTests();

/**
 * Loads this XCTest runner's configuration file and figures out which tests to
 * run based on the contents of that configuration file.
 *
 * @return the set of tests to run, or nil if the user asked for all tests or if
 * there's any problem loading or parsing the configuration.
 */
NSSet<NSString*>* _Nullable LoadXCTestConfigurationTestsToRun() {
  // Xcode invokes the test runner with an XCTestConfigurationFilePath
  // environment variable set to the path of a configuration file containing,
  // among other things, the set of tests to run. The configuration file
  // deserializes to a non-public XCTestConfiguration class.
  //
  // This loads that file and then reflectively pulls out the testsToRun set.
  // Just in case any of these private details should change in the future and
  // something should fail here, the mechanism complains but fails open. This
  // way the worst that can happen is that users end up running more tests than
  // they intend, but we never accidentally show a green run that wasn't.
  static NSString* const configEnvVar = @"XCTestConfigurationFilePath";

  NSDictionary<NSString*, NSString*>* env =
      [[NSProcessInfo processInfo] environment];
  NSString* filePath = [env objectForKey:configEnvVar];
  if (!filePath) {
    NSLog(@"Missing %@ environment variable; assuming all tests", configEnvVar);
    return nil;
  }

  id config;
  NSError* error;
  if (@available(macOS 10.13, iOS 11, tvOS 11, *)) {
    NSData* data = [NSData dataWithContentsOfFile:filePath
                                          options:kNilOptions
                                            error:&error];
    if (!data) {
      NSLog(@"Failed to fill data with contents of file. %@", error);
      return nil;
    }

    config = [NSKeyedUnarchiver unarchivedObjectOfClass:NSObject.class
                                               fromData:data
                                                  error:&error];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    config = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
#pragma clang diagnostic pop
  }

  if (!config) {
    NSLog(@"Failed to load any configuration from %@=%@. %@", configEnvVar,
          filePath, error);
    return nil;
  }

  SEL testsToRunSelector = NSSelectorFromString(@"testsToRun");
  if (![config respondsToSelector:testsToRunSelector]) {
    NSLog(@"Invalid configuration from %@=%@: missing testsToRun", configEnvVar,
          filePath);
    return nil;
  }

  // Invoke the testsToRun selector safely. This indirection is required because
  // just calling -performSelector: fails to properly retain the NSSet under
  // ARC.
  typedef NSSet<NSString*>* (*TestsToRunFunction)(id, SEL);
  IMP testsToRunMethod = [config methodForSelector:testsToRunSelector];
  auto testsToRunFunction =
      reinterpret_cast<TestsToRunFunction>(testsToRunMethod);
  return testsToRunFunction(config, testsToRunSelector);
}

/**
 * Creates a GoogleTest filter specification, suitable for passing to the
 * --gtest_filter flag, that limits GoogleTest to running the same set of tests
 * that Xcode requested.
 *
 * Each member of the testsToRun set is mapped as follows:
 *
 *   * Bare class: "ClassTests" => "Class.*"
 *   * Class and method: "ClassTests/testMethod" => "Class.Method"
 *
 * These members are then joined with a ":" as googletest requires.
 *
 * @see
 * https://github.com/google/googletest/blob/main/docs/advanced.md
 */
NSString* CreateTestFiltersFromTestsToRun(NSSet<NSString*>* testsToRun) {
  NSMutableString* result = [[NSMutableString alloc] init];
  for (NSString* spec in testsToRun) {
    NSArray<NSString*>* parts = [spec componentsSeparatedByString:@"/"];

    NSString* gtestCaseName = nil;
    if (parts.count > 0) {
      NSString* className = parts[0];
      if ([className hasSuffix:kTestCaseSuffix]) {
        gtestCaseName = [className
            substringToIndex:className.length - kTestCaseSuffix.length];
      }
    }

    NSString* gtestMethodName = nil;
    if (parts.count > 1) {
      NSString* methodName = parts[1];
      if ([methodName hasPrefix:kTestMethodPrefix]) {
        gtestMethodName =
            [methodName substringFromIndex:kTestMethodPrefix.length];
      }
    }

    if (gtestCaseName) {
      if (result.length > 0) {
        [result appendString:@":"];
      }
      [result appendString:gtestCaseName];
      [result appendString:@"."];
      [result appendString:(gtestMethodName ? gtestMethodName : @"*")];
    }
  }

  return result;
}

/** Returns the name of the selector for the test method representing this
 * specific test. */
NSString* SelectorNameForTestInfo(const testing::TestInfo* testInfo) {
  return
      [NSString stringWithFormat:@"%@%s", kTestMethodPrefix, testInfo->name()];
}

/** Returns the name of the class representing the given testing::TestCase. */
NSString* ClassNameForTestCase(const testing::TestCase* testCase) {
  return [NSString stringWithFormat:@"%s%@", testCase->name(), kTestCaseSuffix];
}

/**
 * Returns a key name for the testInfosByKey dictionary. Each (class, selector)
 * pair corresponds to a unique GoogleTest result.
 */
NSString* TestInfoKey(Class testClass, SEL testSelector) {
  return [NSString stringWithFormat:@"%@.%@", NSStringFromClass(testClass),
                                    NSStringFromSelector(testSelector)];
}

/**
 * A function that is the implementation for each generated test method. It
 * shouldn't be used directly--instead use it with class_addMethod to define the
 * behavior of the generated XCTestCase class.
 *
 * The first invocation of this method runs all GoogleTest tests. Delaying
 * execution this way allows XCTest to register to the test runner that it
 * actually has started.
 *
 * Looks up the testing::TestInfo for this test method and reports on the
 * outcome to XCTest, as if the test actually ran in this method.
 *
 * Note: The parameter names of self and _cmd match up with the implicit
 * parameters passed to any Objective-C method. Naming them this way here allows
 * XCTAssert and friends to work.
 */
void XCTestMethod(XCTestCase* self, SEL _cmd) {
  RunGoogleTestTests();

  NSString* testInfoKey = TestInfoKey([self class], _cmd);
  NSValue* holder = testInfosByKey[testInfoKey];
  auto testInfo = static_cast<const testing::TestInfo*>(holder.pointerValue);
  if (!testInfo) {
    return;
  }

  if (!testInfo->should_run()) {
    // Test was filtered out by gunit; nothing to report.
    return;
  }

  const testing::TestResult* result = testInfo->result();
  if (result->Passed()) {
    // Let Xcode know that the test ran and succeeded.
    XCTAssertTrue(true);
    return;
  } else if (result->Skipped()) {
    // Let Xcode know that the test was skipped.
    XCTSkip();
  }

  // Test failed :-(. Record the failure such that Xcode will navigate directly
  // to the file:line.
  int parts = result->total_part_count();
  for (int i = 0; i < parts; i++) {
    const testing::TestPartResult& part = result->GetTestPartResult(i);
    const char* path = part.file_name() ? part.file_name() : "";
    int line = part.line_number() > 0 ? part.line_number() : 0;

    auto* location = [[XCTSourceCodeLocation alloc] initWithFilePath:@(path)
                                                          lineNumber:line];
    auto* context = [[XCTSourceCodeContext alloc] initWithLocation:location];
    auto* issue = [[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
                              compactDescription:@(part.summary())
                             detailedDescription:@(part.message())
                               sourceCodeContext:context
                                 associatedError:nil
                                     attachments:@[]];
    [self recordIssue:issue];
  }
}

/**
 * Generates a new subclass of XCTestCase for the given GoogleTest TestCase.
 * Each TestInfo (which represents an individual test method execution) is
 * translated into a method on the test case.
 *
 * @param testCase The testing::TestCase of interest to translate.
 * @param infoMap A map of TestInfoKeys to testing::TestInfos, populated by this
 *     method.
 *
 * @return A new Class that's a subclass of XCTestCase, that's been registered
 * with the Objective-C runtime.
 */
Class CreateXCTestCaseClass(const testing::TestCase* testCase,
                            NSMutableDictionary<NSString*, NSValue*>* infoMap) {
  NSString* testCaseName = ClassNameForTestCase(testCase);
  Class testClass =
      objc_allocateClassPair([XCTestCase class], [testCaseName UTF8String], 0);

  // Create a method for each TestInfo.
  int testInfos = testCase->total_test_count();
  for (int j = 0; j < testInfos; j++) {
    const testing::TestInfo* testInfo = testCase->GetTestInfo(j);

    NSString* selectorName = SelectorNameForTestInfo(testInfo);
    SEL selector = sel_registerName([selectorName UTF8String]);

    // Use the XCTestMethod function as the method implementation. The v@:
    // indicates it is a void objective-C method; this must continue to match
    // the signature of XCTestMethod.
    IMP method = reinterpret_cast<IMP>(XCTestMethod);
    class_addMethod(testClass, selector, method, "v@:");

    NSString* infoKey = TestInfoKey(testClass, selector);
    NSValue* holder = [NSValue valueWithPointer:testInfo];
    infoMap[infoKey] = holder;
  }
  objc_registerClassPair(testClass);

  return testClass;
}

/**
 * Creates a test suite containing all C++ tests, used when the user starts the
 * GoogleTests class.
 *
 * Note: normally XCTest finds all the XCTestCase classes that are registered
 * with the run time and asks them to create suites for themselves. When a user
 * focuses on the GoogleTests class, XCTest no longer does this so we have to
 * force XCTest to see more tests than it would normally look at so that the
 * indicators in the test navigator update properly.
 */
XCTestSuite* CreateAllTestsTestSuite() {
  XCTestSuite* allTestsSuite =
      [[XCTestSuite alloc] initWithName:@"All GoogleTest Tests"];
  [allTestsSuite
      addTest:[XCTestSuite testSuiteForTestCaseClass:[GoogleTests class]]];

  const testing::UnitTest* main = testing::UnitTest::GetInstance();

  int testCases = main->total_test_case_count();
  for (int i = 0; i < testCases; i++) {
    const testing::TestCase* testCase = main->GetTestCase(i);
    NSString* testCaseName = ClassNameForTestCase(testCase);
    Class testClass = objc_getClass([testCaseName UTF8String]);
    [allTestsSuite addTest:[XCTestSuite testSuiteForTestCaseClass:testClass]];
  }

  return allTestsSuite;
}

/**
 * Finds and runs googletest-based tests based on the XCTestConfiguration of the
 * current test invocation.
 */
void CreateGoogleTestTests() {
  NSString* mainTestCaseName = NSStringFromClass([GoogleTests class]);

  // Initialize GoogleTest but don't run the tests yet.
  int argc = 1;
  const char* argv[] = {[mainTestCaseName UTF8String]};
  testing::InitGoogleTest(&argc, const_cast<char**>(argv));

  // Convert XCTest's testToRun set to the equivalent --gtest_filter flag.
  //
  // Note that we only set forceAllTests to true if the user specifically
  // focused on GoogleTests. This prevents XCTest double-counting test cases
  // (and failures) when a user asks for all tests.
  NSSet<NSString*>* allTests = [NSSet setWithObject:mainTestCaseName];
  NSSet<NSString*>* testsToRun = LoadXCTestConfigurationTestsToRun();
  if (testsToRun) {
    if ([allTests isEqual:testsToRun]) {
      NSLog(@"Forcing all tests to run");
      forceAllTests = true;
    } else {
      NSString* filters = CreateTestFiltersFromTestsToRun(testsToRun);
      NSLog(@"Using --gtest_filter=%@", filters);
      if (filters) {
        testing::GTEST_FLAG(filter) = [filters UTF8String];
      }
    }
  }

  // Create XCTestCases and populate the testInfosByKey map
  const testing::UnitTest* main = testing::UnitTest::GetInstance();
  NSMutableDictionary<NSString*, NSValue*>* infoMap =
      [NSMutableDictionary dictionaryWithCapacity:main->total_test_count()];

  int testCases = main->total_test_case_count();
  for (int i = 0; i < testCases; i++) {
    const testing::TestCase* testCase = main->GetTestCase(i);
    CreateXCTestCaseClass(testCase, infoMap);
  }
  testInfosByKey = infoMap;
}

void RunGoogleTestTests() {
  static bool firstRun = true;

  if (firstRun) {
    firstRun = false;
    int result = RUN_ALL_TESTS();

    // RUN_ALL_TESTS by default doesn't want you to ignore its result, but it's
    // safe here. Test failures are already logged by GoogleTest itself (and
    // then again by XCTest). Test failures are reported via
    // -recordFailureWithDescription:inFile:atLine:expected: which then causes
    // XCTest itself to fail the run.
    (void)result;
  }
}

}  // namespace

@implementation GoogleTests

+ (XCTestSuite*)defaultTestSuite {
  // Only return all tests beyond GoogleTests if the user is focusing on
  // GoogleTests.
  if (forceAllTests) {
    return CreateAllTestsTestSuite();
  } else {
    // just run the tests that are a part of this class
    return [XCTestSuite testSuiteForTestCaseClass:[self class]];
  }
}

- (void)testGoogleTestsActuallyRun {
  // This whole mechanism is sufficiently tricky that we should verify that the
  // build actually plumbed this together correctly.
  const testing::UnitTest* main = testing::UnitTest::GetInstance();
  XCTAssertGreaterThan(main->total_test_case_count(), 0);
}

@end

/**
 * This class is registered as the NSPrincipalClass in the Firestore_Tests
 * bundle's Info.plist. XCTest instantiates this class to perform one-time setup
 * for the test bundle, as documented here:
 *
 *   https://developer.apple.com/documentation/xctest/xctestobservationcenter
 */
@interface FSTGoogleTestsPrincipal : NSObject
@end

@implementation FSTGoogleTestsPrincipal

- (instancetype)init {
  self = [super init];
  CreateGoogleTestTests();
  return self;
}

@end
