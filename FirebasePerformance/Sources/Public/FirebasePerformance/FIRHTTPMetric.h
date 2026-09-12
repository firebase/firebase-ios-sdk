// Copyright 2020 Google LLC
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

#import "FIRPerformanceAttributable.h"

// clang-format off
// clang-format12 does a weird cascading indent of this enum.
/* Different HTTP methods. */
typedef NS_ENUM(NSInteger, FIRHTTPMethod) {
  /** HTTP Method GET */
  FIRHTTPMethodGET NS_SWIFT_NAME(get),
  /** HTTP Method PUT */
  FIRHTTPMethodPUT NS_SWIFT_NAME(put),
  /** HTTP Method POST */
  FIRHTTPMethodPOST NS_SWIFT_NAME(post),
  /** HTTP Method DELETE */
  FIRHTTPMethodDELETE NS_SWIFT_NAME(delete),
  /** HTTP Method HEAD */
  FIRHTTPMethodHEAD NS_SWIFT_NAME(head),
  /** HTTP Method PATCH */
  FIRHTTPMethodPATCH NS_SWIFT_NAME(patch),
  /** HTTP Method OPTIONS */
  FIRHTTPMethodOPTIONS NS_SWIFT_NAME(options),
  /** HTTP Method TRACE */
  FIRHTTPMethodTRACE NS_SWIFT_NAME(trace),
  /** HTTP Method CONNECT */
  FIRHTTPMethodCONNECT NS_SWIFT_NAME(connect)
} NS_SWIFT_NAME(HTTPMethod);
// clang-format on

/**
 * Instances of `HTTPMetric` can be used to record HTTP network request information.
 */
NS_SWIFT_NAME(HTTPMetric)
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
@interface FIRHTTPMetric : NSObject <FIRPerformanceAttributable>

/**
 * Creates HTTPMetric object for a network request.
 * @param URL The URL for which the metrics are recorded.
 * @param httpMethod HTTP method used by the request.
 */
- (nullable instancetype)initWithURL:(nonnull NSURL *)URL
                          HTTPMethod:(FIRHTTPMethod)httpMethod NS_SWIFT_NAME(init(url:httpMethod:));

/**
 * Use `init(url:httpMethod:)` for Swift and `initWithURL:HTTPMethod:` for Objective-C.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
 * @brief HTTP Response code. Values are greater than 0.
 */
@property(nonatomic, assign) NSInteger responseCode;

/**
 * @brief Size of the request payload.
 */
@property(nonatomic, assign) long requestPayloadSize;

/**
 * @brief Size of the response payload.
 */
@property(nonatomic, assign) long responsePayloadSize;

/**
 * @brief HTTP Response content type.
 */
@property(nonatomic, nullable, copy) NSString *responseContentType;

/**
 * Marks the start time of the request.
 */
- (void)start;

/**
 * Marks the end time of the response and queues the network request metric on the device for
 * transmission. Check the logs if the metric is valid.
 */
- (void)stop;

@end
