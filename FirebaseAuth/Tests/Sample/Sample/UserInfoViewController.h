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

@class FIRUser;
@class StaticContentTableViewManager;

/** @class UserInfoViewController
    @brief A view controller for displaying @c FIRUser data.
 */
@interface UserInfoViewController : UIViewController

/** @property tableViewManager
    @brief A @c StaticContentTableViewManager which is used to manage the contents of the table
        view.
 */
@property(nonatomic, strong) IBOutlet StaticContentTableViewManager *tableViewManager;

/** @fn initWithUser:
    @biref Initializes with a @c FIRUser instance.
    @param user The user to be displayed in the view.
 */
- (instancetype)initWithUser:(FIRUser *)user NS_DESIGNATED_INITIALIZER;

/** @fn initWithNibName:bundle:
    @brief Not available. Call initWithUser: instead.
 */
- (instancetype)initWithNibName:(NSString *)nibNameOrNil
                         bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

/** @fn initWithCoder:
    @brief Not available. Call initWithUser: instead.
 */
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

/** @fn done
    @brief Called when user taps the "Done" button.
 */
- (IBAction)done:(id)sender;

@end
