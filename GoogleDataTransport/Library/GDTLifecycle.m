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

#import "Library/Public/GDTLifecycle.h"

#import <GoogleDataTransport/GDTEvent.h>

#import "Library/Private/GDTRegistrar_Private.h"
#import "Library/Private/GDTStorage_Private.h"
#import "Library/Private/GDTTransformer_Private.h"
#import "Library/Private/GDTUploadCoordinator_Private.h"

@implementation GDTLifecycle

+ (void)load {
  [self sharedInstance];
}

/** Creates/returns the singleton instance of this class.
 *
 * @return The singleton instance of this class.
 */
+ (instancetype)sharedInstance {
  static GDTLifecycle *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[GDTLifecycle alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];

    NSString *name = UIApplicationWillTerminateNotification;
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminate:)
                               name:name
                             object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
  UIApplication *application = [UIApplication sharedApplication];
  [[GDTTransformer sharedInstance] appWillBackground:application];
  [[GDTStorage sharedInstance] appWillBackground:application];
  [[GDTUploadCoordinator sharedInstance] appWillBackground:application];
  [[GDTRegistrar sharedInstance] appWillBackground:application];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
  UIApplication *application = [UIApplication sharedApplication];
  [[GDTTransformer sharedInstance] appWillForeground:application];
  [[GDTStorage sharedInstance] appWillForeground:application];
  [[GDTUploadCoordinator sharedInstance] appWillForeground:application];
  [[GDTRegistrar sharedInstance] appWillForeground:application];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  UIApplication *application = [UIApplication sharedApplication];
  [[GDTTransformer sharedInstance] appWillTerminate:application];
  [[GDTStorage sharedInstance] appWillTerminate:application];
  [[GDTUploadCoordinator sharedInstance] appWillTerminate:application];
  [[GDTRegistrar sharedInstance] appWillTerminate:application];
}

@end
