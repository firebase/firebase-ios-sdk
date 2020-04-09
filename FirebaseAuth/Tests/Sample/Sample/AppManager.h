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

#import <Foundation/Foundation.h>

@class FIRApp;
@class FIRAuth;
@class FIROptions;
@class FIRPhoneAuthProvider;

NS_ASSUME_NONNULL_BEGIN

/** @class AppManager
    @brief A manager of global FIRApp instances.
 */
@interface AppManager : NSObject

/** @property count
    @brief The total count of apps under management, including the default app.
 */
@property(nonatomic, assign, readonly) int count;

/** @property active
    @brief The index of the currently active app, 0 being the default app.
 */
@property(nonatomic, assign) int active;

/** @fn appAtIndex:
    @brief Retrieves the app at the given index.
    @param index The index of the app to be retrieved, 0 being the default app.
    @return The app at the given index.
 */
- (nullable FIRApp *)appAtIndex:(int)index;

/** @fn recreateAppAtIndex:withOptions:completion:
    @brief Deletes the app at the given index, and optionally creates it again with given options.
    @param index The index of the app to be recreated, 0 being the default app.
    @param options Optionally, the new options with which app should be created.
    @param completion The block to call when completes.
 */
- (void)recreateAppAtIndex:(int)index
               withOptions:(nullable FIROptions *)options
                completion:(void (^)(void))completion;

/** @fn sharedInstance
    @brief Gets a shared instance of the class.
 */
+ (instancetype)sharedInstance;

/** @fn app
    @brief A shortcut to get the currently active app.
 */
+ (FIRApp *)app;

/** @fn auth
    @brief A shortcut to get the auth instance for the currently active app.
 */
+ (FIRAuth *)auth;

/** @fn phoneAuthProvider
    @brief A shortcut to get the phone auth provider for the currently active app.
 */
+ (FIRPhoneAuthProvider *)phoneAuthProvider;

@end

NS_ASSUME_NONNULL_END
