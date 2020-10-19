/*
 * Copyright 2018 Google
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

#import "FirebaseDynamicLinks/Sources/Public/FirebaseDynamicLinks/FIRDynamicLink.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRDynamicLink ()

typedef NS_ENUM(NSUInteger, FIRDynamicLinkMatchConfidence) {
  FIRDynamicLinkMatchConfidenceWeak,
  FIRDynamicLinkMatchConfidenceStrong
} NS_SWIFT_NAME(DynamicLinkMatchConfidence) DEPRECATED_MSG_ATTRIBUTE("Use FIRDLMatchType instead.");

@property(nonatomic, assign, readonly)
    FIRDynamicLinkMatchConfidence matchConfidence DEPRECATED_MSG_ATTRIBUTE(
        "Use FIRDynamicLink.matchType (DynamicLink.DLMatchType) instead.");

@property(nonatomic, copy, nullable) NSURL *url;

@property(nonatomic, copy, readwrite, nullable) NSString *minimumAppVersion;

// The invite ID retrieved from the dynamic link.
@property(nonatomic, copy, nullable) NSString *inviteId;

// Whether the received invite is matched via ipv4 or ipv6 endpoint.
@property(nonatomic, copy, nullable) NSString *weakMatchEndpoint;

@property(nonatomic, copy, nullable) NSString *matchMessage;

@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *parametersDictionary;

@property(nonatomic, assign, readwrite) FIRDLMatchType matchType;

- (instancetype)initWithParametersDictionary:(NSDictionary<NSString *, id> *)parametersDictionary;

@end

NS_ASSUME_NONNULL_END
