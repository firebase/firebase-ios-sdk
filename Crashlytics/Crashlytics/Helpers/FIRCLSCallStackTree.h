// Copyright 2021 Google LLC
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
#if defined(__IPHONE_15_0)
#define CLS_METRICKIT_SUPPORTED (__has_include(<MetricKit/MetricKit.h>) && TARGET_OS_IOS)
#else
#define CLS_METRICKIT_SUPPORTED 0
#endif

#if CLS_METRICKIT_SUPPORTED
#import <MetricKit/MetricKit.h>

/*
 * Helper class for parsing the `MXCallStackTree` that we receive from MetricKit. Flattens the
 * nested structure into a structure similar to what is used in Crashlytics.
 */
@interface FIRCLSCallStackTree : NSObject

- (instancetype)initWithMXCallStackTree:(MXCallStackTree *)callStackTree API_AVAILABLE(ios(14.0));
- (NSArray *)getArrayRepresentation;
- (NSArray *)getFramesOfBlamedThread;
- (instancetype)init NS_UNAVAILABLE;

@end
#endif
