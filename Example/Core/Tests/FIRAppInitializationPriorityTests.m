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

#import <XCTest/XCTest.h>
#import "FIRTestCase.h"
#import "FIRTestComponents.h"
#import <FirebaseCore/FIRAppInternal.h>


#pragma mark - Base class (FIRTestClassForInitiationPriority)

/// A test class that is used for the initiation priority test cases.
@interface FIRTestClassForInitiationPriority: FIRTestClass

+ (NSArray<Class<FIRLibrary>> *)initializationOrder;

@end

@implementation FIRTestClassForInitiationPriority

static NSMutableArray<Class<FIRLibrary>> *_initializationOrder;

+ (NSArray<Class<FIRLibrary>> *)initializationOrder {
    return _initializationOrder;
}

+ (void)configureWithApp:(nonnull FIRApp *)app {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      _initializationOrder = [[NSMutableArray alloc] init];
    });
    
    [_initializationOrder addObject:[self class]];
}

@end

#pragma mark - Subclasses needed for tests

@interface FIRTestClassForInitiationPriorityUrgent: FIRTestClassForInitiationPriority
@end

@implementation FIRTestClassForInitiationPriorityUrgent
@end

@interface FIRTestClassForInitiationPriorityHigh: FIRTestClassForInitiationPriority
@end

@implementation FIRTestClassForInitiationPriorityHigh
@end

@interface FIRTestClassForInitiationPriorityNormal: FIRTestClassForInitiationPriority
@end

@implementation FIRTestClassForInitiationPriorityNormal
@end

@interface FIRTestClassForInitiationPriorityNormal2: FIRTestClassForInitiationPriority
@end

@implementation FIRTestClassForInitiationPriorityNormal2
@end

@interface FIRTestClassForInitiationPriorityLow: FIRTestClassForInitiationPriority
@end

@implementation FIRTestClassForInitiationPriorityLow
@end

#pragma mark - Tests

/** @class FIRAppInitializationPriorityTests
    @brief Tests for @c FIRAppInitializationPriorityTests
 */
@interface FIRAppInitializationPriorityTests : XCTestCase
@end

@implementation FIRAppInitializationPriorityTests

- (void)testRegisterLibraryHonorsInitializationPriority {
    Class urgentClass = [FIRTestClassForInitiationPriorityUrgent class];
    [FIRApp registerInternalLibrary:urgentClass withName:@"UrgentClass" withVersion:@"1.0.0" withPriority:FIRInitializationPriorityUrgent];
    
    Class lowClass = [FIRTestClassForInitiationPriorityLow class];
    [FIRApp registerInternalLibrary:lowClass withName:@"LowClass" withVersion:@"1.0.0" withPriority:FIRInitializationPriorityLow];
    
  Class normalClass = [FIRTestClassForInitiationPriorityNormal class];
  [FIRApp registerInternalLibrary:normalClass withName:@"NormalClass" withVersion:@"1.0.0" withPriority:FIRInitializationPriorityNormal];
    
    Class highClass = [FIRTestClassForInitiationPriorityHigh class];
    [FIRApp registerInternalLibrary:highClass withName:@"HighClass" withVersion:@"1.0.0" withPriority:FIRInitializationPriorityHigh];
    
    Class normalClass2 = [FIRTestClassForInitiationPriorityNormal2 class];
    [FIRApp registerInternalLibrary:normalClass2 withName:@"NormalClass2" withVersion:@"1.0.0" withPriority:FIRInitializationPriorityNormal];
    
  [FIRApp configure];
    
    NSArray<Class<FIRLibrary>> *ordering = FIRTestClassForInitiationPriority.initializationOrder;
    XCTAssertEqual(ordering.count, 5);
    XCTAssertEqual(ordering[0], urgentClass);
    XCTAssertEqual(ordering[1], highClass);
    XCTAssertEqual(ordering[2], normalClass);
    XCTAssertEqual(ordering[3], normalClass2);
    XCTAssertEqual(ordering[4], lowClass);
}

@end
