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

#import "FirebaseDatabase/Tests/Helpers/FTestExpectations.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDataSnapshot.h"

@interface FExpectation : NSObject

@property(strong, nonatomic) FIRDatabaseQuery* query;
@property(strong, nonatomic) id expectation;
@property(strong, nonatomic) FIRDataSnapshot* snap;

@end

@implementation FExpectation

@synthesize query;
@synthesize expectation;
@synthesize snap;

@end

@implementation FTestExpectations

- (id)initFrom:(XCTestCase*)other {
  self = [super init];
  if (self) {
    expectations = [[NSMutableArray alloc] init];
    from = other;
  }
  return self;
}

- (void)addQuery:(FIRDatabaseQuery*)query withExpectation:(id)expectation {
  FExpectation* exp = [[FExpectation alloc] init];
  exp.query = query;
  exp.expectation = expectation;
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot* snapshot) {
                  exp.snap = snapshot;
                }];
  [expectations addObject:exp];
}

- (BOOL)isReady {
  for (FExpectation* exp in expectations) {
    if (!exp.snap) {
      return NO;
    }
    // Note that a failure here will end up triggering the timeout
    FIRDataSnapshot* snap = exp.snap;
    NSDictionary* result = snap.value;
    NSDictionary* expected = exp.expectation;
    if ([result isEqual:[NSNull null]] || ![result isEqualToDictionary:expected]) {
      return NO;
    }
  }
  return YES;
}

- (void)validate {
  for (FExpectation* exp in expectations) {
    FIRDataSnapshot* snap = exp.snap;
    NSDictionary* result = [snap value];
    NSDictionary* expected = exp.expectation;
    XCTAssertTrue([result isEqualToDictionary:expected], @"Expectation mismatch: %@ should be %@",
                  result, expected);
  }
}

- (void)failWithException:(NSException*)anException {
  @throw anException;
  // TODO: fix
  //[from failWithException:anException];
}

@end
