//
//  LYHWSpeedSetup.h
//  一行接入：装 Hook + 拿到 UI 行
//
//  用法（在你自己的 dylib 构造函数里）：
//      LYHWSetupUISpeedFeature();
//
//  用法（在设置页里加这一行）：
//      LYHWSpeedMenuItem *item = [LYHWSpeedMenuItem uiSpeedItem];
//      UITableViewCell *cell = [LYHWSpeedCellFactory cellForItem:item target:self action:@selector(hb_speedCellTapped)];
//  再实现：
//      - (void)hb_speedCellTapped {
//          [LYHWSpeedAlert showEditorFrom:self item:item onChanged:^(float v){ [self.tableView reloadData]; }];
//      }
//

#import <Foundation/Foundation.h>

@interface LYHWSpeedSetup : NSObject
@end

/// 安装「界面速度」Hook（幂等，可在 __attribute__((constructor)) 里直接调）
void LYHWSetupUISpeedFeature(void);
