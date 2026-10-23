//
//  LYHWRootListController.m
//  LYHW 设置面板
//
//  说明：为了不依赖私有框架头文件（不同 SDK 版本差异大），
//  这里只用运行时声明 + 经典 PSSpecifier API 构建界面，
//  保证在 GitHub Actions 的任意 Theos/Xcode 组合下都能编过。
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

// ---- Preferences 框架最小声明（运行时由系统提供，编译期只做声明）----
@interface PSSpecifier : NSObject
+ (instancetype)preferenceSpecifierNamed:(NSString *)name
                                  target:(id)target
                                     set:(SEL)set
                                     get:(SEL)get
                                  detail:(Class)detail
                                    cell:(long long)cell
                                   edit:(Class)edit;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (void)setTarget:(id)target;
- (void)setButtonAction:(SEL)action;
- (NSString *)name;
@end

@interface PSListController : UIViewController
- (NSArray *)specifiers;
- (void)reloadSpecifiers;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
@end

@interface PSViewController : UIViewController
@end

static NSString * const kWRCPrefsSuite = @"com.lyhw.LYHW";
static NSString * const kWRCPrefsChanged = @"com.lyhw.settings_changed";

typedef NS_ENUM(NSInteger, LYHWCellType) {
    LYHWCellSwitch = 0,
    LYHWCellSlider,
    LYHWCellTextField,
    LYHWCellButton,
};

@interface LYHWRootListController : PSListController
@end

@implementation LYHWRootListController {
    NSMutableArray<PSSpecifier *> *_specs;
}

#pragma mark - 存储

- (NSUserDefaults *)defaults {
    return [[NSUserDefaults alloc] initWithSuiteName:kWRCPrefsSuite];
}

- (id)valueForKey:(NSString *)key fallback:(id)fallback {
    id v = [[self defaults] objectForKey:key];
    return v ?: fallback;
}

- (void)storeValue:(id)value forKey:(NSString *)key {
    NSUserDefaults *d = [self defaults];
    if (value == nil) {
        [d removeObjectForKey:key];
    } else {
        [d setObject:value forKey:key];
    }
    [d synchronize];

    // 跨进程通知微信里的 tweak 立刻刷新
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kWRCPrefsChanged,
                                         NULL, NULL, YES);
}

#pragma mark - 取值/设值（给 PSSpecifier 用）

- (id)getBool:(PSSpecifier *)spec {
    NSString *key = [spec propertyForKey:@"key"];
    NSNumber *def = [spec propertyForKey:@"default"];
    id v = [self valueForKey:key fallback:def];
    return @([v boolValue]);
}

- (void)setBool:(id)value specifier:(PSSpecifier *)spec {
    NSString *key = [spec propertyForKey:@"key"];
    [self storeValue:@([value boolValue]) forKey:key];
}

- (id)getNumber:(PSSpecifier *)spec {
    NSString *key = [spec propertyForKey:@"key"];
    NSNumber *def = [spec propertyForKey:@"default"];
    return [self valueForKey:key fallback:def];
}

- (void)setNumber:(id)value specifier:(PSSpecifier *)spec {
    NSString *key = [spec propertyForKey:@"key"];
    [self storeValue:@([value doubleValue]) forKey:key];
}

- (id)getString:(PSSpecifier *)spec {
    NSString *key = [spec propertyForKey:@"key"];
    NSString *def = [spec propertyForKey:@"default"] ?: @"";
    return [self valueForKey:key fallback:def];
}

- (void)setString:(id)value specifier:(PSSpecifier *)spec {
    NSString *key = [spec propertyForKey:@"key"];
    [self storeValue:(value ?: @"") forKey:key];
}

#pragma mark - 构建界面

- (PSSpecifier *)switchRow:(NSString *)title key:(NSString *)key def:(BOOL)def {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:@selector(setBool:specifier:)
                                                         get:@selector(getBool:)
                                                      detail:nil
                                                        cell:6 /* PSButtonCell? 用 6=PSSwitchCell */
                                                       edit:nil];
    [spec setProperty:key forKey:@"key"];
    [spec setProperty:@(def) forKey:@"default"];
    [spec setProperty:@"com.lyhw.LYHW" forKey:@"defaults"];
    [spec setProperty:@"PSSwitchCell" forKey:@"cellClass"];
    return spec;
}

- (PSSpecifier *)sliderRow:(NSString *)title key:(NSString *)key def:(double)def min:(double)min max:(double)max {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:@selector(setNumber:specifier:)
                                                         get:@selector(getNumber:)
                                                      detail:nil
                                                        cell:5 /* PSSliderCell */
                                                       edit:nil];
    [spec setProperty:key forKey:@"key"];
    [spec setProperty:@(def) forKey:@"default"];
    [spec setProperty:@(min) forKey:@"min"];
    [spec setProperty:@(max) forKey:@"max"];
    [spec setProperty:@(def) forKey:@"defaultValue"];
    [spec setProperty:@"PSSliderCell" forKey:@"cellClass"];
    return spec;
}

- (PSSpecifier *)textRow:(NSString *)title key:(NSString *)key def:(NSString *)def {
    // 用按钮行 + 弹窗输入：不依赖 Preferences 私有 cell 枚举，任何系统版本都稳
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:nil
                                                         get:nil
                                                      detail:nil
                                                        cell:2
                                                       edit:nil];
    [spec setProperty:key forKey:@"key"];
    [spec setProperty:def forKey:@"default"];
    [spec setProperty:@"PSButtonCell" forKey:@"cellClass"];
    [spec setProperty:@(YES) forKey:@"enabled"];
    [spec setTarget:self];
    [spec setButtonAction:@selector(editTextValue:)];
    return spec;
}

- (void)editTextValue:(PSSpecifier *)spec {
    NSString *key = [spec propertyForKey:@"key"];
    NSString *current = [self valueForKey:key fallback:[spec propertyForKey:@"default"]];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[spec name]
                                                                  message:@"输入文本（颜色用 #RRGGBB）"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = current;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *text = alert.textFields.firstObject.text ?: @"";
        [weakSelf storeValue:text forKey:key];
        [weakSelf reloadSpecifiers];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (NSArray *)specifiers {
    if (_specs) return _specs;

    _specs = [NSMutableArray array];

    // ===== 界面圆角 =====
    [_specs addObject:[PSSpecifier groupSpecifierWithName:@"界面圆角"]];
    [_specs addObject:[self switchRow:@"启用主界面圆角" key:@"homepageCornerEnabled" def:YES]];
    [_specs addObject:[self switchRow:@"启用主框架圆角" key:@"mainFrameCornerEnabled" def:YES]];
    [_specs addObject:[self switchRow:@"列表卡片化间距" key:@"mainFrameSpacingUnifyEnabled" def:YES]];
    [_specs addObject:[self switchRow:@"发现页圆角" key:@"discoverPageCornerEnabled" def:YES]];
    [_specs addObject:[self sliderRow:@"圆角大小" key:@"globalCornerRadius" def:15 min:0 max:40]];
    [_specs addObject:[self sliderRow:@"卡片间距" key:@"globalCornerSpacing" def:6 min:0 max:20]];
    [_specs addObject:[self sliderRow:@"左右留白" key:@"globalCornerMargin" def:10 min:0 max:30]];
    [_specs addObject:[self sliderRow:@"描边宽度" key:@"globalCornerStroke" def:0 min:0 max:3]];
    [_specs addObject:[self textRow:@"浅色背景色 (#RRGGBB)" key:@"globalCornerBackgroundColorLight" def:@"#FFFFFF"]];
    [_specs addObject:[self textRow:@"深色背景色 (#RRGGBB)" key:@"globalCornerBackgroundColorDark" def:@"#1C1C1E"]];
    [_specs addObject:[self textRow:@"浅色描边色" key:@"globalCornerStrokeColorLight" def:@"#E5E5EA"]];
    [_specs addObject:[self textRow:@"深色描边色" key:@"globalCornerStrokeColorDark" def:@"#3A3A3C"]];

    // ===== 头像框圆角 =====
    [_specs addObject:[PSSpecifier groupSpecifierWithName:@"头像框圆角"]];
    [_specs addObject:[self switchRow:@"启用头像圆角" key:@"avatarCornerEnabled" def:YES]];
    [_specs addObject:[self sliderRow:@"圆角比例 (%)" key:@"avatarCornerRadius" def:100 min:0 max:100]];
    [_specs addObject:[self switchRow:@"头像缩放" key:@"avatarCornerScaleEnabled" def:NO]];
    [_specs addObject:[self sliderRow:@"缩放比例" key:@"avatarCornerScale" def:1.0 min:0.6 max:1.0]];
    [_specs addObject:[self switchRow:@"头像描边" key:@"avatarCornerBorderEnabled" def:NO]];
    [_specs addObject:[self sliderRow:@"描边粗细" key:@"avatarCornerBorderSize" def:1.0 min:0 max:6]];
    [_specs addObject:[self textRow:@"浅色描边色" key:@"avatarCornerBorderColorLight" def:@"#D9D9D9"]];
    [_specs addObject:[self textRow:@"深色描边色" key:@"avatarCornerBorderColorDark" def:@"#3F3F41"]];

    // ===== 资料卡美化 =====
    [_specs addObject:[PSSpecifier groupSpecifierWithName:@"资料卡美化"]];
    [_specs addObject:[self switchRow:@"启用资料卡美化" key:@"profileCardBeautifyEnabled" def:YES]];
    [_specs addObject:[self switchRow:@"资料卡圆角" key:@"profileCornerEnabled" def:YES]];
    [_specs addObject:[self switchRow:@"圆角跟随全局" key:@"profileFollowGlobalCornerEnabled" def:YES]];
    [_specs addObject:[self sliderRow:@"独立圆角大小" key:@"profileCornerRadius" def:16 min:0 max:40]];
    [_specs addObject:[self textRow:@"背景图路径" key:@"profileCardBackgroundImagePath" def:@""]];
    [_specs addObject:[self sliderRow:@"背景图透明度" key:@"profileCardBackgroundImageAlpha" def:1.0 min:0 max:1.0]];
    [_specs addObject:[self textRow:@"浅色背景色" key:@"profileCardBackgroundLightColor" def:@"#F2F2F7"]];
    [_specs addObject:[self textRow:@"深色背景色" key:@"profileCardBackgroundDarkColor" def:@"#000000"]];
    [_specs addObject:[self textRow:@"昵称颜色" key:@"profileCardNameLightColor" def:@"#111111"]];
    [_specs addObject:[self textRow:@"签名颜色" key:@"profileCardSignatureLightColor" def:@"#8E8E93"]];
    [_specs addObject:[self switchRow:@"默认隐藏微信号" key:@"profileCardWechatIDHiddenByDefault" def:NO]];

    // ===== 消息横幅美化 =====
    [_specs addObject:[PSSpecifier groupSpecifierWithName:@"消息横幅美化"]];
    [_specs addObject:[self switchRow:@"启用横幅美化" key:@"msgBannerBeautifyEnabled" def:NO]];
    [_specs addObject:[self sliderRow:@"横幅高度" key:@"msgBannerHeight" def:70 min:40 max:140]];
    [_specs addObject:[self sliderRow:@"横幅宽度 (0=跟随系统)" key:@"msgBannerWidth" def:0 min:0 max:420]];
    [_specs addObject:[self sliderRow:@"左右外边距" key:@"msgBannerExtraMargin" def:0 min:0 max:30]];
    [_specs addObject:[self sliderRow:@"停留秒数" key:@"msgBannerStaySeconds" def:3 min:1 max:10]];
    [_specs addObject:[self sliderRow:@"正文最大字数 (0=不限)" key:@"msgBannerMaxTextLength" def:0 min:0 max:200]];
    [_specs addObject:[self switchRow:@"背景图" key:@"msgBannerBgUseImageBackground" def:NO]];
    [_specs addObject:[self textRow:@"背景图目录" key:@"msgBannerBgImageFolder" def:@""]];
    [_specs addObject:[self sliderRow:@"背景图透明度" key:@"msgBannerBgImageAlpha" def:1.0 min:0 max:1.0]];
    [_specs addObject:[self switchRow:@"自定义背景色" key:@"msgBannerBgColorEnabled" def:NO]];
    [_specs addObject:[self textRow:@"背景色(浅)" key:@"msgBannerBgColorLight" def:@"#FFFFFF"]];
    [_specs addObject:[self textRow:@"背景色(深)" key:@"msgBannerBgColorDark" def:@"#1C1C1E"]];
    [_specs addObject:[self switchRow:@"昵称配色" key:@"msgBannerNicknameColorEnabled" def:NO]];
    [_specs addObject:[self textRow:@"昵称色(浅)" key:@"msgBannerNicknameColorLight" def:@"#111111"]];
    [_specs addObject:[self switchRow:@"正文配色" key:@"msgBannerContentColorEnabled" def:NO]];
    [_specs addObject:[self textRow:@"正文色(浅)" key:@"msgBannerContentColorLight" def:@"#3A3A3C"]];

    // ===== 菜单美化 =====
    [_specs addObject:[PSSpecifier groupSpecifierWithName:@"菜单美化"]];
    [_specs addObject:[self switchRow:@"菜单圆角" key:@"menuCornerEnabled" def:YES]];
    [_specs addObject:[self sliderRow:@"菜单圆角大小" key:@"menuCornerRadius" def:14 min:0 max:30]];
    [_specs addObject:[self sliderRow:@"菜单描边" key:@"menuCornerBorderSize" def:0 min:0 max:3]];
    [_specs addObject:[self switchRow:@"加号菜单圆角" key:@"plusMenuCornerEnabled" def:YES]];
    [_specs addObject:[self sliderRow:@"加号菜单圆角大小" key:@"plusMenuCornerRadius" def:16 min:0 max:30]];
    [_specs addObject:[self switchRow:@"菜单背景图" key:@"menuUseImageBackground" def:NO]];
    [_specs addObject:[self textRow:@"背景图目录" key:@"menuBackgroundImageFolder" def:@""]];
    [_specs addObject:[self switchRow:@"自定义菜单底色" key:@"menuColorEnabled" def:NO]];
    [_specs addObject:[self textRow:@"菜单底色(浅)" key:@"menuColorLight" def:@"#FFFFFF"]];
    [_specs addObject:[self textRow:@"菜单底色(深)" key:@"menuColorDark" def:@"#1C1C1E"]];
    [_specs addObject:[self switchRow:@"自定义文字色" key:@"menuTextColorEnabled" def:NO]];
    [_specs addObject:[self textRow:@"文字色(浅)" key:@"menuTextColorLight" def:@"#111111"]];
    [_specs addObject:[self switchRow:@"自定义图标色" key:@"menuIconColorEnabled" def:NO]];
    [_specs addObject:[self textRow:@"图标色(浅)" key:@"menuIconColorLight" def:@"#111111"]];

    return _specs;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"LYHW";
}

@end
