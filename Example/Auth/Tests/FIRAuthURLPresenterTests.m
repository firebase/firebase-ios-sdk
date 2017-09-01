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

#import <Foundation/Foundation.h>
#import <SafariServices/SafariServices.h>
#import <XCTest/XCTest.h>

#import "FIRAuthURLPresenter.h"
#import "FIRAuthUIDelegate.h"
#import <OCMock/OCMock.h>

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static NSTimeInterval kExpectationTimeout = 1;

@interface FIRAuthDefaultUIDelegate : NSObject <FIRAuthUIDelegate>
/** @fn defaultUIDelegate
    @brief Returns a default FIRAuthUIDelegate object.
    @return The default FIRAuthUIDelegate object.
 */
+ (id<FIRAuthUIDelegate>)defaultUIDelegate;
@end

@interface FIRAuthURLPresenterTests : XCTestCase

@end

@implementation FIRAuthURLPresenterTests

/** @fn testFIRAuthURLPresenterNonNilUIDelegate
    @brief Tests @c FIRAuthURLPresenter class showing UI with a non-nil UIDelegate.
 */
- (void)testFIRAuthURLPresenterNonNilUIDelegate {
 id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));
  NSURL *presenterURL = [NSURL URLWithString:@"https://presenter.url"];
  FIRAuthURLPresenter *presenter = [[FIRAuthURLPresenter alloc] init];

  if ([SFSafariViewController class]) {
    XCTestExpectation *callbackMatcherExpectation =
        [self expectationWithDescription:@"callbackMatcher callback"];
    FIRAuthURLCallbackMatcher callbackMatcher = ^BOOL(NSURL *_Nonnull callbackURL) {
      XCTAssertEqualObjects(callbackURL, presenterURL);
      [callbackMatcherExpectation fulfill];
      return YES;
    };

    XCTestExpectation *completionBlockExpectation =
        [self expectationWithDescription:@"completion callback"];
    FIRAuthURLPresentationCompletion completionBlock = ^(NSURL *_Nullable callbackURL,
                                                         NSError *_Nullable error) {
      XCTAssertEqualObjects(callbackURL, presenterURL);
      XCTAssertNil(error);
      [completionBlockExpectation fulfill];
    };

    id presenterArg = [OCMArg isKindOfClass:[SFSafariViewController class]];
    OCMExpect([mockUIDelegate presentViewController:presenterArg
                                           animated:YES
                                         completion:nil]).andDo(^(NSInvocation *invocation) {
      __unsafe_unretained id unretainedArgument;
      // Indices 0 and 1 indicate the hidden arguments self and _cmd.
      // `presentViewController` is at index 2.
      [invocation getArgument:&unretainedArgument atIndex:2];

      SFSafariViewController *viewController = unretainedArgument;
      XCTAssertEqual(viewController.delegate, presenter);
      XCTAssertTrue([viewController isKindOfClass:[SFSafariViewController class]]);
    });
    [presenter presentURL:presenterURL
               UIDelegate:mockUIDelegate
          callbackMatcher:callbackMatcher
               completion:completionBlock];
    OCMVerifyAll(mockUIDelegate);
    OCMExpect([mockUIDelegate dismissViewControllerAnimated:OCMOCK_ANY
                                                 completion:OCMOCK_ANY]).
          andDo(^(NSInvocation *invocation) {
      __unsafe_unretained id unretainedArgument;
      // Indices 0 and 1 indicate the hidden arguments self and _cmd.
      // `completion` is at index 3.
      [invocation getArgument:&unretainedArgument atIndex:3];
      void (^finishBlock)() = unretainedArgument;
      finishBlock();
    });
    [presenter canHandleURL:presenterURL];
    [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
    OCMVerifyAll(mockUIDelegate);
  }
}

/** @fn testFIRAuthURLPresenterNilUIDelegate
    @brief Tests @c FIRAuthURLPresenter class showing UI with a nil UIDelegate.
 */
- (void)testFIRAuthURLPresenterNilUIDelegate {
  NSURL *presenterURL = [NSURL URLWithString:@"https://presenter.url"];
  FIRAuthURLPresenter *presenter = [[FIRAuthURLPresenter alloc] init];

  if ([SFSafariViewController class]) {
    XCTestExpectation *callbackMatcherExpectation =
        [self expectationWithDescription:@"callbackMatcher callback"];
    FIRAuthURLCallbackMatcher callbackMatcher = ^BOOL(NSURL *_Nonnull callbackURL) {
      XCTAssertEqualObjects(callbackURL, presenterURL);
      [callbackMatcherExpectation fulfill];
      return YES;
    };
    XCTestExpectation *completionBlockExpectation =
        [self expectationWithDescription:@"completion callback"];
    FIRAuthURLPresentationCompletion completionBlock = ^(NSURL *_Nullable callbackURL,
                                                         NSError *_Nullable error) {
      XCTAssertEqualObjects(callbackURL, presenterURL);
      XCTAssertNil(error);
      [completionBlockExpectation fulfill];
    };

    id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));

    // Swizzle default UIDelegate
    Method method = class_getClassMethod([FIRAuthDefaultUIDelegate class],
                                         @selector(defaultUIDelegate));
    __block IMP originalImplementation;
    IMP newImplmentation = imp_implementationWithBlock(^id(id object) {
      return mockUIDelegate;
    });
    originalImplementation = method_setImplementation(method, newImplmentation);
    if ([SFSafariViewController class]) {
      id presenterArg = [OCMArg isKindOfClass:[SFSafariViewController class]];
      OCMExpect([mockUIDelegate presentViewController:presenterArg
                                       animated:[OCMArg any]
                                     completion:[OCMArg any]]).
          andDo(^(NSInvocation *invocation) {
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentViewController` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];
        SFSafariViewController *viewController = unretainedArgument;
        XCTAssertEqual(viewController.delegate, presenter);
        XCTAssertTrue([viewController isKindOfClass:[SFSafariViewController class]]);
      });
    }
    [presenter presentURL:presenterURL
               UIDelegate:nil
          callbackMatcher:callbackMatcher
               completion:completionBlock];
    OCMVerifyAll(mockUIDelegate);

    OCMExpect([mockUIDelegate dismissViewControllerAnimated:OCMOCK_ANY
                                                 completion:OCMOCK_ANY]).
        andDo(^(NSInvocation *invocation) {
      __unsafe_unretained id unretainedArgument;
      // Indices 0 and 1 indicate the hidden arguments self and _cmd.
      // `completion` is at index 3.
      [invocation getArgument:&unretainedArgument atIndex:3];
      void (^finishBlock)() = unretainedArgument;
      finishBlock();
    });
    [presenter canHandleURL:presenterURL];
    [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
    OCMVerifyAll(mockUIDelegate);
    // Unswizzle.
    imp_removeBlock(method_setImplementation(method, originalImplementation));
  }
}

#pragma mark - Method Swizzling

+ (id)mockDefaultUIDelegate {
  return OCMProtocolMock(@protocol(FIRAuthUIDelegate));
}

@end
