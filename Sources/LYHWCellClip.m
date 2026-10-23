#import <UIKit/UIKit.h>
#import <objc/runtime.h>
// cell 的 layer.masksToBounds 也可能被单独打开（不经过 setClipsToBounds），
// 这里在 CALayer 层拦截：属于挂了阴影宿主的 cell 的图层，不允许打开 masksToBounds。
static void (*orig_setMasks)(CALayer *, SEL, BOOL);
static void lyhw_setMasks(CALayer *self, SEL _cmd, BOOL m) {
    if (m) {
        id d = self.delegate;
        if ([d isKindOfClass:[UITableViewCell class]] && [(UIView *)d viewWithTag:0x574357]) m = NO;
    }
    orig_setMasks(self, _cmd, m);
}
__attribute__((constructor)) static void LYHWCellClipInit(void) {
    Method mt = class_getInstanceMethod([CALayer class], @selector(setMasksToBounds:));
    if (mt) orig_setMasks = (void *)method_setImplementation(mt, (IMP)lyhw_setMasks);
}
