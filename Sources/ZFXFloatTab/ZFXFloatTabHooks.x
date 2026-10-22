//
//  Tweak.xm
//  悬浮底栏 —— 入口与 Hook
//
//  接管点（与原插件完全一致）：
//    MMTabBar            layoutSubviews / hitTest:withEvent: / selectIndex: / 各类外观 setter
//    UITabBarButton      layoutSubviews（同步选中态）
//    MMTabBarItemView    layoutSubviews / setSelected:（同步选中态）
//

#import <UIKit/UIKit.h>
#import "ZFXFloatTabPrefs.h"
#import "ZFXFloatTabBar.h"
#import "ZFXFloatTabSettings.h"
#import "ZFXFloatTabGestures.h"

@interface MMTabBar : UIView
@end
@interface UITabBarButton : UIControl
@end
@interface MMTabBarItemView : UIView
@end

%group ZFXFloatTab

%hook MMTabBar

- (void)layoutSubviews {
    %orig;
    [[ZFXFloatTabManager shared] layoutTabBar:self];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *result = %orig;
    UIView *extended = [[ZFXFloatTabManager shared] hitTestExtensionForTabBar:self
                                                                        point:point
                                                                        event:event];
    return extended ?: result;
}

- (void)selectIndex:(unsigned long)index {
    %orig;
    [[ZFXFloatTabManager shared] tabBar:self didSelectIndex:(NSInteger)index];
}

// 外观 setter：开启悬浮底栏后阻断原生底栏背景/描边，避免和悬浮层打架
- (void)setBackgroundColor:(UIColor *)color {
    if ([[ZFXFloatTabManager shared] shouldSuppressNativeAppearance]) return;
    %orig;
}

- (void)setBackgroundImage:(UIImage *)image {
    if ([[ZFXFloatTabManager shared] shouldSuppressNativeAppearance]) return;
    %orig;
}

- (void)setShadowImage:(UIImage *)image {
    if ([[ZFXFloatTabManager shared] shouldSuppressNativeAppearance]) return;
    %orig;
}

- (void)setBarTintColor:(UIColor *)color {
    if ([[ZFXFloatTabManager shared] shouldSuppressNativeAppearance]) return;
    %orig;
}

- (void)setStandardAppearance:(id)appearance {
    if ([[ZFXFloatTabManager shared] shouldSuppressNativeAppearance]) return;
    %orig;
}

- (void)setScrollEdgeAppearance:(id)appearance {
    if ([[ZFXFloatTabManager shared] shouldSuppressNativeAppearance]) return;
    %orig;
}

%end

%hook UITabBarButton

- (void)layoutSubviews {
    %orig;
    if (![[ZFXFloatTabManager shared] enabled]) return;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}

%end

%hook MMTabBarItemView

- (void)layoutSubviews {
    %orig;
    if (![[ZFXFloatTabManager shared] enabled]) return;
    self.alpha = 0.0;
}

- (void)setSelected:(BOOL)selected {
    %orig;
    [[ZFXFloatTabManager shared] reloadConfig];
}

%end

%end // ZFXFloatTab

#pragma mark - 入口

static void ZFXFloatTabStart(void) {
    [ZFXPrefs registerDefaults];
    [[ZFXFloatTabManager shared] install];
    [[ZFXEdgeBackController shared] updateEnabledState];

    [[NSNotificationCenter defaultCenter] addObserverForName:ZFXSettingsChangedNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        [[ZFXEdgeBackController shared] updateEnabledState];
    }];

    // 退出登录/切换账号时 NSUserDefaults 会变化，兜底刷新一次
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        [[ZFXEdgeBackController shared] updateEnabledState];
    }];
}

%ctor {
    ZFXFloatTabStart();
    %init(ZFXFloatTab);
}
