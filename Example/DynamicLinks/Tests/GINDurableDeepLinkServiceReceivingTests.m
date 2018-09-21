/*
 * Copyright 2018 Google
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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "DynamicLinks/GINDurableDeepLinkServiceReceiving+Private.h"
#import "OCMock.h"

@interface GINDurableDeepLinkServiceReceivingTests : XCTestCase
@end

@implementation GINDurableDeepLinkServiceReceivingTests

- (void)testGINGetMainWindowRetrievesWindowWhenWindowIsKey {
  UIWindow *window = [[UIWindow alloc] init];

  id application = OCMPartialMock([UIApplication sharedApplication]);
  [[[application stub] andReturn:window] keyWindow];

  id returnedObject = GINGetMainWindow(application);

  XCTAssertEqual(returnedObject, window);
}

- (void)testGINGetMainWindowRetrievesWindowWhenWindowIsDelegateWindowAndNotKey {
  UIWindow *window = [[UIWindow alloc] init];

  id appDelegate = OCMProtocolMock(@protocol(UIApplicationDelegate));
  [[[appDelegate stub] andReturn:window] window];

  id application = OCMPartialMock([UIApplication sharedApplication]);
  [[[application stub] andReturn:nil] keyWindow];
  [[[application stub] andReturn:appDelegate] delegate];

  id returnedObject = GINGetMainWindow(application);

  XCTAssertEqual(returnedObject, window);
}

- (void)testGINGetMainWindowRetrievesNilWhenNoKeyWindowAndNoDelegateWindow {
  id application = OCMPartialMock([UIApplication sharedApplication]);
  [[[application stub] andReturn:nil] keyWindow];
  [[[application stub] andReturn:OCMOCK_ANY] delegate];

  id returnedObject = GINGetMainWindow(application);

  XCTAssertNil(returnedObject);
}

- (void)testGINGetTopViewControllerFromViewControllerReturnsNilWithNilVC {
  id returnedObject = GINGetTopViewControllerFromViewController(nil);

  XCTAssertNil(returnedObject);
}

- (void)testGINGetTopViewControllerFromViewControllerReturnsSameVCWhenNotAContainerVC {
  UIViewController *viewController = [[UIViewController alloc] init];
  id returnedObject = GINGetTopViewControllerFromViewController(viewController);

  XCTAssertEqual(viewController, returnedObject);
}

- (void)testGINGetTopViewControllerFromViewControllerReturnsTopVCOfNavVC {
  UIViewController *topViewController = [[UIViewController alloc] init];
  UINavigationController *navViewController =
      [[UINavigationController alloc] initWithRootViewController:topViewController];

  id returnedObject = GINGetTopViewControllerFromViewController(navViewController);

  XCTAssertEqual(topViewController, returnedObject);
}

- (void)testGINGetTopViewControllerFromViewControllerReturnsFocusOfTabVC {
  UIViewController *tabVC = [[UIViewController alloc] init];
  UITabBarController *tabBarController = [[UITabBarController alloc] init];
  tabBarController.viewControllers = @[ tabVC ];

  id returnedObject = GINGetTopViewControllerFromViewController(tabBarController);

  XCTAssertEqual(tabVC, returnedObject);
}

- (void)testGINGetTopViewControllerFromViewControllerRetunsPresentedViewController {
  UIViewController *presentedViewController = [[UIViewController alloc] init];

  id presentingViewController = OCMPartialMock([[UIViewController alloc] init]);
  [[[presentingViewController stub] andReturn:presentedViewController] presentedViewController];

  id returnedObject = GINGetTopViewControllerFromViewController(presentingViewController);

  XCTAssertEqual(presentedViewController, returnedObject);
}

- (void)testGINRemoveViewControllerFromHierarchyRemovesFromParent {
  id viewController = OCMClassMock([UIViewController class]);
  [[[viewController stub] andReturn:OCMOCK_ANY] parentViewController];
  [OCMStub([viewController removeFromParentViewController]) andDo:nil];

  GINRemoveViewControllerFromHierarchy(viewController);

  OCMVerify([viewController removeFromParentViewController]);
}

- (void)testGINRemoveViewControllerFromHierarchyRemovesViewFromSuperview {
  id view = OCMClassMock([UIView class]);
  [[[view stub] andReturn:OCMOCK_ANY] superview];
  [OCMStub([view removeFromSuperview]) andDo:nil];

  id viewController = OCMPartialMock([[UIViewController alloc] init]);
  [[[viewController stub] andReturn:view] view];

  GINRemoveViewControllerFromHierarchy(viewController);

  OCMVerify([view removeFromSuperview]);
}

- (void)testGINRemoveViewControllerFromHierarchyDoesntRemoveFromParentIfNoParent {
  id viewController = OCMClassMock([UIViewController class]);
  [[[viewController stub] andReturn:nil] parentViewController];
  [[viewController reject] removeFromParentViewController];

  GINRemoveViewControllerFromHierarchy(viewController);

  [viewController verify];
}

- (void)testGINRemoveViewControllerFromHierarchyDoesntRemoveViewFromSuperviewIfNoSuperview {
  id view = OCMClassMock([UIView class]);
  [[[view stub] andReturn:nil] superview];
  [[view reject] removeFromSuperview];

  id viewController = OCMPartialMock([[UIViewController alloc] init]);
  [[[viewController stub] andReturn:view] view];

  GINRemoveViewControllerFromHierarchy(viewController);

  [view verify];
}

@end
