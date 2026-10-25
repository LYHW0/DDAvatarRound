#import "L62Strings.h"
//
//  LYHWSpeedAlert.m
//

#import "LYHWSpeedAlert.h"
#import "LYHWSpeedConfig.h"
#import "LYHWSpeedHook.h"

// 想把弹窗换回微信原生风格（黄白助手那种）时，把下面改成 1，
// 并且确保宿主进程里确实有 WCUIAlertView（微信内部类）。
#ifndef HB_USE_WECHAT_ALERT_STYLE
#define HB_USE_WECHAT_ALERT_STYLE 0
#endif

@implementation LYHWSpeedAlert

#pragma mark - 取当前顶层控制器

+ (UIViewController *)topViewController
{
    UIWindow *keyWin = nil;
    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        if (w.isKeyWindow) { keyWin = w; break; }
    }
    if (!keyWin) keyWin = [[[UIApplication sharedApplication] windows] firstObject];

    UIViewController *vc = keyWin.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

#pragma mark - 输入框

+ (void)showEditorFrom:(UIViewController *)host
                  item:(LYHWSpeedMenuItem *)item
             onChanged:(LYHWSpeedChangedBlock)onChanged
{
    if (!host) host = [self topViewController];
    if (!host) return;

#if HB_USE_WECHAT_ALERT_STYLE
    // ── 与原始二进制完全一致的调用序列（宿主需存在 WCUIAlertView）──
    Class ab = NSClassFromString(L62Decode(168));
    if (ab && [ab instancesRespondToSelector:@selector(initWithTitle:message:)]) {
        id alert = [[ab alloc] initWithTitle:item.alertTitle message:item.alertMessage];
        if ([alert respondsToSelector:@selector(addBtnTitle:target:sel:)]) {
            SEL cancelSel = NULL;
            [alert addBtnTitle:item.cancelButton target:host sel:cancelSel];
            [alert addBtnTitle:item.confirmButton target:host sel:NSSelectorFromString(item.confirmSelectorName)];
        }
        if ([alert respondsToSelector:@selector(showTextFieldWithMaxLen:)]) {
            [alert showTextFieldWithMaxLen:item.textMaxLength];
        }
        if ([alert respondsToSelector:@selector(setTextFieldDefaultText:)]) {
            [alert setTextFieldDefaultText:LYHWSpeedDisplayText()];
        }
        if ([alert respondsToSelector:@selector(show)]) {
            [alert show];
            return;
        }
    }
#endif

    // ── 通用实现（任何工程可用）──
    NSString *cur = LYHWSpeedDisplayText();

    UIAlertController *ac =
        [UIAlertController alertControllerWithTitle:item.alertTitle
                                            message:item.alertMessage
                                     preferredStyle:UIAlertControllerStyleAlert];

    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text            = cur;
        tf.keyboardType    = UIKeyboardTypeDecimalPad;
        tf.textAlignment   = NSTextAlignmentCenter;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    __weak UIAlertController *weakAC = ac;
    [ac addAction:[UIAlertAction actionWithTitle:item.cancelButton
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];

    [ac addAction:[UIAlertAction actionWithTitle:item.confirmButton
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *a) {
        NSString *text = weakAC.textFields.firstObject.text ?: @"";
        if (text.length > item.textMaxLength) {
            text = [text substringToIndex:item.textMaxLength];
        }
        // 原实现：v = [text floatValue]; [LYHWConfigUtil setEditUiWindowsSpeed:v];
        float v = [text floatValue];
        LYHWSetUISpeed(v);

        if (onChanged) onChanged(v);
        [self showRestartPromptFrom:host item:item];
    }]];

    [host presentViewController:ac animated:YES completion:nil];
}

#pragma mark - 重启提示

+ (void)showRestartPromptFrom:(UIViewController *)host item:(LYHWSpeedMenuItem *)item
{
    if (!host) host = [self topViewController];
    if (!host) return;

    UIAlertController *ac =
        [UIAlertController alertControllerWithTitle:item.restartTitle
                                            message:item.restartMessage
                                     preferredStyle:UIAlertControllerStyleAlert];

    [ac addAction:[UIAlertAction actionWithTitle:item.restartNowButton
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction *a) {
        LYHWReloadHostApplication();
    }]];

    [ac addAction:[UIAlertAction actionWithTitle:item.restartLaterButton
                                          style:UIAlertActionStyleDefault
                                        handler:nil]];

    [host presentViewController:ac animated:YES completion:nil];
}

@end
