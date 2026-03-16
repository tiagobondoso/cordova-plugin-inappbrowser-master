/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVInAppBrowserNavigationController.h"
#import <objc/runtime.h>

#define    STATUSBAR_HEIGHT 20.0

@implementation CDVInAppBrowserNavigationController : UINavigationController

- (void) dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    if ( self.presentedViewController) {
        [super dismissViewControllerAnimated:flag completion:completion];
    }
}

- (UIWindowScene *)currentWindowScene
{
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = self.view.window.windowScene;
        if (windowScene != nil) {
            return windowScene;
        }

        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                return (UIWindowScene *)scene;
            }
        }
    }
    return nil;
}

- (CGRect)statusBarFrame
{
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self currentWindowScene];
        if (scene.statusBarManager != nil) {
            return scene.statusBarManager.statusBarFrame;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].statusBarFrame;
#pragma clang diagnostic pop
}

- (UIInterfaceOrientation)currentInterfaceOrientation
{
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self currentWindowScene];
        UIInterfaceOrientation orientation = scene.interfaceOrientation;
        if (orientation != UIInterfaceOrientationUnknown) {
            return orientation;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].statusBarOrientation;
#pragma clang diagnostic pop
}

- (void) viewDidLoad {

    CGRect statusBarFrame = [self invertFrameIfNeeded:[self statusBarFrame]];
    statusBarFrame.size.height = STATUSBAR_HEIGHT;
    // simplified from: http://stackoverflow.com/a/25669695/219684

    UIToolbar* bgToolbar = [[UIToolbar alloc] initWithFrame:statusBarFrame];
    bgToolbar.barStyle = UIBarStyleDefault;
    [bgToolbar setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [self.view addSubview:bgToolbar];

    [super viewDidLoad];
}

- (CGRect) invertFrameIfNeeded:(CGRect)rect {
    if (UIInterfaceOrientationIsLandscape([self currentInterfaceOrientation])) {
        CGFloat temp = rect.size.width;
        rect.size.width = rect.size.height;
        rect.size.height = temp;
    }
    rect.origin = CGPointZero;
    return rect;
}

#pragma mark CDVScreenOrientationDelegate

- (BOOL)shouldAutorotate
{
    if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(shouldAutorotate)]) {
        return [self.orientationDelegate shouldAutorotate];
    }
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(supportedInterfaceOrientations)]) {
        return [self.orientationDelegate supportedInterfaceOrientations];
    }

    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    SEL legacySelector = @selector(shouldAutorotateToInterfaceOrientation:);

    id target = self.orientationDelegate;
    if ((target != nil) && [target respondsToSelector:legacySelector]) {
        IMP implementation = [target methodForSelector:legacySelector];
        if (implementation != NULL) {
            BOOL (*legacyMethod)(id, SEL, UIInterfaceOrientation) = (BOOL (*)(id, SEL, UIInterfaceOrientation))implementation;
            return legacyMethod(target, legacySelector, interfaceOrientation);
        }
    }

    return YES;
}


@end
