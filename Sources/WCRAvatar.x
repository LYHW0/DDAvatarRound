//
//  WCRAvatar.x  —  模块五：头像框圆角 / 头像美化
//
//  原版 hook 点（二进制初始化函数还原）：
//    MMHeadImageView(layoutSubviews / setFrame: / setBounds: / setHeadImageViewCornerRadius:
//                    / updateUsrName:withHeadImgUrl: / setHeadImageByName: / updateHeadImage:
//                    / ImageDidLoad:Url: / resetToDefaultImage / checkAndUpdateImage)
//    MMUILongPressImageView(setImage:)  FakeHeadImageView  WCFinderHeadImageView
//
//  效果：头像圆角按"百分比"控制（100% = 正圆，与原版默认值 100 一致），
//  可单独配描边颜色/粗细、头像缩放（留白），聊天页与列表页可分别设置。
//

#import "WCRConfig.h"
#import "WCRCommon.h"

static inline WCRConfig *WCRACfg(void) { return [WCRConfig shared]; }

/// 算出某个头像视图该用的圆角
static CGFloat WCRAvatarRadiusForView(UIView *view, BOOL chatPage) {
    WCRConfig *cfg = WCRACfg();
    if (!view) return 0;

    CGSize size = view.bounds.size;
    CGFloat minSide = MIN(size.width, size.height);
    if (minSide <= 1) return 0;

    if (chatPage && cfg.avatarCornerChatPageEnabled) {
        // 聊天页支持固定值（pt），超过半径就按正圆处理
        CGFloat r = cfg.avatarCornerChatPageRadius;
        return MIN(r, minSide / 2.0);
    }

    // 其它位置按百分比：100% → 正圆
    CGFloat percent = cfg.avatarCornerRadius / 100.0;
    percent = MAX(0.0, MIN(1.0, percent));
    return (minSide / 2.0) * percent;
}

/// 找到头像视图内部真正的图片视图
static UIImageView *WCRAvatarInnerImageView(UIView *view) {
    if (!view) return nil;
    if ([view isKindOfClass:[UIImageView class]]) return (UIImageView *)view;

    // MMHeadImageView 暴露了 headImageView 属性
    @try {
        if ([view respondsToSelector:NSSelectorFromString(@"headImageView")]) {
            id inner = [view valueForKey:@"headImageView"];
            if ([inner isKindOfClass:[UIImageView class]]) return (UIImageView *)inner;
        }
    } @catch (NSException *e) { (void)e; }

    return (UIImageView *)WCRFirstSubviewOfClass(view, [UIImageView class]);
}

/// 统一套用头像样式
static void WCRApplyAvatarStyle(UIView *view, BOOL chatPage) {
    if (!view) return;
    WCRConfig *cfg = WCRACfg();
    if (!cfg.avatarCornerEnabled) return;

    CGFloat radius = WCRAvatarRadiusForView(view, chatPage);
    BOOL borderOn = chatPage ? cfg.avatarCornerChatPageBorderEnabled : cfg.avatarCornerBorderEnabled;
    CGFloat borderSize = chatPage ? cfg.avatarCornerChatPageBorderSize : cfg.avatarCornerBorderSize;
    UIColor *borderColor = chatPage
        ? WCRColorForAppearance(cfg.avatarCornerChatPageBorderColorLight, cfg.avatarCornerChatPageBorderColorDark)
        : WCRColorForAppearance(cfg.avatarCornerBorderColorLight, cfg.avatarCornerBorderColorDark);

    UIImageView *inner = WCRAvatarInnerImageView(view);
    if (inner) {
        WCRApplyCornerToImageView(inner, radius, borderOn ? borderSize : 0, borderColor);

        // 头像缩放：向内收一点，视觉上更"圆润"
        if (cfg.avatarCornerScaleEnabled && cfg.avatarCornerScale > 0.1f && cfg.avatarCornerScale < 1.0f) {
            CGFloat s = cfg.avatarCornerScale;
            CGSize target = CGSizeMake(inner.bounds.size.width * s, inner.bounds.size.height * s);
            if (target.width > 1 && !CGSizeEqualToSize(inner.bounds.size, target)) {
                inner.bounds = (CGRect){CGPointZero, target};
            }
        }
    }

    // 外层容器也裁一下，避免圆角外露出方角
    if (radius > 0.5) {
        view.layer.masksToBounds = YES;
        view.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    if (borderOn && borderSize > 0.01) {
        view.layer.borderWidth = borderSize;
        view.layer.borderColor = borderColor.CGColor;
    }
}

%hook MMHeadImageView

- (void)layoutSubviews {
    %orig;
    WCRApplyAvatarStyle((UIView *)self, NO);
}

- (void)setFrame:(CGRect)frame {
    %orig;
    WCRApplyAvatarStyle((UIView *)self, NO);
}

- (void)setBounds:(CGRect)bounds {
    %orig;
    WCRApplyAvatarStyle((UIView *)self, NO);
}

- (void)setHeadImageViewCornerRadius:(double)radius {
    %orig;
    WCRApplyAvatarStyle((UIView *)self, NO);
}

%end

%hook MMUILongPressImageView

- (void)setImage:(UIImage *)image {
    %orig;
    if (!WCRACfg().avatarCornerEnabled) return;
    WCRApplyAvatarStyle((UIView *)self, NO);
}

%end

%hook FakeHeadImageView

- (void)layoutSubviews {
    %orig;
    WCRApplyAvatarStyle((UIView *)self, NO);
}

%end

%hook WCFinderHeadImageView

- (void)layoutSubviews {
    %orig;
    WCRApplyAvatarStyle((UIView *)self, NO);
}

%end
