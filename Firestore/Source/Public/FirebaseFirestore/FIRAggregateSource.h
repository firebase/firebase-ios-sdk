/*
 * Copyright 2022 Google LLC
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

/**
 * The sources from which an `AggregateQuery` can retrieve its results.
 *
 * See `AggregateQuery.getAggregation(source:completion:)`.
 */
typedef NS_ENUM(NSUInteger, FIRAggregateSource) {
  /**
   * Perform the aggregation on the server and download the result.
   *
   * The result received from the server is presented, unaltered, without considering any local
   * state. That is, documents in the local cache are not taken into consideration, neither are
   * local modifications not yet synchronized with the server. Previously-downloaded results, if
   * any, are not used. Every request using this source necessarily involves a round trip to the
   * server.
   *
   * The `AggregateQuery` will fail if the server cannot be reached, such as if the client is
   * offline.
   */
  FIRAggregateSourceServer,
} NS_SWIFT_NAME(AggregateSource);

NS_ASSUME_NONNULL_END
