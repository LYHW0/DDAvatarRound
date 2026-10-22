//
//  HBSpeedSetup.h
//  一行接入：装 Hook + 拿到 UI 行
//
//  用法（在你自己的 dylib 构造函数里）：
//      HBSetupUISpeedFeature();
//
//  用法（在设置页里加这一行）：
//      HBSpeedMenuItem *item = [HBSpeedMenuItem uiSpeedItem];
//      UITableViewCell *cell = [HBSpeedCellFactory cellForItem:item target:self action:@selector(hb_speedCellTapped)];
//  再实现：
//      - (void)hb_speedCellTapped {
//          [HBSpeedAlert showEditorFrom:self item:item onChanged:^(float v){ [self.tableView reloadData]; }];
//      }
//

#import <Foundation/Foundation.h>

@interface HBSpeedSetup : NSObject
@end

/// 安装「界面速度」Hook（幂等，可在 __attribute__((constructor)) 里直接调）
void HBSetupUISpeedFeature(void);
