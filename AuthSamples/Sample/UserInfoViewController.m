/** @file SettingsViewController.m
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2016 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import "googlemac/iPhone/Identity/Firebear/Sample/UserInfoViewController.h"

#import "googlemac/iPhone/Identity/Firebear/Auth/Source/FIRUser.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/FIRUserInfo.h"
#import "googlemac/iPhone/Identity/Firebear/Sample/StaticContentTableViewManager.h"

/** @fn stringWithBool
    @brief Converts a boolean value to a string for display.
    @param boolValue the boolean value.
    @return The string form of the boolean value.
 */
static NSString *stringWithBool(BOOL boolValue) {
  return boolValue ? @"YES" : @"NO";
}

@implementation UserInfoViewController {
  FIRUser *_user;
}

- (instancetype)initWithUser:(FIRUser *)user {
  self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil];
  if (self) {
    _user = user;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self loadTableView];
}

- (void)loadTableView {
  NSMutableArray<StaticContentTableViewSection *> *sections = [@[
    [StaticContentTableViewSection sectionWithTitle:@"User" cells:@[
      [StaticContentTableViewCell cellWithTitle:@"anonymous" value:stringWithBool(_user.anonymous)],
      [StaticContentTableViewCell cellWithTitle:@"emailVerified"
                                          value:stringWithBool(_user.emailVerified)],
      [StaticContentTableViewCell cellWithTitle:@"refreshToken" value:_user.refreshToken],
    ]]
  ] mutableCopy];
  [sections addObject:[self sectionWithUserInfo:_user]];
  for (id<FIRUserInfo> userInfo in _user.providerData) {
    [sections addObject:[self sectionWithUserInfo:userInfo]];
  }
  _tableViewManager.contents = [StaticContentTableViewContent contentWithSections:sections];
}

- (StaticContentTableViewSection *)sectionWithUserInfo:(id<FIRUserInfo>)userInfo {
  return [StaticContentTableViewSection sectionWithTitle:userInfo.providerID cells:@[
    [StaticContentTableViewCell cellWithTitle:@"uid" value:userInfo.uid],
    [StaticContentTableViewCell cellWithTitle:@"displayName" value:userInfo.displayName],
    [StaticContentTableViewCell cellWithTitle:@"photoURL" value:[userInfo.photoURL absoluteString]],
    [StaticContentTableViewCell cellWithTitle:@"email" value:userInfo.email],
    [StaticContentTableViewCell cellWithTitle:@"phoneNumber" value:userInfo.phoneNumber]
  ]];
}

- (IBAction)done:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

@end
