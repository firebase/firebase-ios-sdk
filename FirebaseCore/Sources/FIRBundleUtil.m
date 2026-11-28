// Copyright 2017 Google
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

#import "FirebaseCore/Sources/FIRBundleUtil.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>

@implementation FIRBundleUtil

/// Bundles that replace `relevantBundles` in tests. Set only by tests, through
/// `+setRelevantBundlesForTesting:`.
static NSArray<NSBundle *> *sRelevantBundlesForTesting;

/// Overrides `isAppExtension` in tests. Set only by tests, through `+setIsAppExtensionForTesting:`.
static NSNumber *sIsAppExtensionForTesting;

+ (NSArray *)relevantBundles {
  @synchronized(self) {
    if (sRelevantBundlesForTesting) {
      return sRelevantBundlesForTesting;
    }
  }
  return @[ [NSBundle mainBundle], [NSBundle bundleForClass:[self class]] ];
}

+ (void)setRelevantBundlesForTesting:(nullable NSArray<NSBundle *> *)bundles {
  @synchronized(self) {
    sRelevantBundlesForTesting = [bundles copy];
  }
}

+ (BOOL)isAppExtension {
  NSNumber *isAppExtension;
  @synchronized(self) {
    isAppExtension = sIsAppExtensionForTesting;
  }
  return isAppExtension != nil ? isAppExtension.boolValue : [GULAppEnvironmentUtil isAppExtension];
}

+ (void)setIsAppExtensionForTesting:(nullable NSNumber *)isAppExtension {
  @synchronized(self) {
    sIsAppExtensionForTesting = [isAppExtension copy];
  }
}

+ (NSString *)optionsDictionaryPathWithResourceName:(NSString *)resourceName
                                        andFileType:(NSString *)fileType
                                          inBundles:(NSArray *)bundles {
  // Loop through all bundles to find the config dict.
  for (NSBundle *bundle in bundles) {
    NSString *path = [bundle pathForResource:resourceName ofType:fileType];
    // Use the first one we find.
    if (path) {
      return path;
    }
  }
  return nil;
}

+ (NSArray *)relevantURLSchemes {
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (NSBundle *bundle in [[self class] relevantBundles]) {
    NSArray *urlTypes = [bundle objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    for (NSDictionary *urlType in urlTypes) {
      [result addObjectsFromArray:urlType[@"CFBundleURLSchemes"]];
    }
  }
  return result;
}

+ (BOOL)hasBundleIdentifierPrefix:(NSString *)bundleIdentifier inBundles:(NSArray *)bundles {
  for (NSBundle *bundle in bundles) {
    if ([bundle.bundleIdentifier isEqualToString:bundleIdentifier]) {
      return YES;
    }

    if ([self isAppExtension]) {
      // A developer could be using the same `FIROptions` for both their app and extension. Since
      // extensions have a suffix added to the bundleID, we consider a matching prefix as valid.
      NSString *appBundleIDFromExtension =
          [self bundleIdentifierByRemovingLastPartFrom:bundle.bundleIdentifier];
      if ([appBundleIDFromExtension isEqualToString:bundleIdentifier]) {
        return YES;
      }
    }
  }
  return NO;
}

+ (NSString *)bundleIdentifierByRemovingLastPartFrom:(NSString *)bundleIdentifier {
  NSString *bundleIDComponentsSeparator = @".";

  NSMutableArray<NSString *> *bundleIDComponents =
      [[bundleIdentifier componentsSeparatedByString:bundleIDComponentsSeparator] mutableCopy];
  [bundleIDComponents removeLastObject];

  return [bundleIDComponents componentsJoinedByString:bundleIDComponentsSeparator];
}

@end
