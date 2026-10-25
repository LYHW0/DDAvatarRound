// Top navigation only. No bottom-bar mask, no private view removal.
#import <UIKit/UIKit.h>
#import <objc/message.h>
static void LYHWPlainNavigationButton(UIBarButtonItem *item) {
    if (!item) return;
    // Only suppress the shared visual background. The private hidesBackground
    // flag can change the hosting path on iOS 26; leave it entirely to UIKit.
    SEL getter = NSSelectorFromString(@"hidesSharedBackground");
    SEL setter = NSSelectorFromString(@"setHidesSharedBackground:");
    if ([item respondsToSelector:getter] && [item respondsToSelector:setter] &&
        !((BOOL (*)(id,SEL))objc_msgSend)(item,getter))
        ((void (*)(id,SEL,BOOL))objc_msgSend)(item,setter,YES);
}
static void LYHWPlainNavigationItem(UINavigationItem *item) {
    for (UIBarButtonItem *b in item.leftBarButtonItems) LYHWPlainNavigationButton(b);
    for (UIBarButtonItem *b in item.rightBarButtonItems) LYHWPlainNavigationButton(b);
    LYHWPlainNavigationButton(item.backBarButtonItem);
}
%group LYHWPlainTopNavigation
%hook UINavigationBar
- (void)layoutSubviews {
    for (UINavigationItem *item in self.items) LYHWPlainNavigationItem(item);
    %orig;
}
%end
%hook UINavigationItem
- (void)setLeftBarButtonItems:(NSArray *)items {
    for (UIBarButtonItem *item in items) LYHWPlainNavigationButton(item);
    %orig;
}
- (void)setRightBarButtonItems:(NSArray *)items {
    for (UIBarButtonItem *item in items) LYHWPlainNavigationButton(item);
    %orig;
}
- (void)setLeftBarButtonItem:(UIBarButtonItem *)item {
    LYHWPlainNavigationButton(item);
    %orig;
}
- (void)setRightBarButtonItem:(UIBarButtonItem *)item {
    LYHWPlainNavigationButton(item);
    %orig;
}
- (void)setLeftBarButtonItems:(NSArray *)items animated:(BOOL)animated {
    for (UIBarButtonItem *item in items) LYHWPlainNavigationButton(item);
    %orig;
}
- (void)setRightBarButtonItems:(NSArray *)items animated:(BOOL)animated {
    for (UIBarButtonItem *item in items) LYHWPlainNavigationButton(item);
    %orig;
}
- (void)setLeftBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated {
    LYHWPlainNavigationButton(item);
    %orig;
}
- (void)setRightBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated {
    LYHWPlainNavigationButton(item);
    %orig;
}
- (void)setBackBarButtonItem:(UIBarButtonItem *)item {
    LYHWPlainNavigationButton(item);
    %orig;
}
%end
%end
%ctor {
    if (@available(iOS 26.0, *)) {
        %init(LYHWPlainTopNavigation);
    }
}
