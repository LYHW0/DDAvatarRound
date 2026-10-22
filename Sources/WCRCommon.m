//
//  WCRCommon.m
//  LYHW
//

#import "WCRCommon.h"
#import <math.h>

BOOL WCRIsDarkMode(void) {
    if (@available(iOS 13.0, *)) {
        return UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

UIColor *WCRColorFromHex(NSString *hex, UIColor *fallback) {
    if (hex.length == 0) return fallback;

    NSString *s = [hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if ([s hasPrefix:@"0x"] || [s hasPrefix:@"0X"]) s = [s substringFromIndex:2];
    if (s.length != 6 && s.length != 8) return fallback;

    unsigned long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:s];
    if (![scanner scanHexLongLong:&value]) return fallback;

    CGFloat r, g, b, a = 1.0;
    if (s.length == 6) {
        r = ((value >> 16) & 0xFF) / 255.0;
        g = ((value >> 8) & 0xFF) / 255.0;
        b = (value & 0xFF) / 255.0;
    } else {
        r = ((value >> 24) & 0xFF) / 255.0;
        g = ((value >> 16) & 0xFF) / 255.0;
        b = ((value >> 8) & 0xFF) / 255.0;
        a = (value & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

UIColor *WCRColorForAppearance(NSString *lightHex, NSString *darkHex) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            BOOL dark = (trait.userInterfaceStyle == UIUserInterfaceStyleDark);
            return WCRColorFromHex(dark ? darkHex : lightHex, [UIColor clearColor]);
        }];
    }
    return WCRColorFromHex(lightHex, [UIColor clearColor]);
}

NSString *WCRHexFromColor(UIColor *color) {
    if (!color) return @"";
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        return @"";
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)lround(r * 255.0), (int)lround(g * 255.0), (int)lround(b * 255.0)];
}

void WCRApplyCorner(UIView *view,
                    CGFloat radius,
                    CGFloat borderWidth,
                    UIColor *borderColor,
                    BOOL clip) {
    if (!view || ![view isKindOfClass:[UIView class]]) return;

    CALayer *layer = view.layer;
    if (!layer) return;

    if (@available(iOS 13.0, *)) {
        layer.cornerCurve = kCACornerCurveContinuous;
    }
    layer.cornerRadius = MAX(0.0, radius);
    layer.masksToBounds = clip && radius > 0.5;

    if (borderWidth > 0.01 && borderColor) {
        layer.borderWidth = borderWidth;
        layer.borderColor = borderColor.CGColor;
    } else if (borderWidth <= 0.01) {
        layer.borderWidth = 0;
    }
}

void WCRApplyCornerToImageView(UIImageView *imageView, CGFloat radius, CGFloat borderWidth, UIColor *borderColor) {
    if (!imageView) return;
    CALayer *layer = imageView.layer;
    if (@available(iOS 13.0, *)) {
        layer.cornerCurve = kCACornerCurveContinuous;
    }
    layer.cornerRadius = MAX(0.0, radius);
    layer.masksToBounds = (radius > 0.5);
    if (borderWidth > 0.01 && borderColor) {
        layer.borderWidth = borderWidth;
        layer.borderColor = borderColor.CGColor;
    } else {
        layer.borderWidth = 0;
    }
}

void WCRTintLabels(UIView *root, UIColor *color, NSArray<NSString *> *skipClassNames) {
    if (!root || !color) return;
    NSSet *skip = skipClassNames.count ? [NSSet setWithArray:skipClassNames] : nil;

    if ([root isKindOfClass:[UILabel class]] && root != nil) {
        if (!skip || ![skip containsObject:NSStringFromClass([root class])]) {
            ((UILabel *)root).textColor = color;
        }
    }
    for (UIView *sub in root.subviews) {
        WCRTintLabels(sub, color, skipClassNames);
    }
}

UIView *WCRFirstSubviewOfClass(UIView *root, Class cls) {
    if (!root || !cls) return nil;
    if ([root isKindOfClass:cls]) return root;
    for (UIView *sub in root.subviews) {
        UIView *hit = WCRFirstSubviewOfClass(sub, cls);
        if (hit) return hit;
    }
    return nil;
}

CGRect WCRSafeBounds(UIView *view) {
    if (!view) return CGRectZero;
    return UIEdgeInsetsInsetRect(view.bounds, view.safeAreaInsets);
}
