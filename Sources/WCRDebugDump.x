//
//  WCRDebugDump.x  —  调试：在任意页面摇一摇，把当前视图层级复制到剪贴板
//
//  用途：定位顶栏、资料页等的真实视图结构（类名、frame、背景色、圆角、遮罩）。
//  用法：在出问题的页面摇一摇 → 弹出“已复制” → 粘贴给开发者。
//

#import <UIKit/UIKit.h>

%config(generator=MobileSubstrate)

static NSString *WCRDumpColor(UIColor *c) {
    if (!c) return @"nil";
    CGFloat r = 0, g = 0, b = 0, a = 0, w = 0;
    if ([c getRed:&r green:&g blue:&b alpha:&a])
        return [NSString stringWithFormat:@"rgba(%.2f,%.2f,%.2f,%.2f)", r, g, b, a];
    if ([c getWhite:&w alpha:&a])
        return [NSString stringWithFormat:@"white(%.2f,%.2f)", w, a];
    return @"?";
}

static void WCRDumpWalk(UIView *v, NSMutableString *out, int depth) {
    if (depth > 32 || out.length > 200000) return;
    [out appendFormat:@"%*s%@ tag=%ld frame=%@ bg=%@ hidden=%d alpha=%.2f clip=%d radius=%.1f mask=%u\n",
        depth * 2, "", NSStringFromClass([v class]), (long)v.tag, NSStringFromCGRect(v.frame),
        WCRDumpColor(v.backgroundColor), v.hidden, v.alpha, v.clipsToBounds,
        v.layer.cornerRadius, (unsigned int)v.layer.maskedCorners];
    for (UIView *sv in v.subviews) WCRDumpWalk(sv, out, depth + 1);
}

%hook UIWindow
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    if (motion != UIEventSubtypeMotionShake) return;

    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"WCR view dump (window %.0fx%.0f)\n", self.bounds.size.width, self.bounds.size.height];
    WCRDumpWalk(self, out, 0);
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
