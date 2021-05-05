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

#import "FirebaseAppCheck/Tests/Unit/Utils/FIRFixtureLoader.h"

@implementation FIRFixtureLoader

+ (NSData *)loadFixtureNamed:(NSString *)fileName {
  NSURL *fileURL;
  __auto_type possibleResourceBundles = [self possibleResourceBundles];
  for (NSBundle *bundle in possibleResourceBundles) {
    fileURL = [bundle URLForResource:fileName withExtension:nil];
    if (fileURL != nil) {
      NSLog(@"Fixture named: %@ was found at bundle %@", fileName, [bundle bundleIdentifier]);
      break;
    }
  }

  NSError *error;
  NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&error];

  return data;
}

+ (NSArray<NSBundle *> *)possibleResourceBundles {
  NSBundle *bundleForClass = [NSBundle bundleForClass:[self class]];

  // Swift Package Manager packages resources into separate bundles inside the test bundle.
  NSArray<NSURL *> *enclosedBundleURLs = [bundleForClass URLsForResourcesWithExtension:@"bundle"
                                                                          subdirectory:nil];

  NSMutableArray<NSBundle *> *bundlesForResources = [@[ bundleForClass ] mutableCopy];
  for (NSURL *bundleURL in enclosedBundleURLs) {
    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    if (bundle) {
      [bundlesForResources addObject:bundle];
    }
  }

  return [bundlesForResources copy];
}

@end
