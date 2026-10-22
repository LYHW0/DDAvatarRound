//
//  HBSpeedMenuItem.h
//  自定义界面速度 —— 菜单项数据表（与原插件二进制里的文案逐字对齐）
//

#import <Foundation/Foundation.h>

@interface HBSpeedMenuItem : NSObject

/// 行标题（原二进制：自定义界面速度:）
@property (nonatomic, copy) NSString *title;

/// 右侧值格式（原二进制：%.1f）
@property (nonatomic, copy) NSString *valueFormat;

/// 说明文字 / 分组 footer（原二进制：修改UI速度，默认是1.0）
@property (nonatomic, copy) NSString *footer;

/// 输入弹窗
@property (nonatomic, copy) NSString *alertTitle;        // 黄白助手
@property (nonatomic, copy) NSString *alertMessage;      // 三行提示
@property (nonatomic, copy) NSString *confirmButton;     // 确定
@property (nonatomic, copy) NSString *cancelButton;      // 取消
@property (nonatomic, assign) NSUInteger textMaxLength;  // 256

/// 设置成功后的重启弹窗
@property (nonatomic, copy) NSString *restartTitle;      // 黄白助手
@property (nonatomic, copy) NSString *restartMessage;    // 设置成功，需要重启生效
@property (nonatomic, copy) NSString *restartNowButton;  // 立即重启
@property (nonatomic, copy) NSString *restartLaterButton;// 稍后重启

/// 控制器上的回调选择器名（供 WeChat 原生 cell / WCUIAlertView 使用）
@property (nonatomic, copy) NSString *tapSelectorName;    // hb_speedCellTapped
@property (nonatomic, copy) NSString *confirmSelectorName;// hb_speedAlertConfirm:

+ (instancetype)uiSpeedItem;

@end
