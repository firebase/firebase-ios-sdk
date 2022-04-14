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
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageConstants.h"
#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageMetadata.h"
#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageReference.h"
#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageTask.h"

#import "FirebaseStorageInternal/Sources/FIRStorageConstants_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageErrors.h"
#import "FirebaseStorageInternal/Sources/FIRStorageReference_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageTask_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageTokenAuthorizer.h"
#import "FirebaseStorageInternal/Sources/FIRStorageUtils.h"

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcher.h>
#endif

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kGoogleHTTPErrorDomain;
FOUNDATION_EXPORT NSString *const kHTTPVersion;
FOUNDATION_EXPORT NSString *const kUnauthenticatedResponseString;
FOUNDATION_EXPORT NSString *const kUnauthorizedResponseString;
FOUNDATION_EXPORT NSString *const kNotFoundResponseString;
FOUNDATION_EXPORT NSString *const kInvalidJSONResponseString;
FOUNDATION_EXPORT NSString *const kFIRStorageValidURL;
FOUNDATION_EXPORT NSString *const kFIRStorageNotFoundURL;
FOUNDATION_EXPORT NSString *const kFIRStorageTestAuthToken;
FOUNDATION_EXPORT NSString *const kFIRStorageAppName;

/**
 * Standard timeout for all async tests.
 */
static NSTimeInterval kExpectationTimeoutSeconds = 10;

@interface FIRStorageTestHelpers : NSObject

/**
 * Returns a mocked FIRApp with an injected container for interop and instance creation. No other
 * properties are set.
 */
+ (FIRApp *)mockedApp;

/**
 * Returns a FIRIMPLStorage inialized with a mockedApp.
 */
+ (FIRIMPLStorage *)storageWithMockedApp;

/**
 * Returns a valid URL for an object stored.
 */
+ (NSURL *)objectURL;

/**
 * Returns a valid URL for a bucket.
 */
+ (NSURL *)bucketURL;

/**
 * Returns a valid URL for an object not found in the current storage bucket.
 */
+ (NSURL *)notFoundURL;

/**
 * Returns a valid FIRStoragePath for an object stored.
 */
+ (FIRStoragePath *)objectPath;

/**
 * Returns a valid FIRStoragePath for a bucket (no object).
 */
+ (FIRStoragePath *)bucketPath;

/**
 * Returns a valid FIRStoragePath for an object not found in the current storage bucket.
 */
+ (FIRStoragePath *)notFoundPath;

/**
 * Returns a FIRIMPLStorageReference that is backed by a mocked FIRApp.
 */
+ (FIRIMPLStorageReference *)rootReference;

/**
 * Returns a successful response block.
 */
+ (GTMSessionFetcherTestBlock)successBlock;

/**
 * Returns a successful response block that validates the provided URL.
 */
+ (GTMSessionFetcherTestBlock)successBlockWithURL:(NSString *)url;

/**
 * Returns a successful response block containing object metadata.
 * @param metadata Metadata returned in the request.
 */
+ (GTMSessionFetcherTestBlock)successBlockWithMetadata:(nullable FIRIMPLStorageMetadata *)metadata;

/**
 * Returns a unsuccessful response block due to improper authentication.
 */
+ (GTMSessionFetcherTestBlock)unauthenticatedBlock;

/**
 * Returns a unsuccessful response block due to improper authorization.
 */
+ (GTMSessionFetcherTestBlock)unauthorizedBlock;

/**
 * Returns a unsuccessful response block due the object not being found.
 */
+ (GTMSessionFetcherTestBlock)notFoundBlock;

/**
 * Returns a unsuccessful response block due invalid JSON returned by the server.
 */
+ (GTMSessionFetcherTestBlock)invalidJSONBlock;

/**
 * Waits for the given test case to time out by wrapping -waitForExpectation.
 */
+ (void)waitForExpectation:(id)test;

@end

NS_ASSUME_NONNULL_END
