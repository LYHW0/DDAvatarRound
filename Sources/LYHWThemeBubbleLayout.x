#import <UIKit/UIKit.h>
#import <objc/runtime.h>
// YYAsyncImageView may render via layer.contentsCenter instead of UIImage's
// capInsets. Apply the same one-pixel center to the actual marked image only.
static void LYHWThemeBubbleLayer(UIImageView *view) {
    UIImage *image = view.image;
    NSValue *caps = objc_getAssociatedObject(image, NSSelectorFromString(@"lyhwThemeTextBubbleCaps"));
    static char savedCenter;
    NSValue *original = objc_getAssociatedObject(view, &savedCenter);
    if (!caps || !image.CGImage) {
        if (original) {
            view.layer.contentsCenter = original.CGRectValue;
            objc_setAssociatedObject(view, &savedCenter, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    BOOL textBubble = NO;
    for (UIView *p=view.superview; p; p=p.superview) {
        if ([NSStringFromClass(p.class) isEqualToString:@"TextMessageCellView"]) { textBubble=YES; break; }
        if ([p isKindOfClass:UITableViewCell.class]) break;
    }
    if (!textBubble) return;
    if (!original) objc_setAssociatedObject(view, &savedCenter, [NSValue valueWithCGRect:view.layer.contentsCenter], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGFloat width = CGImageGetWidth(image.CGImage), height = CGImageGetHeight(image.CGImage);
    CGRect center = CGRectMake(floor((width-1)/2)/width, floor((height-1)/2)/height, 1/width, 1/height);
    if (!CGRectEqualToRect(view.layer.contentsCenter,center)) view.layer.contentsCenter=center;
}
%hook YYAsyncImageView
- (void)layoutSubviews {
    %orig;
    LYHWThemeBubbleLayer((UIImageView *)self);
}
- (void)setImage:(UIImage *)image {
    %orig;
    LYHWThemeBubbleLayer((UIImageView *)self);
}
%end
