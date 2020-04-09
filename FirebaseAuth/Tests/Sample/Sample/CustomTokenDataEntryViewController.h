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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** @typedef CustomTokenDataEntryViewControllerCompletion
    @brief The type of callback block invoked when a @c CustomTokenDataEntryViewController is
        dismissed (by either being cancelled or completed by the user.)
    @param cancelled Indicates the user cancelled the flow and didn't want to enter a token.
    @param userEnteredTokenText The token text the user entered.
 */
typedef void (^CustomTokenDataEntryViewControllerCompletion)
    (BOOL cancelled, NSString *_Nullable userEnteredTokenText);

/** @class CustomTokenDataEntryViewController
    @brief Simple view controller to allow data entry of custom BYOAuth tokens.
 */
@interface CustomTokenDataEntryViewController : UIViewController

/** @fn initWithNibName:bundle:
    @brief Please use initWithCompletion:
 */
- (instancetype)initWithNibName:(NSString *_Nullable)nibNameOrNil
                         bundle:(NSBundle *_Nullable)nibBundleOrNil NS_UNAVAILABLE;

/** @fn initWithCoder:
    @brief Please use initWithCompletion:
 */
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

/** @fn initWithCompletion:
    @brief Designated initializer.
    @param completion A block which will be invoked when the user either chooses "cancel" or "done".
 */
- (nullable instancetype)initWithCompletion:
    (CustomTokenDataEntryViewControllerCompletion)completion NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
