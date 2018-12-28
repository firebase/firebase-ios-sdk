/*
 * Copyright 2018 Google
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

#import "ViewController.h"

#import <FirebaseDynamicLinks/FDLURLComponents.h>
#import <FirebaseDynamicLinks/FIRDynamicLinks.h>

#import "LinkTableViewCell.h"
#import "ParamTableViewCell.h"

static NSArray *kParamsConfiguration;

@interface ViewController () <ParamTableViewCellDelegate>
@end

@implementation ViewController {
  NSArray *_paramsConfiguration;
  NSMutableDictionary *_paramValues;

  NSURL *_longLink;
  NSURL *_shortLink;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = [UIColor whiteColor];
  self.title = @"FDL Builder";

  self.tableView.rowHeight = 60;

  [self _initDefaultValues];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 0 && indexPath.row == (kParamsConfiguration.count + 0)) {
    [self _buildFDLLink];
  }
  if (indexPath.section == 0 && indexPath.row == (kParamsConfiguration.count + 1)) {
    // copy long link
    if (_longLink) {
      [UIPasteboard generalPasteboard].string = _longLink.absoluteString;
      [self _presentMessage:@"Long Link copied to Clipboard" description:nil];
    } else {
      [self _presentMessage:@"Long Link is empty" description:nil];
    }
  }
  if (indexPath.section == 0 && indexPath.row == (kParamsConfiguration.count + 2)) {
    // copy short link
    if (_shortLink) {
      [UIPasteboard generalPasteboard].string = _shortLink.absoluteString;
      [self _presentMessage:@"Short Link copied to Clipboard" description:nil];
    } else {
      [self _presentMessage:@"Short Link is empty" description:nil];
    }
  }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0) {
    return kParamsConfiguration.count + 3;
  } else {
    return 0;
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row >= kParamsConfiguration.count) {
    return [self _customCellForRow:indexPath.row - kParamsConfiguration.count];
  } else {
    ParamTableViewCell *cell =
        (ParamTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"ParamTableViewCell"];
    if (!cell) {
      cell = [[ParamTableViewCell alloc] init];
    }
    NSDictionary *paramConfig = kParamsConfiguration[indexPath.row];
    cell.paramConfig = paramConfig;
    cell.textFieldValue = _paramValues[paramConfig[@"id"]];
    cell.delegate = self;
    return cell;
  }
}

- (void)paramTableViewCellUpdatedValue:(ParamTableViewCell *)cell;
{ _paramValues[cell.paramConfig[@"id"]] = cell.textFieldValue; }

#pragma mark - Private methods

- (UITableViewCell *)_customCellForRow:(NSUInteger)row {
  switch (row) {
    case 0: {
      UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                     reuseIdentifier:@"cell"];
      cell.textLabel.text = @"Generate Link";
      cell.accessibilityIdentifier = @"generate-link";
      cell.textLabel.textAlignment = NSTextAlignmentCenter;
      cell.textLabel.font = [UIFont boldSystemFontOfSize:22];
      return cell;
    } break;

    case 1:
    case 2: {
      LinkTableViewCell *cell = (LinkTableViewCell *)[self.tableView
          dequeueReusableCellWithIdentifier:@"LinkTableViewCell"];
      if (!cell) {
        cell = [[LinkTableViewCell alloc] init];
      }
      if (row == 1) {
        [cell setTitle:@"Long link" link:_longLink.absoluteString];
      } else {
        [cell setTitle:@"Short link" link:_shortLink.absoluteString];
      }
      return cell;
    } break;
    case 3: {
      UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                     reuseIdentifier:@"cell"];
      cell.textLabel.text = @"Perform FDL self diagnostic";
      cell.textLabel.textAlignment = NSTextAlignmentCenter;
      cell.textLabel.font = [UIFont systemFontOfSize:22];
      return cell;
    } break;
  }
  return nil;
}

- (void)_initDefaultValues {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kParamsConfiguration = @[
      // general link params
      @{
        @"id" : @"linkString",
        @"label" : @"Link value (required)",
        @"defaultValue" : @"https://www.google.com?q=jump",
      },
      // The default value of domain appcode belongs to project: app-invites-qa
      @{
        @"id" : @"domainURIPrefix",
        @"label" : @"App domainURIPrefix (required)",
        @"defaultValue" : @"https://testfdl.page.link",
      },
      // analytics params
      @{
        @"id" : @"FIRDynamicLinkGoogleAnalyticsParameters.source",
        @"label" : @"Google Analytics source (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkGoogleAnalyticsParameters.medium",
        @"label" : @"Google Analytics medium (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkGoogleAnalyticsParameters.campaign",
        @"label" : @"Google Analytics campaign (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkGoogleAnalyticsParameters.term",
        @"label" : @"Google Analytics term (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkGoogleAnalyticsParameters.content",
        @"label" : @"Google Analytics content (optional)",
        @"defaultValue" : @"",
      },
      // iOS params
      @{
        @"id" : @"FIRDynamicLinkIOSParameters.bundleId",
        @"label" : @"iOS App bundle ID",
        @"defaultValue" : [[NSBundle mainBundle] bundleIdentifier] ?: @"",
      },
      @{
        @"id" : @"FIRDynamicLinkIOSParameters.fallbackURL",
        @"label" : @"Fallback URL iOS (optional)",
      },
      @{
        @"id" : @"FIRDynamicLinkIOSParameters.minimumAppVersion",
        @"label" : @"minimum version of iOS App (optional)",
        @"defaultValue" : @"1.0",
      },
      @{
        @"id" : @"FIRDynamicLinkIOSParameters.customScheme",
        @"label" : @"iOS App custom scheme (optional)",
      },
      @{
        @"id" : @"FIRDynamicLinkIOSParameters.iPadBundleID",
        @"label" : @"iPad App bundleID (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkIOSParameters.iPadFallbackURL",
        @"label" : @"Fallback URL on iPad (optional)",
      },
      @{
        @"id" : @"FIRDynamicLinkIOSParameters.appStoreID",
        @"label" : @"iOS AppStore ID (optional)",
      },

      // iTunesConnect params
      @{
        @"id" : @"FIRDynamicLinkItunesConnectAnalyticsParameters.affiliateToken",
        @"label" : @"iTunesConnect affiliate token (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkItunesConnectAnalyticsParameters.campaignToken",
        @"label" : @"iTunesConnect campaign token (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkItunesConnectAnalyticsParameters.providerToken",
        @"label" : @"iTunesConnect provider token (optional)",
        @"defaultValue" : @"",
      },

      // Android params
      @{
        @"id" : @"FIRDynamicLinkAndroidParameters.packageName",
        @"label" : @"Android App package name (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkAndroidParameters.fallbackURL",
        @"label" : @"Android fallback URL (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkAndroidParameters.minimumVersion",
        @"label" : @"Andropid App minimum version, integer number (optional)",
        @"defaultValue" : @"",
      },

      // social tag params
      @{
        @"id" : @"FIRDynamicLinkSocialMetaTagParameters.title",
        @"label" : @"Social meta tag title (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkSocialMetaTagParameters.descriptionText",
        @"label" : @"Social meta tag description text (optional)",
        @"defaultValue" : @"",
      },
      @{
        @"id" : @"FIRDynamicLinkSocialMetaTagParameters.imageURL",
        @"label" : @"Social meta tag image URL (optional)",
        @"defaultValue" : @"",
      },

      // OtherPlatform params
      @{
        @"id" : @"FIRDynamicLinkOtherPlatformParameters.fallbackUrl",
        @"label" : @"OtherPlatform Fallback link (optional)",
        @"defaultValue" : @"",
      },
    ];
  });

  _paramValues = [[NSMutableDictionary alloc] initWithCapacity:kParamsConfiguration.count];
  for (NSDictionary *paramConfig in kParamsConfiguration) {
    if (paramConfig[@"defaultValue"]) {
      _paramValues[paramConfig[@"id"]] = paramConfig[@"defaultValue"];
    }
  }
}

- (void)_buildFDLLink {
  NSURL *link = [NSURL URLWithString:_paramValues[@"linkString"]];
  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link
                                   domainURIPrefix:_paramValues[@"domainURIPrefix"]];

  FIRDynamicLinkGoogleAnalyticsParameters *analyticsParams =
      [FIRDynamicLinkGoogleAnalyticsParameters
          parametersWithSource:_paramValues[@"FIRDynamicLinkGoogleAnalyticsParameters.source"]
                        medium:_paramValues[@"FIRDynamicLinkGoogleAnalyticsPara"
                                            @"meters.medium"]
                      campaign:_paramValues[@"FIRDynamicLinkGoogleAnalyticsPara"
                                            @"meters.campaign"]];
  analyticsParams.term = _paramValues[@"FIRDynamicLinkGoogleAnalyticsParameters.term"];
  analyticsParams.content = _paramValues[@"FIRDynamicLinkGoogleAnalyticsParameters.content"];

  FIRDynamicLinkIOSParameters *iOSParams;
  if (_paramValues[@"FIRDynamicLinkIOSParameters.bundleId"]) {
    iOSParams = [FIRDynamicLinkIOSParameters
        parametersWithBundleID:_paramValues[@"FIRDynamicLinkIOSParameters.bundleId"]];
    iOSParams.fallbackURL =
        [NSURL URLWithString:_paramValues[@"FIRDynamicLinkIOSParameters.fallbackURL"]];
    iOSParams.customScheme = _paramValues[@"FIRDynamicLinkIOSParameters.customScheme"];
    iOSParams.iPadBundleID = _paramValues[@"FIRDynamicLinkIOSParameters.iPadBundleID"];
    iOSParams.iPadFallbackURL =
        [NSURL URLWithString:_paramValues[@"FIRDynamicLinkIOSParameters.iPadFallbackURL"]];
    iOSParams.appStoreID = _paramValues[@"FIRDynamicLinkIOSParameters.appStoreId"];
    iOSParams.minimumAppVersion = _paramValues[@"FIRDynamicLinkIOSParameters.minimumAppVersion"];
  }

  FIRDynamicLinkItunesConnectAnalyticsParameters *appStoreParams =
      [FIRDynamicLinkItunesConnectAnalyticsParameters parameters];
  appStoreParams.affiliateToken =
      _paramValues[@"FIRDynamicLinkItunesConnectAnalyticsParameters.affiliateToken"];
  appStoreParams.campaignToken =
      _paramValues[@"FIRDynamicLinkItunesConnectAnalyticsParameters.campaignToken"];
  appStoreParams.providerToken =
      _paramValues[@"FIRDynamicLinkItunesConnectAnalyticsParameters.providerToken"];

  FIRDynamicLinkAndroidParameters *androidParams;
  if (_paramValues[@"FIRDynamicLinkAndroidParameters.packageName"]) {
    androidParams = [FIRDynamicLinkAndroidParameters
        parametersWithPackageName:_paramValues[@"FIRDynamicLinkAndroidParameters.packageName"]];
    androidParams.fallbackURL =
        [NSURL URLWithString:_paramValues[@"FIRDynamicLinkAndroidParameters.fallbackURL"]];
    if ([_paramValues[@"FIRDynamicLinkAndroidParameters.minimumVersion"] integerValue] > 0) {
      androidParams.minimumVersion =
          [_paramValues[@"FIRDynamicLinkAndroidParameters.minimumVersion"] integerValue];
    }
  }

  FIRDynamicLinkSocialMetaTagParameters *socialParams =
      [FIRDynamicLinkSocialMetaTagParameters parameters];
  socialParams.title = _paramValues[@"FIRDynamicLinkSocialMetaTagParameters.title"];
  socialParams.descriptionText =
      _paramValues[@"FIRDynamicLinkSocialMetaTagParameters.descriptionText"];
  socialParams.imageURL =
      [NSURL URLWithString:_paramValues[@"FIRDynamicLinkSocialMetaTagParameters.imageURL"]];

  FIRDynamicLinkOtherPlatformParameters *otherPlatformParams =
      [FIRDynamicLinkOtherPlatformParameters parameters];
  otherPlatformParams.fallbackUrl =
      [NSURL URLWithString:_paramValues[@"FIRDynamicLinkOtherPlatformParameters.fallbackUrl"]];

  FIRDynamicLinkComponentsOptions *options = [FIRDynamicLinkComponentsOptions options];
  options.pathLength = FIRShortDynamicLinkPathLengthShort;

  components.analyticsParameters = analyticsParams;
  components.iOSParameters = iOSParams;
  components.iTunesConnectParameters = appStoreParams;
  components.androidParameters = androidParams;
  components.socialMetaTagParameters = socialParams;
  components.otherPlatformParameters = otherPlatformParams;
  components.options = options;

  NSURL *longURL = components.url;
  // Handle longURL.
  NSLog(@"Long URL: %@", longURL);
  _longLink = longURL;
  [self.tableView
      reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:kParamsConfiguration.count + 1
                                                   inSection:0] ]
            withRowAnimation:UITableViewRowAnimationNone];

  [components shortenWithCompletion:^(NSURL *_Nullable shortURL, NSArray *_Nullable warnings,
                                      NSError *_Nullable error) {
    // Handle shortURL or error.
    NSLog(@"Short URL: %@, warnings: %@ error: %@", shortURL, warnings, error);
    if (error) {
      [self _presentMessage:@"Error generating short link" description:[error description]];
    }
    _shortLink = shortURL;
    [self.tableView
        reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:kParamsConfiguration.count + 2
                                                     inSection:0] ]
              withRowAnimation:UITableViewRowAnimationNone];
  }];
}

- (void)_presentMessage:(NSString *)message description:(NSString *)description {
  UIAlertController *alertVC =
      [UIAlertController alertControllerWithTitle:message
                                          message:description
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alertVC addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                              style:UIAlertActionStyleCancel
                                            handler:NULL]];
  [self presentViewController:alertVC animated:YES completion:NULL];
}

@end
