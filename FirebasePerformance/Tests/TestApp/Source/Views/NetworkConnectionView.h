// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
  ConnectionStatus_NA = 0,
  ConnectionStatus_Fail,
  ConnectionStatus_Success
} PerfConnectionStatus;

@class NetworkConnectionView;

@protocol NetworkConnectionViewDelegate <NSObject>

/**
 * Delegate method that is called on start request button tapped.
 *
 * @param connectionView Instance of the NetworkConnectionView.
 */
- (void)networkConnectionViewDidTapRequestButton:(nonnull NetworkConnectionView *)connectionView;

@end

/**
 * A view which represents Network Connection operation.
 */
@interface NetworkConnectionView : UIView

@property(nonatomic, assign) PerfConnectionStatus connectionStatus;

@property(nonatomic, weak, nullable) id<NetworkConnectionViewDelegate> delegate;

@property(nonatomic, copy, nullable) NSString *title;

@property(nonatomic, nullable) UIColor *progressViewColor;

@property(nonatomic, nullable) UIButton *networkCallButton;

@property(nonatomic, nullable) UILabel *connectionStatusLabel;

/** @brief Not a valid initializer. */
- (nonnull instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

/** @brief Not a valid initializer. */
- (nonnull instancetype)initWithCoder:(nullable NSCoder *)coder NS_UNAVAILABLE;

- (void)setProgress:(float)progress animated:(BOOL)animated;

@end
