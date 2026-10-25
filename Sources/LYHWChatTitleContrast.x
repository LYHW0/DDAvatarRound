#import <UIKit/UIKit.h>
#import "LYHWConfig.h"
static BOOL LYHWChatTitleNeedsContrast(UIView *view) {
    if (![LYHWConfig shared].topbarCornerEnabled) return NO;
    UINavigationBar *bar = nil;
    for (UIView *p = view.superview; p; p = p.superview) {
        if ([p isKindOfClass:UINavigationBar.class]) { bar = (id)p; break; }
    }
    if (!bar) return NO;
    UIViewController *owner = nil;
    for (UIResponder *r = bar; r; r = r.nextResponder)
        if ([r isKindOfClass:UINavigationController.class]) { owner = ((UINavigationController *)r).topViewController; break; }
    NSString *name = NSStringFromClass(owner.class);
    return [name containsString:@"MsgContentViewController"] || [name hasPrefix:@"BaseMsgContent"];
}
static UIColor *LYHWChatTitleColor(UIView *view, UIColor *color) {
    if (!color || !LYHWChatTitleNeedsContrast(view)) return color;
    CGFloat r,g,b,a;
    UIColor *resolved = [color resolvedColorWithTraitCollection:view.traitCollection];
    BOOL dark = view.window.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    if ([resolved getRed:&r green:&g blue:&b alpha:&a] && a > 0.1 && !dark && MIN(r,MIN(g,b)) > 0.85)
        return [UIColor colorWithWhite:0.1 alpha:a];
    return color;
}
%hook UILabel
- (void)setTextColor:(UIColor *)color {
    %orig(LYHWChatTitleColor((UIView *)self, color));
}
%end
%hook UINavigationBar
- (void)layoutSubviews {
    %orig;
    if (!LYHWChatTitleNeedsContrast((UIView *)self.subviews.firstObject)) return;
    NSMutableArray *pending = [NSMutableArray arrayWithArray:self.subviews];
    for (NSUInteger i=0; i<pending.count && i<128; i++) {
        UIView *v = pending[i];
        if ([v isKindOfClass:UILabel.class]) {
            UILabel *label = (id)v;
            UIColor *next = LYHWChatTitleColor(v, label.textColor);
            if (next != label.textColor && ![next isEqual:label.textColor]) label.textColor = next;
        }
        [pending addObjectsFromArray:v.subviews];
    }
}
%end
