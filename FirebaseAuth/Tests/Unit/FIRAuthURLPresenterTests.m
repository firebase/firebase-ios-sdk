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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>
#import <SafariServices/SafariServices.h>
#import <XCTest/XCTest.h>
#import "OCMock.h"

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthUIDelegate.h"

#import "FirebaseAuth/Sources/Utilities/FIRAuthURLPresenter.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthWebViewController.h"

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static NSTimeInterval kExpectationTimeout = 2;

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
  [self testFIRAuthURLPresenterUsingDefaultUIDelegate:NO];
}

/** @fn testFIRAuthURLPresenterNilUIDelegate
    @brief Tests @c FIRAuthURLPresenter class showing UI with a nil UIDelegate.
 */
- (void)testFIRAuthURLPresenterNilUIDelegate {
  [self testFIRAuthURLPresenterUsingDefaultUIDelegate:YES];
}

/** @fn testFIRAuthURLPresenterUsingDefaultUIDelegate:
    @brief Tests @c FIRAuthURLPresenter class showing UIe.
    @param usesDefaultUIDelegate Whether or not to test the default UI delegate.
 */
- (void)testFIRAuthURLPresenterUsingDefaultUIDelegate:(BOOL)usesDefaultUIDelegate {
  id mockUIDelegate = OCMProtocolMock(@protocol(FIRAuthUIDelegate));
  NSURL *presenterURL = [NSURL URLWithString:@"https://presenter.url"];
  FIRAuthURLPresenter *presenter = [[FIRAuthURLPresenter alloc] init];

  if (usesDefaultUIDelegate) {
    id mockDefaultUIDelegateClass = OCMClassMock([FIRAuthDefaultUIDelegate class]);
    OCMStub(ClassMethod([mockDefaultUIDelegateClass defaultUIDelegate])).andReturn(mockUIDelegate);
  }

  __block XCTestExpectation *callbackMatcherExpectation;
  FIRAuthURLCallbackMatcher callbackMatcher = ^BOOL(NSURL *_Nonnull callbackURL) {
    XCTAssertNotNil(callbackMatcherExpectation);
    XCTAssertEqualObjects(callbackURL, presenterURL);
    [callbackMatcherExpectation fulfill];
    return YES;
  };

  __block XCTestExpectation *completionBlockExpectation;
  FIRAuthURLPresentationCompletion completionBlock =
      ^(NSURL *_Nullable callbackURL, NSError *_Nullable error) {
        XCTAssertNotNil(completionBlockExpectation);
        XCTAssertEqualObjects(callbackURL, presenterURL);
        XCTAssertNil(error);
        [completionBlockExpectation fulfill];
      };

  XCTestExpectation *UIPresentationExpectation = [self expectationWithDescription:@"present UI"];
  OCMExpect([mockUIDelegate presentViewController:[OCMArg any] animated:YES completion:nil])
      .andDo(^(NSInvocation *invocation) {
        XCTAssertTrue([NSThread isMainThread]);
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `presentViewController` is at index 2.
        [invocation getArgument:&unretainedArgument atIndex:2];

        id presentViewController = unretainedArgument;
#if TARGET_OS_MACCATALYST
        // SFSafariViewController is not available
        UINavigationController *navigationController = presentViewController;
        XCTAssertTrue([navigationController isKindOfClass:[UINavigationController class]]);
        FIRAuthWebViewController *webViewController =
            navigationController.viewControllers.firstObject;
        XCTAssertTrue([webViewController isKindOfClass:[FIRAuthWebViewController class]]);
#else
        SFSafariViewController *viewController = presentViewController;
        XCTAssertTrue([viewController isKindOfClass:[SFSafariViewController class]]);
        XCTAssertEqual(viewController.delegate, presenter);
#endif
        [UIPresentationExpectation fulfill];
      });

  // Present the content.
  [presenter presentURL:presenterURL
             UIDelegate:usesDefaultUIDelegate ? nil : mockUIDelegate
        callbackMatcher:callbackMatcher
             completion:completionBlock];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(mockUIDelegate);

  // Pretend dismissing view controller.
  OCMExpect([mockUIDelegate dismissViewControllerAnimated:YES completion:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        XCTAssertTrue([NSThread isMainThread]);
        __unsafe_unretained id unretainedArgument;
        // Indices 0 and 1 indicate the hidden arguments self and _cmd.
        // `completion` is at index 3.
        [invocation getArgument:&unretainedArgument atIndex:3];
        void (^completion)(void) = unretainedArgument;
        dispatch_async(dispatch_get_main_queue(), completion);
      });
  completionBlockExpectation = [self expectationWithDescription:@"completion callback"];
  callbackMatcherExpectation = [self expectationWithDescription:@"callbackMatcher callback"];

  // Close the presented content.
  XCTAssertTrue([presenter canHandleURL:presenterURL]);
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(mockUIDelegate);
}

@end

#endif
