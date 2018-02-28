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

#import "Firestore/Source/Model/FSTMutation.h"

#import <FirebaseFirestore/FIRTimestamp.h>
#import <XCTest/XCTest.h>

#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

@interface FSTMutationTests : XCTestCase
@end

@implementation FSTMutationTests {
  FIRTimestamp *_timestamp;
}

- (void)setUp {
  _timestamp = [FIRTimestamp timestamp];
}

- (void)testAppliesSetsToDocuments {
  NSDictionary *docData = @{@"foo" : @"foo-value", @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc(@"collection/key", 0, docData, NO);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"bar" : @"bar-value"});
  FSTMaybeDocument *setDoc = [set applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{@"bar" : @"bar-value"};
  XCTAssertEqualObjects(setDoc, FSTTestDoc(@"collection/key", 0, expectedData, YES));
}

- (void)testAppliesPatchesToDocuments {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value"}, @"baz" : @"baz-value" };
  FSTDocument *baseDoc = FSTTestDoc(@"collection/key", 0, docData, NO);

  FSTMutation *patch =
      FSTTestPatchMutation(@"collection/key", @{@"foo.bar" : @"new-bar-value"}, nil);
  FSTMaybeDocument *patchedDoc =
      [patch applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{ @"foo" : @{@"bar" : @"new-bar-value"}, @"baz" : @"baz-value" };
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc(@"collection/key", 0, expectedData, YES));
}

- (void)testDeletesValuesFromTheFieldMask {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value", @"baz" : @"baz-value"} };
  FSTDocument *baseDoc = FSTTestDoc(@"collection/key", 0, docData, NO);

  FSTDocumentKey *key = FSTTestDocKey(@"collection/key");
  FSTFieldMask *mask = [[FSTFieldMask alloc] initWithFields:@[ FSTTestFieldPath(@"foo.bar") ]];
  FSTMutation *patch = [[FSTPatchMutation alloc] initWithKey:key
                                                   fieldMask:mask
                                                       value:[FSTObjectValue objectValue]
                                                precondition:[FSTPrecondition none]];
  FSTMaybeDocument *patchedDoc =
      [patch applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{ @"foo" : @{@"baz" : @"baz-value"} };
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc(@"collection/key", 0, expectedData, YES));
}

- (void)testPatchesPrimitiveValue {
  NSDictionary *docData = @{@"foo" : @"foo-value", @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc(@"collection/key", 0, docData, NO);

  FSTMutation *patch =
      FSTTestPatchMutation(@"collection/key", @{@"foo.bar" : @"new-bar-value"}, nil);
  FSTMaybeDocument *patchedDoc =
      [patch applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{ @"foo" : @{@"bar" : @"new-bar-value"}, @"baz" : @"baz-value" };
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc(@"collection/key", 0, expectedData, YES));
}

- (void)testPatchingDeletedDocumentsDoesNothing {
  FSTMaybeDocument *baseDoc = FSTTestDeletedDoc(@"collection/key", 0);
  FSTMutation *patch = FSTTestPatchMutation(@"collection/key", @{@"foo" : @"bar"}, nil);
  FSTMaybeDocument *patchedDoc =
      [patch applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];
  XCTAssertEqualObjects(patchedDoc, baseDoc);
}

- (void)testAppliesLocalTransformsToDocuments {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value"}, @"baz" : @"baz-value" };
  FSTDocument *baseDoc = FSTTestDoc(@"collection/key", 0, docData, NO);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @[ @"foo.bar" ]);
  FSTMaybeDocument *transformedDoc =
      [transform applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  // Server timestamps aren't parsed, so we manually insert it.
  FSTObjectValue *expectedData = FSTTestObjectValue(
      @{ @"foo" : @{@"bar" : @"<server-timestamp>"},
         @"baz" : @"baz-value" });
  expectedData =
      [expectedData objectBySettingValue:[FSTServerTimestampValue
                                             serverTimestampValueWithLocalWriteTime:_timestamp
                                                                      previousValue:nil]
                                 forPath:FSTTestFieldPath(@"foo.bar")];

  FSTDocument *expectedDoc = [FSTDocument documentWithData:expectedData
                                                       key:FSTTestDocKey(@"collection/key")
                                                   version:FSTTestVersion(0)
                                         hasLocalMutations:YES];

  XCTAssertEqualObjects(transformedDoc, expectedDoc);
}

- (void)testAppliesServerAckedTransformsToDocuments {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value"}, @"baz" : @"baz-value" };
  FSTDocument *baseDoc = FSTTestDoc(@"collection/key", 0, docData, NO);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @[ @"foo.bar" ]);

  FSTMutationResult *mutationResult = [[FSTMutationResult alloc]
       initWithVersion:FSTTestVersion(1)
      transformResults:@[ [FSTTimestampValue timestampValue:_timestamp] ]];

  FSTMaybeDocument *transformedDoc = [transform applyTo:baseDoc
                                           baseDocument:baseDoc
                                         localWriteTime:_timestamp
                                         mutationResult:mutationResult];

  NSDictionary *expectedData =
      @{ @"foo" : @{@"bar" : _timestamp.approximateDateValue},
         @"baz" : @"baz-value" };
  XCTAssertEqualObjects(transformedDoc, FSTTestDoc(@"collection/key", 0, expectedData, NO));
}

- (void)testDeleteDeletes {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc(@"collection/key", 0, docData, NO);

  FSTMutation *mutation = FSTTestDeleteMutation(@"collection/key");
  FSTMaybeDocument *result =
      [mutation applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];
  XCTAssertEqualObjects(result, FSTTestDeletedDoc(@"collection/key", 0));
}

- (void)testSetWithMutationResult {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc(@"collection/key", 0, docData, NO);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"foo" : @"new-bar"});
  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:FSTTestVersion(4) transformResults:nil];
  FSTMaybeDocument *setDoc = [set applyTo:baseDoc
                             baseDocument:baseDoc
                           localWriteTime:_timestamp
                           mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"foo" : @"new-bar"};
  XCTAssertEqualObjects(setDoc, FSTTestDoc(@"collection/key", 0, expectedData, NO));
}

- (void)testPatchWithMutationResult {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc(@"collection/key", 0, docData, NO);

  FSTMutation *patch = FSTTestPatchMutation(@"collection/key", @{@"foo" : @"new-bar"}, nil);
  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:FSTTestVersion(4) transformResults:nil];
  FSTMaybeDocument *patchedDoc = [patch applyTo:baseDoc
                                   baseDocument:baseDoc
                                 localWriteTime:_timestamp
                                 mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"foo" : @"new-bar"};
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc(@"collection/key", 0, expectedData, NO));
}

#define ASSERT_VERSION_TRANSITION(mutation, base, expected)                                 \
  do {                                                                                      \
    FSTMutationResult *mutationResult =                                                     \
        [[FSTMutationResult alloc] initWithVersion:FSTTestVersion(0) transformResults:nil]; \
    FSTMaybeDocument *actual = [mutation applyTo:base                                       \
                                    baseDocument:base                                       \
                                  localWriteTime:_timestamp                                 \
                                  mutationResult:mutationResult];                           \
    XCTAssertEqualObjects(actual, expected);                                                \
  } while (0);

/**
 * Tests the transition table documented in FSTMutation.h.
 */
- (void)testTransitions {
  FSTDocument *docV0 = FSTTestDoc(@"collection/key", 0, @{}, NO);
  FSTDeletedDocument *deletedV0 = FSTTestDeletedDoc(@"collection/key", 0);

  FSTDocument *docV3 = FSTTestDoc(@"collection/key", 3, @{}, NO);
  FSTDeletedDocument *deletedV3 = FSTTestDeletedDoc(@"collection/key", 3);

  FSTMutation *setMutation = FSTTestSetMutation(@"collection/key", @{});
  FSTMutation *patchMutation = FSTTestPatchMutation(@"collection/key", @{}, nil);
  FSTMutation *deleteMutation = FSTTestDeleteMutation(@"collection/key");

  ASSERT_VERSION_TRANSITION(setMutation, docV3, docV3);
  ASSERT_VERSION_TRANSITION(setMutation, deletedV3, docV0);
  ASSERT_VERSION_TRANSITION(setMutation, nil, docV0);

  ASSERT_VERSION_TRANSITION(patchMutation, docV3, docV3);
  ASSERT_VERSION_TRANSITION(patchMutation, deletedV3, deletedV3);
  ASSERT_VERSION_TRANSITION(patchMutation, nil, nil);

  ASSERT_VERSION_TRANSITION(deleteMutation, docV3, deletedV0);
  ASSERT_VERSION_TRANSITION(deleteMutation, deletedV3, deletedV0);
  ASSERT_VERSION_TRANSITION(deleteMutation, nil, deletedV0);
}

#undef ASSERT_TRANSITION

@end
