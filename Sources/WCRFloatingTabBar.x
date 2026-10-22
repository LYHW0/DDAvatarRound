#import <UIKit/UIKit.h>
#import "WCRConfig.h"

@interface MMTabBar : UIView
- (BOOL)targetIndexIsSelected:(long long)i;
- (id)tabBarItemViewAtIndex:(long long)i;
- (long long)tabBarItemCount;
- (id)backgroundView;
@end

%hook MMTabBar
- (void)layoutSubviews {
    %orig;
    if (![WCRConfig shared].floatingTabBarEnabled) return;
    UIView *bar = (UIView *)self;
    UIView *bg = [(MMTabBar *)self backgroundView];
    if ([bg isKindOfClass:[UIView class]]) bg.hidden = YES;
    CGFloat w = bar.bounds.size.width;
    CGFloat h = MIN(62.0, bar.bounds.size.height);
    CGRect pillF = CGRectMake(14, 0, w - 28, h);
    UIView *pill = [bar viewWithTag:0x574650];
    if (!pill) {
        pill = [UIView new]; pill.tag = 0x574650; pill.userInteractionEnabled = NO;
        [bar insertSubview:pill atIndex:0];
    }
    pill.frame = pillF;
    pill.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return (t.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [UIColor colorWithWhite:0.14 alpha:0.96] : [UIColor colorWithWhite:0.94 alpha:0.96];
    }];
    pill.layer.cornerRadius = h / 2;
    UIView *hi = [bar viewWithTag:0x574651];
    if (!hi) {
        hi = [UIView new]; hi.tag = 0x574651; hi.userInteractionEnabled = NO;
        hi.layer.shadowColor = [UIColor blackColor].CGColor;
        hi.layer.shadowOpacity = 0.10; hi.layer.shadowRadius = 8; hi.layer.shadowOffset = CGSizeMake(0, 3);
        [bar insertSubview:hi aboveSubview:pill];
    }
    hi.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return (t.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [UIColor colorWithWhite:0.25 alpha:1] : [UIColor whiteColor];
    }];
    long long n = [(MMTabBar *)self tabBarItemCount];
    for (long long i = 0; i < n; i++) {
        if (![(MMTabBar *)self targetIndexIsSelected:i]) continue;
        UIView *iv = [(MMTabBar *)self tabBarItemViewAtIndex:i];
        if (![iv isKindOfClass:[UIView class]]) break;
        CGRect f = iv.frame;
        CGFloat hw = MAX(f.size.width + 8, h + 20);
        CGRect r = CGRectMake(CGRectGetMidX(f) - hw / 2, -4, hw, h + 8);
        r.origin.x = MAX(pillF.origin.x - 2, MIN(r.origin.x, CGRectGetMaxX(pillF) + 2 - hw));
        BOOL anim = hi.frame.size.width > 1;
        [UIView animateWithDuration:anim ? 0.25 : 0 animations:^{ hi.frame = r; }];
        hi.layer.cornerRadius = r.size.height / 2;
        break;
    }
}
%end
