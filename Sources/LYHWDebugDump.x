//
//  LYHWDebugDump.x  —  调试：在任意页面摇一摇，把当前视图层级复制到剪贴板
//
//  用途：定位顶栏、资料页等的真实视图结构（类名、frame、背景色、圆角、遮罩）。
//  用法：在出问题的页面摇一摇 → 弹出“已复制” → 粘贴给开发者。
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSString *LYHWDumpTransform(CATransform3D t) {
    return [NSString stringWithFormat:@"[%.4g,%.4g,%.4g,%.4g;%.4g,%.4g,%.4g,%.4g;%.4g,%.4g,%.4g,%.4g;%.4g,%.4g,%.4g,%.4g]",
        t.m11,t.m12,t.m13,t.m14,t.m21,t.m22,t.m23,t.m24,
        t.m31,t.m32,t.m33,t.m34,t.m41,t.m42,t.m43,t.m44];
}

static void LYHWDumpPathElement(void *info, const CGPathElement *element) {
    NSMutableString *out = (__bridge NSMutableString *)info;
    if (out.length > 200000) return;
    NSUInteger n = element->type == kCGPathElementAddCurveToPoint ? 3 :
        element->type == kCGPathElementAddQuadCurveToPoint ? 2 :
        element->type == kCGPathElementCloseSubpath ? 0 : 1;
    [out appendFormat:@" %ld", (long)element->type];
    for (NSUInteger i = 0; i < n; i++)
        [out appendFormat:@"%@", NSStringFromCGPoint(element->points[i])];
}

static void LYHWDumpMask(UIView *v, NSMutableString *out, int depth) {
    CALayer *layer = v.layer;
    [out appendFormat:@"%*slayer opacity=%.3f zPosition=%.3f hidden=%d bounds=%@ transform=%@ sublayerTransform=%@\n",
        depth * 2 + 2, "", layer.opacity, layer.zPosition, layer.hidden,
        NSStringFromCGRect(layer.bounds), LYHWDumpTransform(layer.transform), LYHWDumpTransform(layer.sublayerTransform)];
    CALayer *mask = layer.mask;
    if (!mask) {
        [out appendFormat:@"%*slayerMask=nil\n", depth * 2 + 2, ""];
        return;
    }
    [out appendFormat:@"%*slayerMask name=%@ class=%@ viewBounds=%@ frame=%@ bounds=%@ position=%@ opacity=%.2f hidden=%d transformIdentity=%d",
        depth * 2 + 2, "", mask.name, NSStringFromClass(mask.class),
        NSStringFromCGRect(v.bounds), NSStringFromCGRect(mask.frame), NSStringFromCGRect(mask.bounds),
        NSStringFromCGPoint(mask.position), mask.opacity, mask.hidden, CATransform3DIsIdentity(mask.transform)];
    if ([mask isKindOfClass:CAShapeLayer.class]) {
        CAShapeLayer *shape = (CAShapeLayer *)mask;
        [out appendFormat:@" fillAlpha=%.2f fillRule=%@ pathBBox=%@ path=",
            shape.fillColor ? CGColorGetAlpha(shape.fillColor) : 0, shape.fillRule,
            shape.path ? NSStringFromCGRect(CGPathGetPathBoundingBox(shape.path)) : @"nil"];
        if (shape.path) CGPathApply(shape.path, (__bridge void *)out, LYHWDumpPathElement);
    }
    [out appendString:@"\n"];
}

%config(generator=MobileSubstrate)

static NSString *LYHWDumpColor(UIColor *c) {
    if (!c) return @"nil";
    CGFloat r = 0, g = 0, b = 0, a = 0, w = 0;
    if ([c getRed:&r green:&g blue:&b alpha:&a])
        return [NSString stringWithFormat:@"rgba(%.2f,%.2f,%.2f,%.2f)", r, g, b, a];
    if ([c getWhite:&w alpha:&a])
        return [NSString stringWithFormat:@"white(%.2f,%.2f)", w, a];
    return @"?";
}

static void LYHWDumpWalk(UIView *v, NSMutableString *out, int depth) {
    if (depth > 32 || out.length > 1000000) return;
    [out appendFormat:@"%*s%@ tag=%ld frame=%@ bg=%@ hidden=%d alpha=%.2f clip=%d radius=%.1f mask=%u\n",
        depth * 2, "", NSStringFromClass([v class]), (long)v.tag, NSStringFromCGRect(v.frame),
        LYHWDumpColor(v.backgroundColor), v.hidden, v.alpha, v.clipsToBounds,
        v.layer.cornerRadius, (unsigned int)v.layer.maskedCorners];
    LYHWDumpMask(v, out, depth);
    if ([v isKindOfClass:UIImageView.class]) {
        UIImage *image = ((UIImageView *)v).image;
        [out appendFormat:@"%*simage size=%@ scale=%.2f caps=%@ center=%@ rect=%@\n", depth*2+2, "", NSStringFromCGSize(image.size), image.scale, NSStringFromUIEdgeInsets(image.capInsets), NSStringFromCGRect(v.layer.contentsCenter), NSStringFromCGRect(v.layer.contentsRect)];
    }
    if ([v isKindOfClass:UITableViewCell.class]) {
        UITableViewCell *cell = (UITableViewCell *)v;
        UIView *card = cell.backgroundView;
        if (card && [NSStringFromClass(v.class) isEqualToString:@"NewContactsItemCell"]) {
            [out appendFormat:@"%*scardHost=%@ cellRect=%@ hostRect=%@\n", depth * 2 + 2, "",
                NSStringFromClass(card.superview.class),
                NSStringFromCGRect([cell.contentView convertRect:card.frame fromView:cell]),
                NSStringFromCGRect([cell.contentView convertRect:card.frame fromView:card.superview])];
        }
    }
    for (UIView *sv in v.subviews) LYHWDumpWalk(sv, out, depth + 1);
}

%hook UIWindow
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    if (motion != UIEventSubtypeMotionShake) return;

    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"LYHW view dump (window %.0fx%.0f)\n", self.bounds.size.width, self.bounds.size.height];
    LYHWDumpWalk(self, out, 0);
    [UIPasteboard generalPasteboard].string = out;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"兰因后悟"
                                                                   message:@"界面层级已复制到剪贴板"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *top = self.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (top) [top presentViewController:alert animated:YES completion:nil];
}
%end
