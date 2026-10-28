//
//  SceneDelegate.m
//  Dopamine
//
//  Created by Lars Fröder on 23.09.23.
//

#import "DOSceneDelegate.h"
#import "DONavigationController.h"
#import "DONavigationControllerOfficial.h"
#import "DOPreferenceManager.h"

@interface DOSceneDelegate ()

@end

static UINavigationController *DOOfficialAwareNavigationController(void)
{
    BOOL official = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"officialUIEnabled" fallback:YES];
    if (official) {
        return [[DONavigationControllerOfficial alloc] init];
    }
    return [[DONavigationController alloc] init];
}

static NSTimeInterval DOLastReleaseCheckTimestamp = 0;

static void DOFetchLatestReleaseInfo(void)
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - DOLastReleaseCheckTimestamp < 600) return;
    DOLastReleaseCheckTimestamp = now;

    NSURL *url = [NSURL URLWithString:@"https://api.github.com/repos/WhyWhySeeYa/Dopamine-3x-build/releases/latest"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:15];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data.length == 0) return;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) return;
        NSString *tag = json[@"tag_name"];
        if (![tag isKindOfClass:[NSString class]] || tag.length == 0) return;

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *lastTag = [defaults stringForKey:@"DOLastKnownReleaseTag"];
        [defaults setObject:tag forKey:@"DOLastKnownReleaseTag"];
        [defaults synchronize];

        // 首次运行只记录不打扰；只有出现新构建才提示一次
        if (lastTag.length == 0 || [lastTag isEqualToString:tag]) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow) { keyWindow = w; break; }
                }
                if (keyWindow) break;
            }
            UIViewController *presenter = keyWindow.rootViewController;
            while (presenter.presentedViewController) presenter = presenter.presentedViewController;
            if (!presenter) return;

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"发现新版本"
                                                                           message:[NSString stringWithFormat:@"最新构建：%@", tag]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            NSString *htmlURL = json[@"html_url"];
            if ([htmlURL isKindOfClass:[NSString class]] && htmlURL.length > 0) {
                [alert addAction:[UIAlertAction actionWithTitle:@"前往下载" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    NSURL *pageURL = [NSURL URLWithString:htmlURL];
                    if (pageURL) [[UIApplication sharedApplication] openURL:pageURL options:@{} completionHandler:nil];
                }]];
            }
            [alert addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:nil]];
            [presenter presentViewController:alert animated:YES completion:nil];
        });
    }] resume];
}

@implementation DOSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    window.rootViewController = DOOfficialAwareNavigationController();
    [window makeKeyAndVisible];
    self.window = window;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DOFetchLatestReleaseInfo();
    });
}

+ (void)relaunch
{
    UIWindowScene *windowScene = (UIWindowScene *)[[[UIApplication sharedApplication] connectedScenes] anyObject];
    DOSceneDelegate *instance = (DOSceneDelegate *)windowScene.delegate;

    [UIView animateWithDuration:0.3 animations:^{
        instance.window.alpha = 0;
    } completion:^(BOOL finished) {
        UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)instance.window.windowScene];
        window.rootViewController = DOOfficialAwareNavigationController();
        [window makeKeyAndVisible];
        instance.window = window;
        instance.window.alpha = 0;
        [UIView animateWithDuration:0.3 animations:^{
            instance.window.alpha = 1;
        }];
    }];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    DOFetchLatestReleaseInfo();
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}


@end
