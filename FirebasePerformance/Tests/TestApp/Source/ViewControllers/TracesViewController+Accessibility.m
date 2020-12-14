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

// Non-google3 relative import to support building with Xcode.
#import "TracesViewController+Accessibility.h"

@implementation TracesViewController (Accessibility)

+ (nonnull AccessibilityItem *)addTraceAccessibilityItem {
  NSDictionary *accessibilityDictionary =
      @{kAccessibilityIdentifierKey : @"addTrace", kAccessibilityLabelKey : @"Add Trace"};

  return [[AccessibilityItem alloc] initWithDictionary:accessibilityDictionary];
}

+ (nonnull AccessibilityItem *)networkRequestAccessibilityItem {
  NSDictionary *accessibilityDictionary = @{
    kAccessibilityIdentifierKey : @"networkRequest",
    kAccessibilityLabelKey : @"Make a network request"
  };

  return [[AccessibilityItem alloc] initWithDictionary:accessibilityDictionary];
}

@end
