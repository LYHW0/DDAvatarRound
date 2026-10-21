#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ========== 微信类接口声明 ==========
@interface MMHeadImageView : UIView
@property (nonatomic, strong) UIView *headImageView;
@end

@interface FakeHeadImageView : UIView
@end

@interface WCTableViewSectionManager : NSObject
@end

@interface UITableViewCell (WeChat)
@end

@interface UITableView (WeChat)
@end

// ========== NSUserDefaults 配置键 ==========
static NSString * const kUserDefaultsSuiteName = @"com.cyansmoke.wechattweak";

// 头像圆角配置
static NSString * const kRoundAvatarKey = @"roundAvatar";
static NSString * const kAvatarCornerRadiusKey = @"avatarCornerRadius";

// 列表圆角配置
static NSString * const kListCornerEnabledKey = @"listCornerEnabled";
static NSString * const kListCornerRadiusKey = @"listCornerRadius";
static NSString * const kSectionMarginKey = @"sectionMargin";
static NSString * const kSectionSpacingKey = @"sectionSpacing";

// ========== 全局状态变量 ==========
// 头像圆角状态
static BOOL isRoundAvatarEnabled = NO;
static float customCornerRadius = 1.0f;

// 列表圆角状态
static BOOL isListCornerEnabled = YES;
static float customListCornerRadius = 16.0f;
static CGFloat globalSectionMargin = 15.0f;
static CGFloat globalSectionSpacing = 12.0f;

// ========== 设置界面声明 ==========
@interface DDAvatarCornerSettingsViewController : UIViewController
@end
