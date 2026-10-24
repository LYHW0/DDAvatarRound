//
//  LYHWRadius.m  —  圆角 / 边框 / 祖先类判定 原语
//

#import "LYHWRadius.h"
#import <QuartzCore/QuartzCore.h>

void LYHWApplyRadius(UIView *view, CGFloat radius) {
    if (!view) return;
    CALayer *l = view.layer;
    if (fabs(l.cornerRadius - radius) > 0.01) l.cornerRadius = radius;
    BOOL want = (radius > 0.01);
    if (l.masksToBounds != want) l.masksToBounds = want;
    if (@available(iOS 13.0, *)) l.cornerCurve = kCACornerCurveContinuous;
}

void LYHWApplyRadiusAndBorder(UIView *view, CGFloat radius,
                              CGFloat borderWidth, UIColor *borderColor) {
    if (!view) return;
    LYHWApplyRadius(view, radius);
    CALayer *l = view.layer;
    if (borderWidth > 0.01) {
        l.borderWidth = borderWidth;
        l.borderColor = (borderColor ?: [UIColor clearColor]).CGColor;
        l.masksToBounds = YES;
    } else if (l.borderWidth > 0.01) {
        l.borderWidth = 0;
        l.borderColor = NULL;
    }
}

void LYHWApplyRadiusCorners(UIView *view, CGFloat radius, CACornerMask corners) {
    if (!view) return;
    CALayer *l = view.layer;
    if (fabs(l.cornerRadius - radius) > 0.01) l.cornerRadius = radius;
    l.maskedCorners = corners;
    l.masksToBounds = (radius > 0.01);
    if (@available(iOS 13.0, *)) l.cornerCurve = kCACornerCurveContinuous;
}

BOOL LYHWIsKindOfClassNamed(id obj, NSString *className) {
    if (!obj || className.length == 0) return NO;
    Class c = NSClassFromString(className);
    return c != Nil && [obj isKindOfClass:c];
}

BOOL LYHWViewInsideClass(UIView *view, NSString *className) {
    Class c = NSClassFromString(className);
    if (!c) return NO;
    for (UIView *v = view; v; v = v.superview) {
        if ([v isKindOfClass:c]) return YES;
    }
    return NO;
}

BOOL LYHWViewInsideAnyClass(UIView *view, NSArray<NSString *> *classNames) {
    if (!view || classNames.count == 0) return NO;
    NSMutableArray *classes = [NSMutableArray arrayWithCapacity:classNames.count];
    for (NSString *n in classNames) {
        Class c = NSClassFromString(n);
        if (c) [classes addObject:c];
    }
    if (classes.count == 0) return NO;
    for (UIView *v = view; v; v = v.superview) {
        for (Class c in classes) if ([v isKindOfClass:c]) return YES;
    }
    return NO;
}

void LYHWRemoveVisualEffectViews(UIView *root, int depth) {
    if (!root || depth > 6) return;
    for (UIView *sv in [root.subviews copy]) {
        if ([sv isKindOfClass:[UIVisualEffectView class]]) {
            sv.hidden = YES;
            sv.alpha = 0;
            continue;
        }
        LYHWRemoveVisualEffectViews(sv, depth + 1);
    }
}

void LYHWRemoveBackgroundImageViews(UIView *root, CGFloat minWidthRatio, int depth) {
    if (!root || depth > 6) return;
    CGFloat W = root.bounds.size.width;
    if (W < 1) return;
    for (UIView *sv in [root.subviews copy]) {
        if ([sv isKindOfClass:[UIImageView class]] &&
            sv.bounds.size.width >= W * minWidthRatio &&
            sv.bounds.size.height > 10) {
            sv.hidden = YES;
            continue;
        }
        LYHWRemoveBackgroundImageViews(sv, minWidthRatio, depth + 1);
    }
}
