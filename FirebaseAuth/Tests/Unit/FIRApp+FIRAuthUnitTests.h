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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

/** @category FIRApp (FIRAuthUnitTests)
    @brief Tests for @c FIRAuth.
 */
@interface FIRApp (FIRAuthUnitTests)

/** @fn resetAppForAuthUnitTests
    @brief Resets the Firebase app for unit tests.
 */
+ (void)resetAppForAuthUnitTests;

/** @fn appForAuthUnitTestsWithName:
    @brief Creates a Firebase app with given name.
    @param name The name for the app.
    @return A @c FIRApp with the specified name.
 */
+ (FIRApp *)appForAuthUnitTestsWithName:(NSString *)name;

@end
