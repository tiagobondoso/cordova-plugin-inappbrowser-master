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

#import "CDVUserAgentUtilCompat.h"

#if !__has_include(<Cordova/CDVUserAgentUtil.h>)

#import <WebKit/WebKit.h>

static NSString* gOriginalUserAgent = nil;
static NSInteger gNextLockToken = 1;
static NSInteger gActiveLockToken = 0;
static dispatch_queue_t gUserAgentQueue;

@implementation CDVUserAgentUtil

+ (void)initialize
{
    if (self == [CDVUserAgentUtil class]) {
        gUserAgentQueue = dispatch_queue_create("cordova.plugin.inappbrowser.useragent", DISPATCH_QUEUE_SERIAL);
    }
}

+ (NSString*)originalUserAgent
{
    __block NSString* userAgent = nil;
    dispatch_sync(gUserAgentQueue, ^{
        userAgent = gOriginalUserAgent;
    });
    if (userAgent != nil && [userAgent length] > 0) {
        return userAgent;
    }

    NSString* storedAgent = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserAgent"];
    if ([storedAgent length] == 0) {
        storedAgent = [self fetchDefaultUserAgent];
    }
    if ([storedAgent length] == 0) {
        storedAgent = @"Mozilla/5.0";
    }

    dispatch_sync(gUserAgentQueue, ^{
        if ([gOriginalUserAgent length] == 0) {
            gOriginalUserAgent = [storedAgent copy];
        }
        userAgent = gOriginalUserAgent;
    });
    return userAgent;
}

+ (NSString*)fetchDefaultUserAgent
{
    __block NSString* userAgent = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    void (^evaluationBlock)(void) = ^{
        WKWebView* webView = [[WKWebView alloc] initWithFrame:CGRectZero];
        [webView evaluateJavaScript:@"navigator.userAgent"
                   completionHandler:^(id result, NSError* error) {
                       if ([result isKindOfClass:[NSString class]]) {
                           userAgent = result;
                       }
                       dispatch_semaphore_signal(semaphore);
                   }];
    };

    if ([NSThread isMainThread]) {
        evaluationBlock();
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), evaluationBlock);
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }

    return userAgent;
}

+ (void)acquireLock:(void (^)(NSInteger lockToken))block
{
    if (block == nil) {
        return;
    }
    dispatch_sync(gUserAgentQueue, ^{
        gActiveLockToken = gNextLockToken++;
        block(gActiveLockToken);
    });
}

+ (void)releaseLock:(NSInteger*)lockToken
{
    dispatch_sync(gUserAgentQueue, ^{
        if ((lockToken != NULL) && (*lockToken == gActiveLockToken)) {
            gActiveLockToken = 0;
            *lockToken = 0;
        }
    });
}

+ (void)setUserAgent:(NSString*)value lockToken:(NSInteger)lockToken
{
    if ((lockToken == 0) || ([value length] == 0)) {
        return;
    }

    dispatch_sync(gUserAgentQueue, ^{
        if (lockToken == gActiveLockToken) {
            [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"UserAgent": value }];
            [[NSUserDefaults standardUserDefaults] synchronize];
            gOriginalUserAgent = [value copy];
        }
    });
}

@end

#endif
