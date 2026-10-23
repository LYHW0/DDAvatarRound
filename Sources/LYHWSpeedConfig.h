//
//  LYHWSpeedConfig.h
//  自定义界面速度 —— 配置层
//
//  逆向来源：LYHWWechatHelper.dylib
//  原实现：LYHWConfigUtil +editUiWindowsSpeed / +setEditUiWindowsSpeed:
//  默认值：1.0（原插件提示文案「修改UI速度，默认是1.0」）
//

#import <Foundation/Foundation.h>

/// 原插件使用的配置键名（与访问器同名）
extern NSString * const LYHWSpeedDefaultsKey;   // @"editUiWindowsSpeed"

/// 默认值 1.0
extern const float LYHWSpeedDefaultValue;

/// 允许的取值区间（仅用于输入校验提示，原插件不做强制夹取）
extern const float LYHWSpeedMinValue;           // 0.0
extern const float LYHWSpeedMaxValue;           // 2.0

/// 读 / 写。key 与 LYHWConfigUtil.editUiWindowsSpeed 一致，
/// 若宿主工程已有同名配置可直接对接，不需要改这里。
float LYHWGetUISpeed(void);
void  LYHWSetUISpeed(float speed);

/// 是否启用（speed != 1.0 时才需要动 layer.speed）
BOOL  LYHWSpeedNeedsApply(void);

/// 显示用文本：%.1f —— 与原插件右侧值完全一致
NSString *LYHWSpeedDisplayText(void);
