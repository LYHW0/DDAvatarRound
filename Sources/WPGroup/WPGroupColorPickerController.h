//
//  WPGroupColorPickerController.h
//  颜色选择器
//
//  逆向自 WCPulseColorPickerController 的分组取色用法：
//  背景 / 指示器 / 选中文字 / 未选文字 四类颜色共用一套取色面板
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPGroupColorPickerController : UIViewController

- (instancetype)initWithTitle:(NSString *)title hex:(nullable NSString *)hex;

/// 选好颜色回调（十六进制，如 #07C160）
@property (nonatomic, copy, nullable) void (^completion)(NSString *hex);

@end

NS_ASSUME_NONNULL_END
