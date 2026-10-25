#import <UIKit/UIKit.h>
#import "LYHWConfig.h"
static BOOL LYHWChatTitleNeedsContrast(UIView *view) {
    if (![LYHWConfig shared].topbarCornerEnabled) return NO;
    BOOL title = [NSStringFromClass(view.class) isEqualToString:@"MMTitleView"];
    UINavigationBar *bar = nil;
    for (UIView *p = view.superview; p; p = p.superview) {
        if ([NSStringFromClass(p.class) isEqualToString:@"MMTitleView"]) title = YES;
        if ([p isKindOfClass:UINavigationBar.class]) { bar = (id)p; break; }
    }
    if (!title || !bar) return NO;
    // Dump confirms MMTitleView/MMUILabel under MMUINavigationBar and a sibling
    // MMMsgContentNavBar in the chat root. Do not depend on responder VC names.
    NSMutableArray *pending = [NSMutableArray array];
    if (bar.superview) [pending addObject:bar.superview];
    for (NSUInteger i=0; i<pending.count && i<256; i++) {
        UIView *v = pending[i];
        NSString *name = NSStringFromClass(v.class);
        if ([name isEqualToString:@"MMMsgContentNavBar"] || [name isEqualToString:@"MMNewMsgContentNavBar"]) return YES;
        if (v == bar || [v isKindOfClass:UITableView.class] || [v isKindOfClass:UICollectionView.class]) continue;
        [pending addObjectsFromArray:v.subviews];
    }
    return NO;
}
static UIColor *LYHWChatTitleColor(UIView *view, UIColor *color) {
    if (!color || !LYHWChatTitleNeedsContrast(view)) return color;
    if (view.window.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) return color;
    CGFloat r,g,b,a;
    if ([[color resolvedColorWithTraitCollection:view.traitCollection] getRed:&r green:&g blue:&b alpha:&a] && a>0.1 && MIN(r,MIN(g,b))>0.85)
        return [UIColor colorWithWhite:0.1 alpha:a];
    return color;
}
static NSAttributedString *LYHWChatTitleAttributed(UIView *view, NSAttributedString *text) {
    if (!text.length || !LYHWChatTitleNeedsContrast(view)) return text;
    NSMutableAttributedString *fixed = [text mutableCopy];
    __block BOOL changed = NO;
    [text enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0,text.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (![value isKindOfClass:UIColor.class]) return;
        UIColor *next = LYHWChatTitleColor(view,value);
        if (![next isEqual:value]) { [fixed addAttribute:NSForegroundColorAttributeName value:next range:range]; changed = YES; }
    }];
    return changed ? fixed : text;
}
%hook MMUILabel
- (void)setTextColor:(UIColor *)color {
    %orig(LYHWChatTitleColor((UIView *)self,color));
}
- (void)setAttributedText:(NSAttributedString *)text {
    %orig(LYHWChatTitleAttributed((UIView *)self,text));
}
%end
%hook MMTitleView
- (void)layoutSubviews {
    %orig;
    NSMutableArray *pending = [NSMutableArray arrayWithArray:((UIView *)self).subviews];
    for (NSUInteger i=0; i<pending.count && i<64; i++) {
        UIView *v = pending[i];
        if ([v isKindOfClass:UILabel.class]) {
            UILabel *label = (id)v;
            UIColor *next = LYHWChatTitleColor(v,label.textColor);
            if (![next isEqual:label.textColor]) label.textColor = next;
            NSAttributedString *text = LYHWChatTitleAttributed(v,label.attributedText);
            if (text != label.attributedText) label.attributedText = text;
        }
        [pending addObjectsFromArray:v.subviews];
    }
}
%end
