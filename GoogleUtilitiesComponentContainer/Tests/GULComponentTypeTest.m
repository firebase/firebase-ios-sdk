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

#import <GoogleUtilitiesComponentContainer/GULComponentContainerInternal.h>
#import <GoogleUtilitiesComponentContainer/GULComponentType.h>
#import <OCMock/OCMock.h>

#import "GULTestComponents.h"

@interface GULComponentTypeTest : XCTestCase

@property(nonatomic, strong) id componentContainerMock;
@end

@implementation GULComponentTypeTest

- (void)setUp {
  [super setUp];
  _componentContainerMock = OCMClassMock([GULComponentContainer class]);
}

- (void)tearDown {
  [super tearDown];
  [_componentContainerMock stopMocking];
}

- (void)testForwardsCallToContainer {
  Protocol *testProtocol = @protocol(GULTestProtocol);
  OCMExpect([self.componentContainerMock instanceForProtocol:testProtocol]);

  // Grab an instance from the container, through ComponentType.
  __unused id<GULTestProtocol> instance =
      [GULComponentType<id<GULTestProtocol>> instanceForProtocol:@protocol(GULTestProtocol)
                                                     inContainer:self.componentContainerMock];
  OCMVerifyAll(self.componentContainerMock);
}

- (void)testMacroForwardsCallToContainer {
  Protocol *testProtocol = @protocol(GULTestProtocol);
  OCMExpect([self.componentContainerMock instanceForProtocol:testProtocol]);

  // Grab an instance from the container, through the macro that uses GULComponentType.
  __unused id<GULTestProtocol> instance =
      GUL_COMPONENT(GULTestProtocol, self.componentContainerMock);

  OCMVerifyAll(self.componentContainerMock);
}
@end
