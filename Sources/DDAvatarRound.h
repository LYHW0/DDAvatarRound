#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

// ========== 微信内部类声明 ==========
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)rightValue;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
- (void)addCell:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

// ========== 原有功能类声明 ==========
@interface MMHeadImageView : UIView
@property(retain, nonatomic) UIView *headImageView;
- (id)initWithUsrName:(id)arg1 headImgUrl:(id)arg2 bAutoUpdate:(BOOL)arg3 bRoundCorner:(BOOL)arg4;
@end

@interface FakeHeadImageView : UIView
@property(readonly, nonatomic) BOOL m_bRoundedCorner;
- (id)initWithRoundCorner:(BOOL)arg1;
@end

// ========== 配置常量 ==========
static NSString * const kUserDefaultsSuiteName = @"com.cyansmoke.wechattweak";
static NSString * const kRoundAvatarKey = @"roundAvatar";
static NSString * const kAvatarCornerRadiusKey = @"avatarCornerRadius";

static BOOL isRoundAvatarEnabled = NO;
static float customCornerRadius = 1.0f;

// ========== 设置界面声明 ==========
@interface DDAvatarCornerSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end
