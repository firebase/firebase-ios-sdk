// Copyright 2018 Google
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

#import <XCTest/XCTestCase.h>

#import <GoogleUtilitiesComponents/GULCCComponentContainerInternal.h>
#import <GoogleUtilitiesComponents/GULCCComponentType.h>
#import <OCMock/OCMock.h>

#import "GULCCTestComponents.h"

@interface GULComponentTypeTest : XCTestCase

@property(nonatomic, strong) id componentContainerMock;
@end

@implementation GULComponentTypeTest

- (void)setUp {
  [super setUp];
  _componentContainerMock = OCMClassMock([GULCCComponentContainer class]);
}

- (void)tearDown {
  [super tearDown];
  [_componentContainerMock stopMocking];
}

- (void)testForwardsCallToContainer {
  Protocol *testProtocol = @protocol(GULCCTestProtocol);
  OCMExpect([self.componentContainerMock instanceForProtocol:testProtocol]);

  // Grab an instance from the container, through ComponentType.
  __unused id<GULCCTestProtocol> instance =
      [GULCCComponentType<id<GULCCTestProtocol>> instanceForProtocol:@protocol(GULCCTestProtocol)
                                                         inContainer:self.componentContainerMock];
  OCMVerifyAll(self.componentContainerMock);
}

- (void)testMacroForwardsCallToContainer {
  Protocol *testProtocol = @protocol(GULCCTestProtocol);
  OCMExpect([self.componentContainerMock instanceForProtocol:testProtocol]);

  // Grab an instance from the container, through the macro that uses GULCCComponentType.
  __unused id<GULCCTestProtocol> instance =
      GUL_COMPONENT(GULCCTestProtocol, self.componentContainerMock);

  OCMVerifyAll(self.componentContainerMock);
}
@end
