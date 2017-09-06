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
#import <XCTest/XCTest.h>

@interface FEventTester : XCTestCase

- (id)initFrom:(XCTestCase*)elsewhere;
- (void)addLookingFor:(NSArray*)l;
- (void)wait;
- (void)waitForInitialization;
- (void)unregister;

@property(nonatomic, strong) NSMutableArray* lookingFor;
@property(readwrite) int callbacksCalled;
@property(nonatomic, strong) NSMutableDictionary* seenFirebaseLocations;
//@property (nonatomic, strong) NSMutableDictionary* initializationEvents;
@property(nonatomic, strong) XCTestCase* from;
@property(nonatomic, strong) NSMutableArray* errors;
@property(nonatomic, strong) NSMutableArray* actualPathsAndEvents;
@property(nonatomic) int initializationEvents;

@end
