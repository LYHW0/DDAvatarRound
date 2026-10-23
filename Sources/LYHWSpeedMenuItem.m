//
//  LYHWSpeedMenuItem.m
//

#import "LYHWSpeedMenuItem.h"

@implementation LYHWSpeedMenuItem

+ (instancetype)uiSpeedItem
{
    LYHWSpeedMenuItem *it = [LYHWSpeedMenuItem new];

    it.title       = @"自定义界面速度:";
    it.valueFormat = @"%.1f";
    it.footer      = @"修改UI速度，默认是1.0";

    it.alertTitle   = @"懒小王";
    it.alertMessage = @"修改UI速度，默认是1.0\n参考最佳值是：1.1或1.3\n建议设置为2就知道该功能什么用途了";
    it.confirmButton = @"确定";
    it.cancelButton  = @"取消";
    it.textMaxLength = 256;

    it.restartTitle       = @"懒小王";
    it.restartMessage     = @"设置成功，需要重启生效";
    it.restartNowButton   = @"立即重启";
    it.restartLaterButton = @"稍后重启";

    it.tapSelectorName     = @"hb_speedCellTapped";
    it.confirmSelectorName = @"hb_speedAlertConfirm:";

    return it;
}

@end
