//
//  LYHWSpeedAlert.h
//  自定义界面速度 —— 输入弹窗 + 重启提示
//
//  原实现（LYHWWechatHelper.dylib -[TheSpecialController setEditUiWindowsSpeeds] @0x9C2558）：
//    1. cur = [NSString stringWithFormat:@"%.1f", [LYHWConfigUtil editUiWindowsSpeed]]
//    2. alert = [[WCUIAlertView alloc] initWithTitle:@"黄白助手" message:@"修改UI速度…"]
//    3. [alert addBtnTitle:@"取消" target:self sel:NULL]
//    4. [alert addBtnTitle:@"确定" target:self sel:@selector(setEditUiWindowsSpeedsd:)]
//    5. [alert showTextFieldWithMaxLen:256]
//    6. [alert setTextFieldDefaultText:cur]
//    7. [alert show]
//
//  确认回调（-[TheSpecialController setEditUiWindowsSpeedsd:] @0x9C2D50）：
//    v = [text floatValue];  [LYHWConfigUtil setEditUiWindowsSpeed:v];
//    [WCUIAlertView showAlertWithTitle:@"黄白助手" message:@"设置成功，需要重启生效"
//                              btnTitle:@"立即重启" handler:^{ LYHWReloadOpenApp }
//                              btnTitle:@"稍后重启" handler:nil];
//    [self reloadTableData];
//

#import <UIKit/UIKit.h>
#import "LYHWSpeedMenuItem.h"

typedef void (^LYHWSpeedChangedBlock)(float newValue);

@interface LYHWSpeedAlert : NSObject

/// 弹出「自定义界面速度」输入框。
/// @param host       用来承载弹窗的控制器（nil 时自动取 keyWindow 的 rootVC）
/// @param item       文案数据表
/// @param onChanged  用户点了「确定」并写入配置后回调（内部已经处理了重启提示）
+ (void)showEditorFrom:(UIViewController *)host
                  item:(LYHWSpeedMenuItem *)item
             onChanged:(LYHWSpeedChangedBlock)onChanged;

/// 设置成功后的重启提示
+ (void)showRestartPromptFrom:(UIViewController *)host item:(LYHWSpeedMenuItem *)item;

@end
