//
//  RoundedCornersView.m
//  FirebaseInAppMessagingDisplay
//
//  Created by Chris Tibbs on 2/9/19.
//

#import "RoundedCornersView.h"

@implementation RoundedCornersView

- (void)setCornerRadius:(CGFloat)cornerRadius {
  self.layer.cornerRadius = cornerRadius;
  self.layer.masksToBounds = cornerRadius > 0;
}

@end
