//
//  ViewControllerObjC.m
//  authtest13
//
//  Created by Jeremy Durham on 2/19/20.
//  Copyright © 2020 Pranav Rajgopal. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ViewControllerObjC.h"
#import <FIRAppDistribution.h>

@implementation ViewControllerObjC

- (void)viewDidLoad:(BOOL)animated{
    NSLog(@"here!");
    [super viewDidLoad];
    [[FIRAppDistribution appDistribution] checkForUpdateWithView:self completion:^(FIRAppDistributionRelease * _Nullable release, NSError * _Nullable error) {
        NSLog(@"%@", release);
        if (release) {
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"New Version Available"
                                                                             message:[NSString stringWithFormat:@"Version %@ (%@) is available.",
                                                                                      release.bundleShortVersion, release.bundleVersion]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *updateAction = [UIAlertAction actionWithTitle:@"Update" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            }];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            }];
            
            [alert addAction:updateAction];
            [alert addAction:cancelAction];
            
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

@end
