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

#import <GoogleUtilitiesComponentContainer/GULComponent.h>
#import <GoogleUtilitiesComponentContainer/GULComponentContainer.h>
#import <GoogleUtilitiesComponentContainer/GULLibrary.h>

@protocol GULComponentRegistrant;

#pragma mark - Standard Component

/// A test protocol to be used for container testing.
@protocol GULTestProtocol
- (void)doSomething;
@end

/// A test class that is a component registrant.
@interface GULTestClass : NSObject <GULTestProtocol, GULComponentLifecycleMaintainer, GULLibrary>
@end

/// A test class that is a component registrant, a duplicate of GULTestClass.
@interface GULTestClassDuplicate
    : NSObject <GULTestProtocol, GULComponentLifecycleMaintainer, GULLibrary>
@end

#pragma mark - Eager Component

/// A test protocol to be used for container testing.
@protocol GULTestProtocolEagerCached
- (void)doSomethingFaster;
@end

/// A test class that is a component registrant that provides a component requiring eager
/// instantiation, and is cached for easier validation that it was instantiated.
@interface GULTestClassEagerCached
    : NSObject <GULTestProtocolEagerCached, GULComponentLifecycleMaintainer, GULLibrary>
@end

#pragma mark - Cached Component

/// A test protocol to be used for container testing.
@protocol GULTestProtocolCached
- (void)cacheCow;
@end

/// A test class that is a component registrant that provides a component that requests to be
/// cached.
@interface GULTestClassCached
    : NSObject <GULTestProtocolCached, GULComponentLifecycleMaintainer, GULLibrary>
@end

#pragma mark - Dependency on Standard

/// A test protocol to be used for container testing.
@protocol GULTestProtocolCachedWithDep
@property(nonatomic, strong) id<GULTestProtocolCached> testProperty;
@end

/// A test class that is a component registrant that provides a component with a dependency on
// `GULTestProtocolCached`.
@interface GULTestClassCachedWithDep
    : NSObject <GULTestProtocolCachedWithDep, GULComponentLifecycleMaintainer, GULLibrary>
@property(nonatomic, strong) id<GULTestProtocolCached> testProperty;
- (instancetype)initWithTest:(id<GULTestProtocolCached>)testInstance;
@end
