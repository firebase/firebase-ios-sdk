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

#import "../Models/AccessibilityItem.h"
#import "PerfTraceView.h"

NS_ASSUME_NONNULL_BEGIN

@interface PerfTraceView (Accessibility)

/**
 * @param traceName Name of the current trace.
 * @return An AccessibilityItem for a stage UI element reflecting the current trace name.
 */
+ (AccessibilityItem *)stageAccessibilityItemWithTraceName:(NSString *)traceName;

/**
 * @param traceName Name of the current trace.
 * @return An AccessibilityItem for a stop UI element reflecting the current trace name.
 */
+ (AccessibilityItem *)stopAccessibilityItemWithTraceName:(NSString *)traceName;

/**
 * @param traceName Name of the current trace.
 * @return An AccessibilityItem for a counter UI element reflecting the current trace name.
 */
+ (AccessibilityItem *)metricOneAccessibilityItemWithTraceName:(NSString *)traceName;

/**
 * @param traceName Name of the current trace.
 * @return An AccessibilityItem for a second counter UI element reflecting the current trace name.
 */
+ (AccessibilityItem *)metricTwoAccessibilityItemWithTraceName:(NSString *)traceName;

/**
 * @param traceName Name of the current trace.
 * @return An AccessibilityItem for a custom attribute UI element reflecting the current trace name.
 */
+ (AccessibilityItem *)customAttributeAccessibilityItemWithTraceName:(NSString *)traceName;
@end

NS_ASSUME_NONNULL_END
