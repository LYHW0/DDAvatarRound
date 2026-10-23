//
//  LYHWSpeedCellFactory.h
//  自定义界面速度 —— 行（cell）生成
//
//  原实现（-[TheSpecialController setEditUiWindowsSpeed] @0x9C20D0）：
//    return [WCTableViewCellManager
//              normalCellForSel:@selector(setEditUiWindowsSpeeds)   // 点击回调
//                       target:self
//                        title:@"自定义界面速度:"
//                   rightValue:[NSString stringWithFormat:@"%.1f", cfg]
//           canRightValueCopy:NO];
//
//  本文件提供两条路：
//    1) 宿主里有 WCTableViewCellManager（微信 / 同类宿主）→ 直接生成原生风格行
//    2) 普通工程 → 返回 UITableViewCell(style = Value1)
//

#import <UIKit/UIKit.h>
#import "LYHWSpeedMenuItem.h"

@interface LYHWSpeedCellFactory : NSObject

/// 生成一行。target/action 为点击回调（原插件用的是 target + selector）。
+ (UITableViewCell *)cellForItem:(LYHWSpeedMenuItem *)item
                          target:(id)target
                          action:(SEL)action;

/// 分组 footer 文案（原插件每行下面那行灰字）
+ (NSString *)footerForItem:(LYHWSpeedMenuItem *)item;

@end
