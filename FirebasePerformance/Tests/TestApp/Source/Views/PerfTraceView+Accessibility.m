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

#import "PerfTraceView+Accessibility.h"

@implementation PerfTraceView (Accessibility)

+ (AccessibilityItem *)stageAccessibilityItemWithTraceName:(NSString *)traceName {
  NSString *accessibilityIdentifier = [NSString stringWithFormat:@"%@Stage", traceName];

  NSDictionary *accessibilityDictionary = @{
    kAccessibilityIdentifierKey : accessibilityIdentifier,
    kAccessibilityLabelKey : @"Add Stage",
  };

  return [[AccessibilityItem alloc] initWithDictionary:accessibilityDictionary];
}

+ (AccessibilityItem *)stopAccessibilityItemWithTraceName:(NSString *)traceName {
  NSString *accessibilityIdentifier = [NSString stringWithFormat:@"%@Stop", traceName];

  NSDictionary *accessibilityDictionary = @{
    kAccessibilityIdentifierKey : accessibilityIdentifier,
    kAccessibilityLabelKey : @"Stop Trace",
  };

  return [[AccessibilityItem alloc] initWithDictionary:accessibilityDictionary];
}

+ (AccessibilityItem *)metricOneAccessibilityItemWithTraceName:(NSString *)traceName {
  NSString *accessibilityIdentifier = [NSString stringWithFormat:@"%@Metric1", traceName];

  NSDictionary *accessibilityDictionary = @{
    kAccessibilityIdentifierKey : accessibilityIdentifier,
    kAccessibilityLabelKey : @"Increment Metric 1",
  };

  return [[AccessibilityItem alloc] initWithDictionary:accessibilityDictionary];
}

+ (AccessibilityItem *)metricTwoAccessibilityItemWithTraceName:(NSString *)traceName {
  NSString *accessibilityIdentifier = [NSString stringWithFormat:@"%@Metric2", traceName];

  NSDictionary *accessibilityDictionary = @{
    kAccessibilityIdentifierKey : accessibilityIdentifier,
    kAccessibilityLabelKey : @"Increment Metric 2",
  };

  return [[AccessibilityItem alloc] initWithDictionary:accessibilityDictionary];
}

+ (AccessibilityItem *)customAttributeAccessibilityItemWithTraceName:(NSString *)traceName {
  NSString *accessibilityIdentifier = [NSString stringWithFormat:@"%@CustomAttr", traceName];

  NSDictionary *accessibilityDictionary = @{
    kAccessibilityIdentifierKey : accessibilityIdentifier,
    kAccessibilityLabelKey : @"Add Custom Attribute",
  };

  return [[AccessibilityItem alloc] initWithDictionary:accessibilityDictionary];
}

@end
