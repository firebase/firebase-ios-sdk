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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FIRIAMRenderingMode) {
  FIRIAMRenderAsBannerView,
  FIRIAMRenderAsModalView,
  FIRIAMRenderAsImageOnlyView,
  FIRIAMRenderAsCardView
};

/**
 * A class for modeling rendering effect settings for in-app messaging
 */
@interface FIRIAMRenderingEffectSetting : NSObject

@property(nonatomic) FIRIAMRenderingMode viewMode;

// background color for the display area, including both the text's background and
// padding's background
@property(nonatomic, copy) UIColor *displayBGColor;

// text color, covering both the title and body texts
@property(nonatomic, copy) UIColor *textColor;

// text color for action button
@property(nonatomic, copy) UIColor *btnTextColor;

// text color for secondary action button
@property(nonatomic, copy) UIColor *secondaryActionBtnTextColor;

// background color for action button
@property(nonatomic, copy) UIColor *btnBGColor;

// duration of the banner view before triggering auto-dismiss
@property(nonatomic) CGFloat autoDimissBannerAfterNSeconds;

// A flag to control rendering the message as a client-side testing message
@property(nonatomic) BOOL isTestMessage;

+ (instancetype)getDefaultRenderingEffectSetting;
@end
NS_ASSUME_NONNULL_END
