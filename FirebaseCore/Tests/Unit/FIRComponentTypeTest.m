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

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"

#import "FirebaseCore/Sources/FIRComponentContainerInternal.h"
#import "FirebaseCore/Sources/Private/FIRComponentType.h"

#import "FirebaseCore/Tests/Unit/FIRTestComponents.h"

@interface FIRComponentTypeTest : FIRTestCase

@property(nonatomic, strong) id componentContainerMock;
@end

@implementation FIRComponentTypeTest

- (void)setUp {
  [super setUp];
  _componentContainerMock = OCMClassMock([FIRComponentContainer class]);
}

- (void)tearDown {
  [super tearDown];
  [_componentContainerMock stopMocking];
}

- (void)testForwardsCallToContainer {
  Protocol *testProtocol = @protocol(FIRTestProtocol);
  OCMExpect([self.componentContainerMock instanceForProtocol:testProtocol]);

  // Grab an instance from the container, through ComponentType.
  __unused id<FIRTestProtocol> instance =
      [FIRComponentType<id<FIRTestProtocol>> instanceForProtocol:@protocol(FIRTestProtocol)
                                                     inContainer:self.componentContainerMock];
  OCMVerifyAll(self.componentContainerMock);
}

- (void)testMacroForwardsCallToContainer {
  Protocol *testProtocol = @protocol(FIRTestProtocol);
  OCMExpect([self.componentContainerMock instanceForProtocol:testProtocol]);

  // Grab an instance from the container, through the macro that uses FIRComponentType.
  __unused id<FIRTestProtocol> instance =
      FIR_COMPONENT(FIRTestProtocol, self.componentContainerMock);

  OCMVerifyAll(self.componentContainerMock);
}
@end
