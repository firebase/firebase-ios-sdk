/*
 * Copyright 2017 Google
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMSDKSettings.h"

@implementation FIRIAMSDKSettings

- (NSString *)description {
  return
      [NSString stringWithFormat:@"APIServer:%@;ProjectNumber:%@; API_Key:%@;Clearcut Server:%@; "
                                  "Fetch Minimal Interval:%lu seconds; Activity Logger Max:%lu; "
                                  "Foreground Display Trigger Minimal Interval:%lu seconds;\n"
                                  "Clearcut strategy:%@;Global Firebase auto data collection %@\n",
                                 self.apiServerHost, self.firebaseProjectNumber, self.apiKey,
                                 self.clearcutServerHost,
                                 (unsigned long)(self.fetchMinIntervalInMinutes * 60),
                                 (unsigned long)self.loggerMaxCountBeforeReduce,
                                 (unsigned long)(self.appFGRenderMinIntervalInMinutes * 60),
                                 self.clearcutStrategy,
                                 self.firebaseAutoDataCollectionEnabled ? @"enabled" : @"disabled"];
}
@end

#endif  // TARGET_OS_IOS
