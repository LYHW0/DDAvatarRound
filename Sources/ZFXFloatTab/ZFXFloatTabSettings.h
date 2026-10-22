//
//  ZFXFloatTabSettings.h
//  悬浮底栏设置页 / 长按调节卡片（菜单与原插件一一对应）
//

#import <UIKit/UIKit.h>
#import "ZFXFloatTabPrefs.h"

typedef NS_ENUM(NSInteger, ZFXRowType) {
    ZFXRowTypeSwitch = 0,
    ZFXRowTypeSegment,
    ZFXRowTypeSlider,
    ZFXRowTypeColor,
};

@interface ZFXSettingRow : NSObject
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *key;
@property (nonatomic, assign) ZFXRowType type;
@property (nonatomic, assign) NSInteger minValue;
@property (nonatomic, assign) NSInteger maxValue;
@property (nonatomic, assign) NSInteger defaultValue;
@property (nonatomic, copy)   NSArray<NSString *> *options;   // 分段控件标题
@end

@interface ZFXSettingSection : NSObject
@property (nonatomic, copy) NSString *header;
@property (nonatomic, copy) NSArray<ZFXSettingRow *> *rows;
@end

/// 完整的设置结构（与原插件一致：功能开关 / 样式与基础 / 颜色配置 / 尺寸与外观）
FOUNDATION_EXPORT NSArray<ZFXSettingSection *> *ZFXBuildSettingSections(void);

#pragma mark - 设置页

@interface ZFXFloatTabSettingsViewController : UITableViewController

/// 供外部设置入口调用
+ (void)presentFromViewController:(UIViewController *)presenter;

@end

#pragma mark - 长按调节卡片

@interface ZFXQuickSettingsCard : UIView

/// 长按底栏弹出：尺寸/透明度/圆角/按钮放大，7 个滑块全在
+ (void)presentInWindow:(UIWindow *)window;

- (void)showInWindow:(UIWindow *)window;
- (void)dismiss;

@end
