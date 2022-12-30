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

#import "AppManager.h"

#import <FirebaseCore/FIRApp.h>
@import FirebaseAuth;

NS_ASSUME_NONNULL_BEGIN

@implementation AppManager {
  /** @var _createdAppNames
      @brief The set of names of live (created but not deleted) app, to avoid iCore warnings.
   */
  NSMutableSet<NSString *> *_liveAppNames;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _count = 2;
    _liveAppNames = [[NSMutableSet<NSString *> alloc] initWithCapacity:_count - 1];
  }
  return self;
}

- (nullable FIRApp *)appAtIndex:(int)index {
  if (index == 0) {
    return [FIRApp defaultApp];
  }
  NSString *name = [self appNameWithIndex:index];
  if ([_liveAppNames containsObject:name]) {
    return [FIRApp appNamed:[self appNameWithIndex:index]];
  }
  return nil;
}

- (void)recreateAppAtIndex:(int)index
               withOptions:(nullable FIROptions *)options
                completion:(void (^)(void))completion {
  [self deleteAppAtIndex:index completion:^() {
    if (index == 0) {
      if (options) {
        [FIRApp configureWithOptions:options];
      }
    } else {
      NSString *name = [self appNameWithIndex:index];
      if (options) {
        [FIRApp configureWithName:name options:options];
        [self->_liveAppNames addObject:name];
      } else {
        [self->_liveAppNames removeObject:name];
      }
    }
    completion();
  }];
}

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  static AppManager *sharedInstance;
   dispatch_once(&onceToken, ^{
     sharedInstance = [[self alloc] init];
   });
  return sharedInstance;
}

+ (FIRApp *)app {
  AppManager *manager = [self sharedInstance];
  return [manager appAtIndex:manager.active];
}

+ (FIRAuth *)auth {
  return [FIRAuth authWithApp:[self app]];
}

+ (FIRPhoneAuthProvider *)phoneAuthProvider {
  return [FIRPhoneAuthProvider providerWithAuth:[self auth]];
}

#pragma mark - Helpers

/** @fn appNameWithIndex:
    @brief Gets the app name for the given index.
    @param index The index of the app managed by this instance.
    @return The app name for the FIRApp instance.
 */
- (NSString *)appNameWithIndex:(int)index {
  return [NSString stringWithFormat:@"APP_%02d", index];
}

/** @fn deleteAppAtIndex:withOptions:completion:
    @brief Deletes the app at the given index.
    @param index The index of the app to be deleted, 0 being the default app.
    @param completion The block to call when completes.
 */
- (void)deleteAppAtIndex:(int)index
              completion:(void (^)(void))completion {
  FIRApp *app = [self appAtIndex:index];
  if (app) {
    [app deleteApp:^(BOOL success) {
      if (success) {
        completion();
      } else {
        NSLog(@"Failed to delete app '%@'.", app.name);
      }
    }];
  } else {
    completion();
  }
}

@end

NS_ASSUME_NONNULL_END
