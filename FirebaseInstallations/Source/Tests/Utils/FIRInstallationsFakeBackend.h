/*
 * Copyright 2026 Google LLC
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

NS_ASSUME_NONNULL_BEGIN

/// A request received by `FIRInstallationsFakeBackend`.
@interface FIRInstallationsFakeBackendRequest : NSObject
@property(nonatomic, readonly) NSString *HTTPMethod;
@property(nonatomic, readonly) NSString *path;
@property(nonatomic, readonly) NSDictionary<NSString *, NSString *> *headers;
/// The JSON body, or `nil` if the request has no JSON object body.
@property(nonatomic, readonly, nullable) NSDictionary *JSONBody;
/// Returns the value of the header named `name`, compared case-insensitively.
- (nullable NSString *)valueForHeader:(NSString *)name;
@end

/// An in-memory fake of the Firebase Installations REST API.
///
/// It handles the requests sent through `URLSession` and keeps installations in memory like the
/// backend: registering an installation issues a refresh token and an auth token, generating an
/// auth token requires the installation's refresh token, and deleting an installation removes it.
@interface FIRInstallationsFakeBackend : NSObject

- (instancetype)init NS_UNAVAILABLE;

/// Creates a backend that expects requests for `projectID` with `APIKey`.
- (instancetype)initWithProjectID:(NSString *)projectID APIKey:(NSString *)APIKey;

/// A session whose data tasks are handled by this backend without using the network. It only
/// supports `dataTaskWithRequest:completionHandler:`, which is what `FIRInstallationsAPIService`
/// uses.
@property(nonatomic, readonly) NSURLSession *URLSession;

/// All requests received so far, in order.
@property(nonatomic, readonly) NSArray<FIRInstallationsFakeBackendRequest *> *requests;

/// Whether the backend has a registered installation with `FID`.
- (BOOL)hasInstallationWithFID:(NSString *)FID;

/// The refresh token issued for the installation with `FID`, or `nil`.
- (nullable NSString *)refreshTokenForFID:(NSString *)FID;

/// The last auth token issued for the installation with `FID`, or `nil`.
- (nullable NSString *)authTokenForFID:(NSString *)FID;

/// Forgets the installation with `FID`, as if the backend had deleted it.
- (void)forgetInstallationWithFID:(NSString *)FID;

/// If set, the next registration response assigns this FID instead of the requested one.
@property(atomic, copy, nullable) NSString *FIDForNextRegistration;

@end

NS_ASSUME_NONNULL_END
