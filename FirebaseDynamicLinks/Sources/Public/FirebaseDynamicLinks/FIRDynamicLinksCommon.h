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

#import <Foundation/Foundation.h>

@class FIRDynamicLink;

NS_ASSUME_NONNULL_BEGIN

/**
 * @file FIRDynamicLinksCommon.h
 * @abstract Commonly shared definitions within Firebase Dynamic Links.
 */

/**
 * @abstract The definition of the block used by |resolveShortLink:completion:|
 */
typedef void (^FIRDynamicLinkResolverHandler)(NSURL* _Nullable url, NSError* _Nullable error)
    NS_SWIFT_NAME(DynamicLinkResolverHandler);

/**
 * @abstract The definition of the block used by |handleUniversalLink:completion:|
 */
typedef void (^FIRDynamicLinkUniversalLinkHandler)(FIRDynamicLink* _Nullable dynamicLink,
                                                   NSError* _Nullable error)
    NS_SWIFT_NAME(DynamicLinkUniversalLinkHandler);

NS_ASSUME_NONNULL_END
