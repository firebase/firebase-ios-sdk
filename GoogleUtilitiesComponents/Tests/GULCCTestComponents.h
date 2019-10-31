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

#import <Foundation/Foundation.h>

#import <GoogleUtilitiesComponents/GULCCComponent.h>
#import <GoogleUtilitiesComponents/GULCCComponentContainer.h>
#import <GoogleUtilitiesComponents/GULCCLibrary.h>

#pragma mark - Standard Component

/// A test protocol to be used for container testing.
@protocol GULCCTestProtocol
- (void)doSomething;
@end

/// A test class that is a component registrant.
@interface GULCCTestClass
    : NSObject <GULCCTestProtocol, GULCCComponentLifecycleMaintainer, GULCCLibrary>
@end

/// A test class that is a component registrant, a duplicate of GULCCTestClass.
@interface GULCCTestClassDuplicate
    : NSObject <GULCCTestProtocol, GULCCComponentLifecycleMaintainer, GULCCLibrary>
@end

#pragma mark - Eager Component

/// A test protocol to be used for container testing.
@protocol GULCCTestProtocolEagerCached
- (void)doSomethingFaster;
@end

/// A test class that is a component registrant that provides a component requiring eager
/// instantiation, and is cached for easier validation that it was instantiated.
@interface GULCCTestClassEagerCached
    : NSObject <GULCCTestProtocolEagerCached, GULCCComponentLifecycleMaintainer, GULCCLibrary>
@end

#pragma mark - Cached Component

/// A test protocol to be used for container testing.
@protocol GULCCTestProtocolCached
- (void)cacheCow;
@end

/// A test class that is a component registrant that provides a component that requests to be
/// cached.
@interface GULCCTestClassCached
    : NSObject <GULCCTestProtocolCached, GULCCComponentLifecycleMaintainer, GULCCLibrary>
@end

#pragma mark - Dependency on Standard

/// A test protocol to be used for container testing.
@protocol GULCCTestProtocolCachedWithDep
@property(nonatomic, strong) id<GULCCTestProtocolCached> testProperty;
@end

/// A test class that is a component registrant that provides a component with a dependency on
// `GULCCTestProtocolCached`.
@interface GULCCTestClassCachedWithDep
    : NSObject <GULCCTestProtocolCachedWithDep, GULCCComponentLifecycleMaintainer, GULCCLibrary>
@property(nonatomic, strong) id<GULCCTestProtocolCached> testProperty;
- (instancetype)initWithTest:(id<GULCCTestProtocolCached>)testInstance;
@end
