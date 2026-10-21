//
//  WCREngine.mm
//  圆角渲染引擎 —— 把配置真正套到微信的视图上
//
//  原插件把渲染散在整包几十个 hook 里(没有独立的 corner 渲染类可对齐),
//  这里用统一入口重写:C++ 侧算参数,ObjC++ 侧只做 hook 与调用。
//

#import "WCRCorner.h"
#import <objc/runtime.h>

static inline WCRCornerConfig *Cfg(void) { return [WCRCornerConfig shared]; }

#pragma mark - ==================== C++ 计算层 ====================

double WCRCornerPainter::radiusForTarget(WCRCornerTarget t) {
    switch (t) {
        case WCRCornerTargetSearchBar:      return Cfg().searchCornerEnabled      ? Cfg().searchCornerRadius : 0;
        case WCRCornerTargetInputBar:       return Cfg().inputCornerEnabled       ? Cfg().inputCornerRadius : 0;
        case WCRCornerTargetKeyboard:       return Cfg().imeKeyboardCornerEnabled ? Cfg().imeKeyboardCornerRadius : 0;
        case WCRCornerTargetTopbar:         return Cfg().topbarCornerEnabled      ? Cfg().topbarCornerRadius : 0;
        case WCRCornerTargetToolbar:        return Cfg().toolbarCornerEnabled     ? Cfg().toolbarCornerRadius : 0;
        case WCRCornerTargetEmoji:          return Cfg().emojiCornerEnabled       ? Cfg().emojiCornerRadius : 0;
        case WCRCornerTargetChatImage:      return Cfg().chatImageCornerEnabled   ? Cfg().chatImageCornerRadius : 0;
        case WCRCornerTargetChatBubble:     return Cfg().chatBubbleCornerEnabled  ? Cfg().chatBubbleCornerRadius : 0;
        case WCRCornerTargetChatTime:       return Cfg().chatTimeRoundCornerEnabled ? Cfg().chatTimeRoundCornerRadius : 0;
        case WCRCornerTargetMsgRefer:       return Cfg().msgReferCornerEnabled    ? Cfg().msgReferCornerRadius : 0;
        case WCRCornerTargetSystemMessage:  return Cfg().systemMessageCornerEnabled ? Cfg().systemMessageCornerRadius : 0;
        case WCRCornerTargetSystemNotice:   return Cfg().systemNoticeCornerEnabled ? Cfg().systemNoticeCornerRadius : 0;
        case WCRCornerTargetVoiceTranslate: return Cfg().voiceTranslateCornerEnabled ? Cfg().voiceTranslateCornerRadius : 0;
        case WCRCornerTargetMoment:         return Cfg().momentCornerEnabled      ? Cfg().momentCornerRadius : 0;
        case WCRCornerTargetFinder:         return Cfg().finderCornerEnabled      ? Cfg().finderCornerRadius : 0;
        case WCRCornerTargetService:        return Cfg().serviceCornerEnabled     ? Cfg().serviceCornerRadius : 0;
        case WCRCornerTargetPlusMenu:       return Cfg().plusMenuCornerEnabled    ? Cfg().plusMenuCornerRadius : 0;
        case WCRCornerTargetSendButton:     return Cfg().sendPublishButtonCornerEnabled ? Cfg().sendPublishButtonCornerRadius : 0;
        case WCRCornerTargetSystemPopup:    return Cfg().systemPopupCornerEnabled ? Cfg().systemPopupCornerRadius : 0;
        case WCRCornerTargetSwipeMenu:      return Cfg().mainFrameSwipeMenuCornerEnabled ? Cfg().mainFrameSwipeMenuCornerRadius : 0;
    }
    return 0;
}

double WCRCornerPainter::borderWidthForTarget(WCRCornerTarget t) {
    CGFloat w = 0;
    switch (t) {
        case WCRCornerTargetSearchBar:      w = Cfg().searchCornerBorderSize; break;
        case WCRCornerTargetInputBar:       w = Cfg().inputCornerBorderSize; break;
        case WCRCornerTargetKeyboard:       w = Cfg().imeKeyboardCornerBorderSize; break;
        case WCRCornerTargetTopbar:         w = Cfg().topbarCornerBorderSize; break;
        case WCRCornerTargetToolbar:        w = Cfg().toolbarCornerBorderSize; break;
        case WCRCornerTargetEmoji:          w = Cfg().emojiCornerBorderSize; break;
        case WCRCornerTargetChatImage:      w = Cfg().chatImageCornerBorderSize; break;
        case WCRCornerTargetChatBubble:     w = Cfg().chatBubbleCornerBorderSize; break;
        case WCRCornerTargetChatTime:       w = Cfg().chatTimeRoundCornerBorderSize; break;
        case WCRCornerTargetMsgRefer:       w = Cfg().msgReferCornerBorderSize; break;
        case WCRCornerTargetSystemMessage:  w = Cfg().systemMessageCornerBorderSize; break;
        case WCRCornerTargetSystemNotice:   w = Cfg().systemNoticeCornerBorderSize; break;
        case WCRCornerTargetVoiceTranslate: w = Cfg().voiceTranslateCornerBorderSize; break;
        case WCRCornerTargetMoment:         w = Cfg().momentCornerBorderSize; break;
        case WCRCornerTargetFinder:         w = Cfg().finderCornerBorderSize; break;
        case WCRCornerTargetService:        w = Cfg().serviceCornerBorderSize; break;
        case WCRCornerTargetPlusMenu:       w = Cfg().plusMenuBorderSize; break;
        case WCRCornerTargetSendButton:     w = Cfg().sendPublishButtonCornerBorderSize; break;
        case WCRCornerTargetSystemPopup:    w = Cfg().systemPopupCornerBorderSize; break;
        case WCRCornerTargetSwipeMenu:      w = 0; break;
    }
    return (double)w;
}

unsigned int WCRCornerPainter::borderColorForTarget(WCRCornerTarget t) {
    UIColor *c = nil;
    switch (t) {
        case WCRCornerTargetSearchBar:      c = WCR_COLOR(searchCornerBorderColor); break;
        case WCRCornerTargetInputBar:       c = WCR_COLOR(inputCornerBorderColor); break;
        case WCRCornerTargetKeyboard:       c = WCR_COLOR(imeKeyboardCornerBorderColor); break;
        case WCRCornerTargetTopbar:         c = WCR_COLOR(topbarCornerBorderColor); break;
        case WCRCornerTargetToolbar:        c = WCR_COLOR(toolbarCornerBorderColor); break;
        case WCRCornerTargetEmoji:          c = WCR_COLOR(emojiCornerBorderColor); break;
        case WCRCornerTargetChatImage:      c = WCR_COLOR(chatImageCornerBorderColor); break;
        case WCRCornerTargetChatBubble:     c = WCR_COLOR(chatBubbleCornerBorderColor); break;
        case WCRCornerTargetChatTime:       c = WCR_COLOR(chatTimeRoundCornerBorderColor); break;
        case WCRCornerTargetMsgRefer:       c = WCR_COLOR(msgReferCornerBorderColor); break;
        case WCRCornerTargetSystemMessage:  c = WCR_COLOR(systemMessageCornerBorderColor); break;
        case WCRCornerTargetSystemNotice:   c = WCR_COLOR(systemNoticeCornerBorderColor); break;
        case WCRCornerTargetVoiceTranslate: c = WCR_COLOR(voiceTranslateCornerBorderColor); break;
        case WCRCornerTargetMoment:         c = WCR_COLOR(momentCornerBorderColor); break;
        case WCRCornerTargetFinder:         c = WCR_COLOR(finderCornerBorderColor); break;
        case WCRCornerTargetService:        c = WCR_COLOR(serviceCornerBorderColor); break;
        case WCRCornerTargetPlusMenu:       c = WCR_COLOR(plusMenuBorderColor); break;
        case WCRCornerTargetSendButton:     c = WCR_COLOR(sendPublishButtonBorderColor); break;
        case WCRCornerTargetSystemPopup:    c = WCR_COLOR(systemPopupBorderColor); break;
        case WCRCornerTargetSwipeMenu:      c = [UIColor clearColor]; break;
    }
    CGFloat r = 0, g = 0, b = 0, a = 1;
    [c getRed:&r green:&g blue:&b alpha:&a];
    return ((unsigned)(r * 255) << 24) | ((unsigned)(g * 255) << 16) | ((unsigned)(b * 255) << 8) | (unsigned)(a * 255);
}

void WCRCornerPainter::applyCorners(CALayer *layer, WCRCornerTarget t,
                                    bool tl, bool tr, bool bl, bool br) {
    if (!layer) return;
    double radius = radiusForTarget(t);
    if (radius <= 0.01) {
        layer.cornerRadius = 0;
        layer.borderWidth = 0;
        layer.mask = nil;
        return;
    }
    if (tl && tr && bl && br) {
        layer.cornerRadius = (CGFloat)radius;
        layer.mask = nil;
    } else {
        // 只圆部分角:用 mask 会破坏原有遮罩,这里退化成整体圆角 + 单边置零
        layer.cornerRadius = (CGFloat)radius;
        if (@available(iOS 11.0, *)) {
            CACornerMask mask = 0;
            if (tl) mask |= kCALayerMinXMinYCorner;
            if (tr) mask |= kCALayerMaxXMinYCorner;
            if (bl) mask |= kCALayerMinXMaxYCorner;
            if (br) mask |= kCALayerMaxXMaxYCorner;
            layer.maskedCorners = mask;
        }
    }
    double bw = borderWidthForTarget(t);
    unsigned int rgba = borderColorForTarget(t);
    layer.borderWidth = (CGFloat)bw;
    if (bw > 0.001) {
        layer.borderColor = [UIColor colorWithRed:((rgba >> 24) & 0xFF) / 255.0
                                            green:((rgba >> 16) & 0xFF) / 255.0
                                             blue:((rgba >> 8) & 0xFF) / 255.0
                                            alpha:(rgba & 0xFF) / 255.0].CGColor;
    }
}

void WCRCornerPainter::apply(CALayer *layer, WCRCornerTarget t) {
    bool topFlat = false, bottomFlat = false;
    if (t == WCRCornerTargetTopbar)  topFlat = Cfg().topbarCornerTopFlatEnabled;
    if (t == WCRCornerTargetToolbar) bottomFlat = Cfg().toolbarCornerBottomFlatEnabled;
    applyCorners(layer, t, !topFlat, !topFlat, !bottomFlat, !bottomFlat);
}

#pragma mark - ==================== ObjC 桥接层 ====================

static const void *kWCROriginalCornerKey = &kWCROriginalCornerKey;

@interface WCRCornerHookCenter ()
+ (WCRCornerTarget)targetForView:(UIView *)view matched:(BOOL *)matched;
+ (void)wcr_apply:(UIView *)view target:(WCRCornerTarget)target;
+ (void)applyRecursively:(UIView *)root;
@end

/// 类名->目标 的缓存,避免每次 layoutSubviews 都做字符串匹配
static const void *kWCRTargetCacheKey = &kWCRTargetCacheKey;

@implementation WCRCornerHookCenter

/// 类名特征 -> 圆角目标(微信类名会随版本变,这里做多关键词匹配)
+ (WCRCornerTarget)targetForView:(UIView *)view matched:(BOOL *)matched {
    NSString *cls = NSStringFromClass([view class]);
    NSString *sup = NSStringFromClass([view.superview class]);
    NSString *probe = [NSString stringWithFormat:@"%@|%@", cls, sup];

    struct Rule { const char *needle; WCRCornerTarget target; };
    static const Rule rules[] = {
        {"SearchBar",        WCRCornerTargetSearchBar},
        {"InputView",        WCRCornerTargetInputBar},
        {"ChatInput",        WCRCornerTargetInputBar},
        {"Keyboard",         WCRCornerTargetKeyboard},
        {"NavigationBar",    WCRCornerTargetTopbar},
        {"NavBar",           WCRCornerTargetTopbar},
        {"TabBar",           WCRCornerTargetToolbar},
        {"Emoticon",         WCRCornerTargetEmoji},
        {"Emoji",            WCRCornerTargetEmoji},
        {"ImageBubble",      WCRCornerTargetChatImage},
        {"ChatImageView",    WCRCornerTargetChatImage},
        {"BubbleView",       WCRCornerTargetChatBubble},
        {"ChatTime",         WCRCornerTargetChatTime},
        {"ReferView",        WCRCornerTargetMsgRefer},
        {"PatMessage",       WCRCornerTargetSystemMessage},
        {"SystemNotice",     WCRCornerTargetSystemNotice},
        {"VoiceTranscribe",  WCRCornerTargetVoiceTranslate},
        {"MomentCell",       WCRCornerTargetMoment},
        {"Finder",           WCRCornerTargetFinder},
        {"ServiceApp",       WCRCornerTargetService},
        {"PlusMenu",         WCRCornerTargetPlusMenu},
        {"SendButton",       WCRCornerTargetSendButton},
        {"AlertView",        WCRCornerTargetSystemPopup},
        {"Toast",            WCRCornerTargetSystemPopup},
        {"SwipeMenu",        WCRCornerTargetSwipeMenu},
    };

    if (!matched) { /* 调用方不需要匹配结果 */ }
    NSNumber *cached = objc_getAssociatedObject(view, kWCRTargetCacheKey);
    if (cached) {
        if (matched) *matched = YES;
        return (WCRCornerTarget)cached.integerValue;
    }

    const char *c = probe.UTF8String;
    for (const auto &r : rules) {
        if (strstr(c, r.needle) != NULL) {
            objc_setAssociatedObject(view, kWCRTargetCacheKey, @(r.target), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (matched) *matched = YES;
            return r.target;
        }
    }
    if (matched) *matched = NO;
    return WCRCornerTargetSearchBar;
}

+ (void)applyToView:(UIView *)view target:(WCRCornerTarget)target {
    if (!view || !view.layer) return;
    BOOL on = NO;
    switch (target) {
        case WCRCornerTargetSearchBar:      on = Cfg().searchCornerEnabled; break;
        case WCRCornerTargetInputBar:       on = Cfg().inputCornerEnabled; break;
        case WCRCornerTargetKeyboard:       on = Cfg().imeKeyboardCornerEnabled; break;
        case WCRCornerTargetTopbar:         on = Cfg().topbarCornerEnabled; break;
        case WCRCornerTargetToolbar:        on = Cfg().toolbarCornerEnabled; break;
        case WCRCornerTargetEmoji:          on = Cfg().emojiCornerEnabled; break;
        case WCRCornerTargetChatImage:      on = Cfg().chatImageCornerEnabled; break;
        case WCRCornerTargetChatBubble:     on = Cfg().chatBubbleCornerEnabled; break;
        case WCRCornerTargetChatTime:       on = Cfg().chatTimeRoundCornerEnabled; break;
        case WCRCornerTargetMsgRefer:       on = Cfg().msgReferCornerEnabled; break;
        case WCRCornerTargetSystemMessage:  on = Cfg().systemMessageCornerEnabled; break;
        case WCRCornerTargetSystemNotice:   on = Cfg().systemNoticeCornerEnabled; break;
        case WCRCornerTargetVoiceTranslate: on = Cfg().voiceTranslateCornerEnabled; break;
        case WCRCornerTargetMoment:         on = Cfg().momentCornerEnabled; break;
        case WCRCornerTargetFinder:         on = Cfg().finderCornerEnabled; break;
        case WCRCornerTargetService:        on = Cfg().serviceCornerEnabled; break;
        case WCRCornerTargetPlusMenu:       on = Cfg().plusMenuCornerEnabled; break;
        case WCRCornerTargetSendButton:     on = Cfg().sendPublishButtonCornerEnabled; break;
        case WCRCornerTargetSystemPopup:    on = Cfg().systemPopupCornerEnabled; break;
        case WCRCornerTargetSwipeMenu:      on = Cfg().mainFrameSwipeMenuCornerEnabled; break;
    }
    if (!on) return;
    [self wcr_apply:view target:target];
}

+ (void)wcr_apply:(UIView *)view target:(WCRCornerTarget)target {
    WCRCornerPainter::apply(view.layer, target);
    // 输入框透明
    if (target == WCRCornerTargetInputBar && Cfg().inputBoxTransparencyEnabled) {
        view.backgroundColor = [view.backgroundColor colorWithAlphaComponent:Cfg().inputBoxTransparencyAlpha / 100.0];
    }
    // 气泡去箭头
    if (target == WCRCornerTargetChatBubble && Cfg().chatBubbleArrowHidden) {
        for (UIView *sub in view.subviews) {
            NSString *n = NSStringFromClass([sub class]);
            if ([n containsString:@"Arrow"] || [n containsString:@"Tail"]) sub.hidden = YES;
        }
    }
}

#pragma mark 递归套用到整棵视图树

+ (void)applyRecursively:(UIView *)root {
    if (!root) return;
    BOOL matched = NO;
    WCRCornerTarget t = [self targetForView:root matched:&matched];
    if (matched) [self applyToView:root target:t];
    for (UIView *sub in root.subviews) [self applyRecursively:sub];
}

#pragma mark 安装 hook

static IMP gOrigLayoutSubviews = NULL;

static void wcr_layoutSubviews(UIView *self, SEL _cmd) {
    ((void (*)(id, SEL))gOrigLayoutSubviews)(self, _cmd);
    BOOL matched = NO;
    WCRCornerTarget t = [WCRCornerHookCenter targetForView:self matched:&matched];
    if (matched) [WCRCornerHookCenter applyToView:self target:t];
}

+ (void)install {
    Class UIViewClass = [UIView class];
    Method m = class_getInstanceMethod(UIViewClass, @selector(layoutSubviews));
    if (m) {
        gOrigLayoutSubviews = method_getImplementation(m);
        method_setImplementation(m, (IMP)wcr_layoutSubviews);
    }

    // 配置变化后刷新所有窗口
    [[NSNotificationCenter defaultCenter] addObserverForName:WCRCornerSettingsChangedNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            [WCRCornerHookCenter applyRecursively:w];
        }
    }];
}

@end
