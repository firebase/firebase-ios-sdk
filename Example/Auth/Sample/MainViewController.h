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

@class StaticContentTableViewManager;
@class UserTableViewCell;

/** @class MainViewController
    @brief The first view controller presented when the application is started.
 */
@interface MainViewController : UIViewController

/** @property tableViewManager
    @brief A @c StaticContentTableViewManager which is used to manage the contents of the table
        view.
 */
@property(nonatomic, strong) IBOutlet StaticContentTableViewManager *tableViewManager;

/** @property tableView
    @brief A UITableView which is used to display user info and a list of actions.
 */
@property(nonatomic, weak) IBOutlet UITableView *tableView;

/** @property userInfoTableViewCell
    @brief A custom UITableViewCell for displaying the user info.
 */
@property(nonatomic, strong) IBOutlet UserTableViewCell *userInfoTableViewCell;

/** @property userInMemoryInfoTableViewCell
    @brief A custom UITableViewCell for displaying the user info.
 */
@property(nonatomic, strong) IBOutlet UserTableViewCell *userInMemoryInfoTableViewCell;

/** @property userToUseCell
    @brief A custom UITableViewCell for choosing which user to use for user operations (either the
        currently signed-in user, or the user in "memory".
 */
@property(nonatomic, strong) IBOutlet UITableViewCell *userToUseCell;

/** @property consoleTextView
    @brief A UITextView with a log of the actions performed in the sample app.
 */
@property(nonatomic, weak) IBOutlet UITextView *consoleTextView;

/** @fn handleIncomingLinkWithURL:
    @brief Handles an incoming link to trigger the appropriate OOBCode if possible.
    @param URL The webURL of the incoming universal link.
    @return Boolean value indicating whether the incoming link could be handled or not.
 */
- (BOOL)handleIncomingLinkWithURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
