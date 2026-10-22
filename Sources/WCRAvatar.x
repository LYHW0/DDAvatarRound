//
//  WCRAvatar.x — 头像圆角（采用 DD头像圆角 的实现）
//  radiusRatio = avatarCornerRadius / 100，1.0 = 正圆
//
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "WCRConfig.h"

@interface MMHeadImageView : UIView
@property(retain, nonatomic) UIView *headImageView;
- (id)initWithUsrName:(id)arg1 headImgUrl:(id)arg2 bAutoUpdate:(BOOL)arg3 bRoundCorner:(BOOL)arg4;
@end

@interface FakeHeadImageView : UIView
- (id)initWithRoundCorner:(BOOL)arg1;
@end

static inline BOOL WCRAvOn(void) { return [WCRConfig shared].avatarCornerEnabled; }
static inline CGFloat WCRAvRatio(void) {
    double r = [WCRConfig shared].avatarCornerRadius / 100.0;
    if (r <= 0) r = 1.0;
    return (CGFloat)MIN(1.0, MAX(0.1, r));
}
static inline CGFloat WCRAvRadius(CGFloat w, CGFloat h) {
    CGFloat ratio = WCRAvRatio();
    return ratio >= 0.99f ? MIN(w, h) / 2.0f : MIN(w, h) / 2.0f * ratio;
}

%hook MMHeadImageView
- (id)initWithUsrName:(id)a headImgUrl:(id)b bAutoUpdate:(BOOL)c bRoundCorner:(BOOL)d {
    return %orig(a, b, c, WCRAvOn() || d);
}
- (void)layoutSubviews {
    %orig;
    if (!WCRAvOn()) return;
    CGFloat w = self.frame.size.width, h = self.frame.size.height;
    if (w > 0 && h > 0) {
        self.layer.cornerRadius = WCRAvRadius(w, h);
        self.layer.masksToBounds = YES;
        if (self.headImageView) {
            CGFloat iw = self.headImageView.frame.size.width, ih = self.headImageView.frame.size.height;
            if (iw > 0 && ih > 0) {
                self.headImageView.layer.cornerRadius = WCRAvRadius(iw, ih);
                self.headImageView.layer.masksToBounds = YES;
            }
        }
    }
}
%end

%hook FakeHeadImageView
- (id)initWithRoundCorner:(BOOL)arg1 {
    return %orig(WCRAvOn() || arg1);
}
- (void)layoutSubviews {
    %orig;
    if (!WCRAvOn()) return;
    CGFloat w = self.frame.size.width, h = self.frame.size.height;
    if (w <= 0 || h <= 0) return;
    self.layer.cornerRadius = WCRAvRadius(w, h);
    self.layer.masksToBounds = YES;
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);
    for (unsigned int i = 0; i < count; i++) {
        NSString *n = [NSString stringWithUTF8String:ivar_getName(ivars[i])];
        if ([n hasPrefix:@"m_"] && [n containsString:@"ImageView"]) {
            id v = object_getIvar(self, ivars[i]);
            if ([v isKindOfClass:[UIImageView class]]) {
                UIImageView *iv = v;
                if (iv.frame.size.width > 0 && iv.frame.size.height > 0) {
                    iv.layer.cornerRadius = WCRAvRadius(iv.frame.size.width, iv.frame.size.height);
                    iv.layer.masksToBounds = YES;
                }
            }
        }
    }
    free(ivars);
}
%end
