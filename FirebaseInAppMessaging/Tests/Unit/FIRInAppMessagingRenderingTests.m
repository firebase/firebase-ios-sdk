/*
 * Copyright 2021 Google LLC
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

#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Public/FirebaseInAppMessaging/FIRInAppMessagingRendering.h"

@interface FIRInAppMessagingRenderingTests : XCTestCase

@end

@implementation FIRInAppMessagingRenderingTests

+ (FIRInAppMessagingImageData *)testImageData {
  NSData *blankImageData = UIImagePNGRepresentation([[UIImage alloc] init]);
  return [[FIRInAppMessagingImageData alloc] initWithImageURL:@"http://google.com"
                                                    imageData:blankImageData];
}

+ (FIRInAppMessagingActionButton *)testActionButton {
  return [[FIRInAppMessagingActionButton alloc] initWithButtonText:@"Tap me"
                                                   buttonTextColor:[UIColor brownColor]
                                                   backgroundColor:[UIColor yellowColor]];
}

- (void)testCardMessageInit {
  FIRInAppMessagingCardDisplay *cardMessage = [[FIRInAppMessagingCardDisplay alloc]
       initWithCampaignName:@"campaignName"
                  titleText:@"titleText"
                   bodyText:@"bodyText"
                  textColor:[UIColor systemPinkColor]
          portraitImageData:[[self class] testImageData]
         landscapeImageData:nil
            backgroundColor:[UIColor redColor]
        primaryActionButton:[[self class] testActionButton]
      secondaryActionButton:nil
           primaryActionURL:[NSURL URLWithString:@"http://test.com"]
         secondaryActionURL:nil
                    appData:@{@"emoji" : @"📺"}];

  // Message initializers for test messages should have these stock parameters.
  XCTAssertEqualObjects(cardMessage.campaignInfo.messageID, @"test_message_id");
  XCTAssertTrue(cardMessage.campaignInfo.renderAsTestMessage);
  XCTAssertEqual(cardMessage.triggerType, FIRInAppMessagingDisplayTriggerTypeOnAnalyticsEvent);

  XCTAssertEqualObjects(cardMessage.campaignInfo.campaignName, @"campaignName");
  XCTAssertEqualObjects(cardMessage.title, @"titleText");
  XCTAssertEqualObjects(cardMessage.body, @"bodyText");
  XCTAssertEqualObjects(cardMessage.textColor, [UIColor systemPinkColor]);
  XCTAssertNotNil(cardMessage.portraitImageData);
  XCTAssertNil(cardMessage.landscapeImageData);
  XCTAssertEqualObjects(cardMessage.displayBackgroundColor, [UIColor redColor]);
  XCTAssertEqualObjects(cardMessage.primaryActionButton.buttonText, @"Tap me");
  XCTAssertEqualObjects(cardMessage.primaryActionButton.buttonTextColor, [UIColor brownColor]);
  XCTAssertEqualObjects(cardMessage.primaryActionButton.buttonBackgroundColor,
                        [UIColor yellowColor]);
  XCTAssertNil(cardMessage.secondaryActionButton);
  XCTAssertEqualObjects(cardMessage.primaryActionURL, [NSURL URLWithString:@"http://test.com"]);
  XCTAssertNil(cardMessage.secondaryActionURL);
  XCTAssertEqualObjects(cardMessage.appData[@"emoji"], @"📺");
}

- (void)testModalMessageInit {
  FIRInAppMessagingModalDisplay *modalMessage = [[FIRInAppMessagingModalDisplay alloc]
      initWithCampaignName:@"campaignName"
                 titleText:@"titleText"
                  bodyText:@"bodyText"
                 textColor:[UIColor systemTealColor]
           backgroundColor:[UIColor grayColor]
                 imageData:[[self class] testImageData]
              actionButton:[[self class] testActionButton]
                 actionURL:[NSURL URLWithString:@"http://modal-test.com"]
                   appData:@{@"emoji" : @"🇵🇷"}];

  XCTAssertEqualObjects(modalMessage.campaignInfo.messageID, @"test_message_id");
  XCTAssertTrue(modalMessage.campaignInfo.renderAsTestMessage);
  XCTAssertEqual(modalMessage.triggerType, FIRInAppMessagingDisplayTriggerTypeOnAnalyticsEvent);

  XCTAssertEqualObjects(modalMessage.campaignInfo.campaignName, @"campaignName");
  XCTAssertEqualObjects(modalMessage.title, @"titleText");
  XCTAssertEqualObjects(modalMessage.bodyText, @"bodyText");
  XCTAssertEqualObjects(modalMessage.textColor, [UIColor systemTealColor]);
  XCTAssertNotNil(modalMessage.imageData);
  XCTAssertEqualObjects(modalMessage.displayBackgroundColor, [UIColor grayColor]);
  XCTAssertEqualObjects(modalMessage.actionButton.buttonText, @"Tap me");
  XCTAssertEqualObjects(modalMessage.actionButton.buttonTextColor, [UIColor brownColor]);
  XCTAssertEqualObjects(modalMessage.actionButton.buttonBackgroundColor, [UIColor yellowColor]);
  XCTAssertEqualObjects(modalMessage.actionURL, [NSURL URLWithString:@"http://modal-test.com"]);
  XCTAssertEqualObjects(modalMessage.appData[@"emoji"], @"🇵🇷");
}

- (void)testBannerMessageInit {
  FIRInAppMessagingBannerDisplay *bannerMessage = [[FIRInAppMessagingBannerDisplay alloc]
      initWithCampaignName:@"campaignName"
                 titleText:@"titleText"
                  bodyText:@"bodyText"
                 textColor:[UIColor clearColor]
           backgroundColor:[UIColor blueColor]
                 imageData:[[self class] testImageData]
                 actionURL:[NSURL URLWithString:@"http://banner-test.com"]
                   appData:@{@"emoji" : @"🇲🇽"}];

  XCTAssertEqualObjects(bannerMessage.campaignInfo.messageID, @"test_message_id");
  XCTAssertTrue(bannerMessage.campaignInfo.renderAsTestMessage);
  XCTAssertEqual(bannerMessage.triggerType, FIRInAppMessagingDisplayTriggerTypeOnAnalyticsEvent);

  XCTAssertEqualObjects(bannerMessage.campaignInfo.campaignName, @"campaignName");
  XCTAssertEqualObjects(bannerMessage.title, @"titleText");
  XCTAssertEqualObjects(bannerMessage.bodyText, @"bodyText");
  XCTAssertEqualObjects(bannerMessage.textColor, [UIColor clearColor]);
  XCTAssertNotNil(bannerMessage.imageData);
  XCTAssertEqualObjects(bannerMessage.displayBackgroundColor, [UIColor blueColor]);
  XCTAssertEqualObjects(bannerMessage.actionURL, [NSURL URLWithString:@"http://banner-test.com"]);
  XCTAssertEqualObjects(bannerMessage.appData[@"emoji"], @"🇲🇽");
}

- (void)testImageOnlyMessageInit {
  FIRInAppMessagingImageOnlyDisplay *imageOnlyMessage = [[FIRInAppMessagingImageOnlyDisplay alloc]
      initWithCampaignName:@"campaignName"
                 imageData:[[self class] testImageData]
                 actionURL:[NSURL URLWithString:@"http://image-test.com"]
                   appData:@{@"emoji" : @"🥊"}];

  XCTAssertEqualObjects(imageOnlyMessage.campaignInfo.messageID, @"test_message_id");
  XCTAssertTrue(imageOnlyMessage.campaignInfo.renderAsTestMessage);
  XCTAssertEqual(imageOnlyMessage.triggerType, FIRInAppMessagingDisplayTriggerTypeOnAnalyticsEvent);

  XCTAssertEqualObjects(imageOnlyMessage.campaignInfo.campaignName, @"campaignName");
  XCTAssertNotNil(imageOnlyMessage.imageData);
  XCTAssertEqualObjects(imageOnlyMessage.actionURL, [NSURL URLWithString:@"http://image-test.com"]);
  XCTAssertEqualObjects(imageOnlyMessage.appData[@"emoji"], @"🥊");
}

@end
