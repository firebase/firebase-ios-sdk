/*
 * Copyright 2019 Google
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

#import "FIRInstallationsItem.h"

@implementation FIRInstallationsItem

- (instancetype)initWithAppID:(NSString *)appID firebaseAppName:(NSString *)firebaseAppName {
  self = [super init];
  if (self) {
    _appID = [appID copy];
    _firebaseAppName = [firebaseAppName copy];
  }
  return self;
}

- (void)updateWithStoredItem:(FIRInstallationsStoredItem *)item {
}

- (FIRInstallationsStoredItem *)storedItem {
  return nil;
}

// [NSString stringWithFormat:@"%@+%@", appID, firebaseAppName]
- (nonnull NSString *)identifier {
  return @"";
}

@end
