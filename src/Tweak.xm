//
//  Tweak.xm
//  注入入口
//
//  主入口:启动时调 WCRPluginRegistrar,把「界面圆角」注册进 WCPluginsMgr(插件收纳)。
//  兜底:只有在 WCPluginsMgr 注册不成功时,才在微信设置页右上角补一个入口,
//        保证任何机型都能进到面板。
//

#import <UIKit/UIKit.h>
#import "WCRCorner.h"
#include <substrate.h>

// 微信设置页(真实类是 UIViewController 子类,这里给出声明供编译期使用)
@interface NewSettingViewController : UIViewController
@end

#pragma mark - 设置页兜底入口

%hook NewSettingViewController

- (void)viewDidLoad {
    %orig;
    if (![WCRPluginRegistrar needsFallbackEntry]) return;
    UIBarButtonItem *item =
        [[UIBarButtonItem alloc] initWithTitle:WCRPluginEntryTitle
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(wcr_openCornerPanel)];
    item.accessibilityIdentifier = @"wcr_corner_entry";
    self.navigationItem.rightBarButtonItem = item;
}

%new
- (void)wcr_openCornerPanel {
    UIViewController *vc = [WCRPluginRegistrar makeEntryViewController];
    [self.navigationController pushViewController:vc animated:YES];
}

%end

#pragma mark - 启动

%ctor {
    @autoreleasepool {
        // 预热配置(首次会写入默认值)
        [WCRCornerConfig shared];
        // 注册进插件收纳
        [WCRPluginRegistrar registerAll];
        // 安装渲染 hook
        [WCRCornerHookCenter install];
    }
}
