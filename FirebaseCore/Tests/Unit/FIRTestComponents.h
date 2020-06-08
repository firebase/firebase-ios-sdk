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

#import <Foundation/Foundation.h>

#import "FirebaseCore/Sources/Private/FIRComponent.h"
#import "FirebaseCore/Sources/Private/FIRComponentContainer.h"
#import "FirebaseCore/Sources/Private/FIRLibrary.h"

@protocol FIRComponentRegistrant;

#pragma mark - Standard Component

/// A test protocol to be used for container testing.
@protocol FIRTestProtocol
- (void)doSomething;
@end

/// A test class that is a component registrant.
@interface FIRTestClass : NSObject <FIRTestProtocol, FIRComponentLifecycleMaintainer, FIRLibrary>
@end

/// A test class that is a component registrant, a duplicate of FIRTestClass.
@interface FIRTestClassDuplicate
    : NSObject <FIRTestProtocol, FIRComponentLifecycleMaintainer, FIRLibrary>
@end

#pragma mark - Eager Component

/// A test protocol to be used for container testing.
@protocol FIRTestProtocolEagerCached
- (void)doSomethingFaster;
@end

/// A test class that is a component registrant that provides a component requiring eager
/// instantiation, and is cached for easier validation that it was instantiated.
@interface FIRTestClassEagerCached
    : NSObject <FIRTestProtocolEagerCached, FIRComponentLifecycleMaintainer, FIRLibrary>
@end

#pragma mark - Cached Component

/// A test protocol to be used for container testing.
@protocol FIRTestProtocolCached
- (void)cacheCow;
@end

/// A test class that is a component registrant that provides a component that requests to be
/// cached.
@interface FIRTestClassCached
    : NSObject <FIRTestProtocolCached, FIRComponentLifecycleMaintainer, FIRLibrary>
@end

#pragma mark - Dependency on Standard

/// A test protocol to be used for container testing.
@protocol FIRTestProtocolCachedWithDep
@property(nonatomic, strong) id<FIRTestProtocolCached> testProperty;
@end

/// A test class that is a component registrant that provides a component with a dependency on
// `FIRTestProtocolCached`.
@interface FIRTestClassCachedWithDep
    : NSObject <FIRTestProtocolCachedWithDep, FIRComponentLifecycleMaintainer, FIRLibrary>
@property(nonatomic, strong) id<FIRTestProtocolCached> testProperty;
- (instancetype)initWithTest:(id<FIRTestProtocolCached>)testInstance;
@end
