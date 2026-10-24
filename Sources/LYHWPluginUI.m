//
//  LYHWPluginUI.m
//  LYHW
//

#import "LYHWPluginUI.h"
#import "LYHWConfig.h"
#import "LYHWSpeedMenuItem.h"
#import "LYHWSpeedCellFactory.h"
#import "LYHWSpeedAlert.h"
#import "LYHWSpeedConfig.h"
#import "DYLAppearance.h"
#import <objc/runtime.h>

static NSString * const kCellID = @"LYHWPluginCell";

static NSDictionary *LYHWPage(NSString *title, NSArray *items) {
    return @{ @"title": title, @"kind": @"page", @"items": items };
}

static NSDictionary *LYHWItem(NSString *title, NSString *key, NSString *kind,
                             double minValue, double maxValue) {
    return @{ @"title": title, @"key": key, @"kind": kind,
              @"min": @(minValue), @"max": @(maxValue) };
}

// 按图1的“页面入口 → 页面设置”组织重复的开关/半径/边框项目。
static void LYHWAddCornerGroup(NSMutableArray *a, NSString *title, NSString *prefix, BOOL border) {
    [a addObject:LYHWItem([title stringByAppendingString:@"圆角"], [prefix stringByAppendingString:@"Enabled"], @"bool", 0, 1)];
    [a addObject:LYHWItem([title stringByAppendingString:@"半径"], [prefix stringByAppendingString:@"Radius"], @"num", 0, 60)];
    if (border) [a addObject:LYHWItem([title stringByAppendingString:@"边框"], [prefix stringByAppendingString:@"BorderSize"], @"num", 0, 6)];
}

static NSDictionary *LYHWPageWithItems(NSString *title, NSArray *items) {
    return LYHWPage(title, items);
}

@interface LYHWPluginSettingsViewController ()
@property (nonatomic, strong) NSArray<NSDictionary *> *sections;
@property (nonatomic, copy) NSString *pageTitle;
@end

@implementation LYHWPluginSettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.pageTitle ?: @"兰因后悟";
    self.tableView.rowHeight = 52.0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    if (self.sections) return;
    // 一级菜单按页面分类，结构仿照用户提供的图1；你的页脚和配置管理保留。
    #define P(t, ...) LYHWPageWithItems(t, @[__VA_ARGS__])
    NSMutableArray *chat = [NSMutableArray array];
    [chat addObject:LYHWItem(@"输入框圆角", @"inputCornerEnabled", @"bool", 0, 1)];
    [chat addObject:LYHWItem(@"输入框圆角半径", @"inputCornerRadius", @"num", 0, 30)];
    [chat addObject:LYHWItem(@"聊天顶栏圆角", @"topbarCornerEnabled", @"bool", 0, 1)];
    [chat addObject:LYHWItem(@"聊天顶栏圆角半径", @"topbarCornerRadius", @"num", 0, 80)];
    [chat addObject:LYHWItem(@"底栏圆角", @"toolbarCornerEnabled", @"bool", 0, 1)];
    [chat addObject:LYHWItem(@"底栏圆角半径", @"toolbarCornerRadius", @"num", 0, 40)];
    LYHWAddCornerGroup(chat, @"聊天图片/视频", @"chatImageCorner", YES);
    LYHWAddCornerGroup(chat, @"聊天表情", @"emojiCorner", YES);
    LYHWAddCornerGroup(chat, @"聊天时间条", @"chatTimeRoundCorner", YES);
    LYHWAddCornerGroup(chat, @"引用消息", @"msgReferCorner", YES);
    LYHWAddCornerGroup(chat, @"位置卡片", @"chatLocationCorner", YES);
    LYHWAddCornerGroup(chat, @"文件卡片", @"chatFileCorner", YES);
    LYHWAddCornerGroup(chat, @"音乐卡片", @"chatMusicCorner", YES);
    LYHWAddCornerGroup(chat, @"名片卡片", @"chatCardCorner", YES);
    LYHWAddCornerGroup(chat, @"红包/转账", @"chatRedPacketCorner", YES);
    LYHWAddCornerGroup(chat, @"收藏转发", @"chatFavoriteCorner", YES);
    LYHWAddCornerGroup(chat, @"公众号文章", @"chatArticleCorner", YES);
    LYHWAddCornerGroup(chat, @"聊天记录", @"chatHistoryCorner", YES);
    LYHWAddCornerGroup(chat, @"小程序", @"chatMiniProgramCorner", YES);
    LYHWAddCornerGroup(chat, @"群置顶提示", @"chatPinTipsCorner", YES);

    NSMutableArray *content = [NSMutableArray array];
    LYHWAddCornerGroup(content, @"视频号", @"finderCorner", YES);
    LYHWAddCornerGroup(content, @"收藏页", @"favoriteCorner", YES);
    LYHWAddCornerGroup(content, @"相册选图", @"photoAlbumCorner", YES);
    LYHWAddCornerGroup(content, @"搜索缩略图", @"chatSearchThumbCorner", YES);
    LYHWAddCornerGroup(content, @"文件浏览", @"fileBrowseCorner", YES);

    NSMutableArray *service = [NSMutableArray array];
    LYHWAddCornerGroup(service, @"服务页/钱包", @"serviceCorner", YES);

    NSArray *pages = @[
        P(@"微信主页", LYHWItem(@"卡片圆角", @"mainFrameCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"卡片阴影", @"cardShadowEnabled", @"bool", 0, 1),
                      LYHWItem(@"隐藏点击特效", @"cellTapEffectHidden", @"bool", 0, 1),
                      LYHWItem(@"阴影强度(0~1)", @"cardShadowStrength", @"num", 0, 1),
                      LYHWItem(@"搜索框圆角", @"searchCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"搜索框圆角半径", @"searchCornerRadius", @"num", 0, 30)),
        P(@"通讯录页", LYHWItem(@"卡片圆角", @"homepageCornerEnabled", @"bool", 0, 1)),
        P(@"发现页", LYHWItem(@"卡片圆角", @"discoverPageCornerEnabled", @"bool", 0, 1),
                     LYHWItem(@"圆角半径", @"globalCornerRadius", @"num", 2, 30),
                     LYHWItem(@"左右留白", @"globalCornerMargin", @"num", 0, 30),
                     LYHWItem(@"视频号圆角入口", @"finderCornerEnabled", @"bool", 0, 1)),
        P(@"我的页面", LYHWItem(@"卡片圆角", @"myPageCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"圆角半径", @"myPageCornerRadius", @"num", 2, 40),
                      LYHWItem(@"左右留白", @"myPageCornerMargin", @"num", 0, 40),
                      LYHWItem(@"服务页卡片圆角", @"servicePageCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"服务页卡片半径", @"servicePageCornerRadius", @"num", 2, 40)),
        P(@"微信设置页", LYHWItem(@"卡片圆角", @"settingPageCornerEnabled", @"bool", 0, 1)),
        P(@"好友资料页", LYHWItem(@"好友资料页圆角", @"profilePageCornerEnabled", @"bool", 0, 1),
                       LYHWItem(@"圆角半径", @"profilePageCornerRadius", @"num", 0, 60),
                       LYHWItem(@"左右留白", @"profilePageCornerMargin", @"num", 0, 40)),
        P(@"群聊资料页", LYHWItem(@"群聊资料页圆角", @"groupInfoCornerEnabled", @"bool", 0, 1),
                         LYHWItem(@"圆角半径", @"groupInfoCornerRadius", @"num", 0, 60),
                         LYHWItem(@"左右留白", @"groupInfoCornerMargin", @"num", 0, 40)),
        P(@"聊天详情页", LYHWItem(@"聊天详情页圆角", @"chatDetailCornerEnabled", @"bool", 0, 1),
                         LYHWItem(@"圆角半径", @"chatDetailCornerRadius", @"num", 0, 60),
                         LYHWItem(@"左右留白", @"chatDetailCornerMargin", @"num", 0, 40)),
        LYHWPageWithItems(@"聊天页圆角", chat),
        P(@"朋友圈圆角", LYHWItem(@"朋友圈卡片圆角", @"timelineCornerEnabled", @"bool", 0, 1),
                       LYHWItem(@"朋友圈卡片半径", @"timelineCornerRadius", @"num", 2, 40),
                       LYHWItem(@"朋友圈图片/视频圆角", @"timelineMediaCornerEnabled", @"bool", 0, 1),
                       LYHWItem(@"图片/视频半径", @"timelineMediaCornerRadius", @"num", 2, 40),
                       LYHWItem(@"朋友圈评论圆角", @"timelineCommentCornerEnabled", @"bool", 0, 1),
                       LYHWItem(@"评论半径", @"timelineCommentCornerRadius", @"num", 2, 30)),
        LYHWPageWithItems(@"内容页圆角", content),
        LYHWPageWithItems(@"服务页圆角", service),
        P(@"头像圆角", LYHWItem(@"头像圆角", @"avatarCornerEnabled", @"bool", 0, 1),
                     LYHWItem(@"头像圆角比例(%)", @"avatarCornerRadius", @"num", 10, 100)),
        P(@"悬浮底栏", LYHWItem(@"启用悬浮底栏（重启生效；与主页卡片圆角互斥）", @"floatingTabBarEnabled", @"bool", 0, 1),
                      LYHWItem(@"悬浮底栏左右留白", @"wkkFloatTabWidth", @"num", -40, 80),
                      LYHWItem(@"悬浮底栏高度增量", @"wkkFloatTabHeight", @"num", -14, 40),
                      LYHWItem(@"悬浮底栏垂直位置", @"wkkFloatTabY", @"num", -40, 40),
                      LYHWItem(@"悬浮底栏圆角（-1自动）", @"wkkFloatTabRadius", @"num", -1, 60),
                      LYHWItem(@"悬浮底栏透明度(%)", @"wkkFloatTabAlpha", @"num", 0, 100),
                      LYHWItem(@"毛玻璃透明度(%)", @"wkkFloatTabMaskAlpha", @"num", 0, 100),
                      LYHWItem(@"按钮缩放(%)", @"wkkFloatTabButtonScale", @"num", 0, 100),
                      LYHWItem(@"隐藏底栏文字", @"wkkFloatTabHideText", @"bool", 0, 1),
                      LYHWItem(@"隐藏红点", @"wkkFloatTabHideDot", @"bool", 0, 1),
                      LYHWItem(@"隐藏数字角标", @"wkkFloatTabHideBadge", @"bool", 0, 1),
                      LYHWItem(@"关闭毛玻璃遮罩", @"wkkFloatTabNoMask", @"bool", 0, 1),
                      LYHWItem(@"立体风格", @"wkkFloatTabStereo", @"bool", 0, 1),
                      LYHWItem(@"遮罩发光", @"wkkFloatTabMaskGlow", @"bool", 0, 1),
                      LYHWItem(@"遮罩随滚动位移", @"wkkFloatTabMaskSlide", @"bool", 0, 1),
                      LYHWItem(@"选中图标动画", @"wkkFloatTabIconAnim", @"bool", 0, 1),
                      LYHWItem(@"长按快速设置", @"wkkFloatTabLongPopup", @"bool", 0, 1)),
        P(@"原生液态底栏", LYHWItem(@"iOS 26 原生液态底栏（重启生效）", @"liquidTabBarEnabled", @"bool", 0, 1)),
        @{ @"title": @"字体与主题 DIY", @"kind": @"appearance" }
    ];
    #undef P
    self.sections = @[ @{ @"header": @"兰因后悟", @"items": pages },
                       @{ @"header": @"配置管理", @"items": @[
                           @{ @"title": @"导出配置", @"kind": @"action", @"action": @"export" },
                           @{ @"title": @"导入配置", @"kind": @"action", @"action": @"import" } ] } ];

    if (!self.pageTitle) {
        UILabel *by = [UILabel new];
        by.text = @"休恋逝水 早悟兰因     by懒小王";
        by.numberOfLines = 0;
        by.textAlignment = NSTextAlignmentCenter;
        by.font = [UIFont systemFontOfSize:13];
        by.textColor = [UIColor colorWithWhite:0.6 alpha:1];
        by.frame = CGRectMake(0, 0, 320, 60);
        self.tableView.tableFooterView = by;
    }
}

- (void)closeTapped {
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Model

- (NSDictionary *)itemAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *section = self.sections[(NSUInteger)indexPath.section];
    NSArray *items = section[@"items"];
    return items[(NSUInteger)indexPath.row];
}

static NSDictionary<NSString *, NSArray *> *LYHWFloatTabDefaults(void) {
    static NSDictionary *map; static dispatch_once_t once;
    dispatch_once(&once, ^{ map = @{
        @"wkkFloatTabWidth": @[@-1, @(-40), @(80)],
        @"wkkFloatTabHeight": @[@12, @(-14), @(40)],
        @"wkkFloatTabY": @[@-4, @(-40), @(40)],
        @"wkkFloatTabRadius": @[@-1, @(-1), @(60)],
        @"wkkFloatTabAlpha": @[@100, @(0), @(100)],
        @"wkkFloatTabMaskAlpha": @[@100, @(0), @(100)],
        @"wkkFloatTabButtonScale": @[@0, @(0), @(100)]
    }; });
    return map;
}
static id LYHWFloatTabValue(NSString *key) {
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    NSArray *spec = LYHWFloatTabDefaults()[key];
    return v ?: (spec ? spec[0] : nil);
}

- (BOOL)boolValueForKey:(NSString *)key {
    id floatValue = LYHWFloatTabValue(key);
    if (floatValue) return [floatValue boolValue];
    id value = nil;
    @try { value = [[LYHWConfig shared] valueForKey:key]; } @catch (__unused id e) {}
    if (!value) value = [[LYHWConfig shared] objectForKey:key def:nil];
    return [value boolValue];
}

- (double)numberValueForKey:(NSString *)key item:(NSDictionary *)item {
    id value = LYHWFloatTabValue(key);
    if (value) {
        NSArray *spec = LYHWFloatTabDefaults()[key];
        double v = [value doubleValue];
        return MAX([spec[1] doubleValue], MIN([spec[2] doubleValue], v));
    }
    value = nil;
    @try { value = [[LYHWConfig shared] valueForKey:key]; } @catch (__unused id e) {}
    if (!value) value = [[LYHWConfig shared] objectForKey:key def:nil];
    if (!value) return 0.0;
    double v = [value doubleValue];
    return MAX([item[@"min"] doubleValue], MIN([item[@"max"] doubleValue], v));
}

- (void)commitValue:(id)value forKey:(NSString *)key {
    LYHWConfig *cfg = [LYHWConfig shared];
    if (LYHWFloatTabDefaults()[key]) {
        [cfg setObject:value forKey:key];
        if ([key isEqualToString:@"floatingTabBarEnabled"] && [value boolValue]) {
            cfg.liquidTabBarEnabled = NO;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification object:nil];
        return;
    }
    [cfg setObject:value forKey:key];
    // 两套底栏 hook 互斥；悬浮底栏配置写入主 bundle defaults，由下次重启安装。
    if ([key isEqualToString:@"liquidTabBarEnabled"] && [value boolValue]) {
        cfg.floatingTabBarEnabled = NO;
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"wkkFloatTab"];
    } else if ([key isEqualToString:@"floatingTabBarEnabled"] && [value boolValue]) {
        cfg.liquidTabBarEnabled = NO;
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"liquidTabBarEnabled"];
    }
    // 新悬浮底栏模块遵循原源码的标准 defaults 键。
    if ([key isEqualToString:@"floatingTabBarEnabled"])
        [[NSUserDefaults standardUserDefaults] setBool:[value boolValue] forKey:@"wkkFloatTab"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification object:nil];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self.sections[(NSUInteger)section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[(NSUInteger)section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return nil;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)ip {
    NSInteger n = [tv numberOfRowsInSection:ip.section];
    cell.backgroundView = nil;
    cell.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor]; }];
    cell.layer.cornerRadius = 14;
    if (@available(iOS 13.0, *)) cell.layer.cornerCurve = kCACornerCurveContinuous;
    CACornerMask m = 0;
    if (ip.row == 0) m |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (ip.row == n - 1) m |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    cell.layer.maskedCorners = m;
    cell.layer.masksToBounds = YES;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:kCellID];
    }
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSDictionary *item = [self itemAtIndexPath:indexPath];
    cell.textLabel.text = item[@"title"];

    if ([item[@"kind"] isEqualToString:@"speed"]) {
        LYHWSpeedMenuItem *speedItem = [LYHWSpeedMenuItem uiSpeedItem];
        UITableViewCell *speedCell = [LYHWSpeedCellFactory cellForItem:speedItem target:self action:@selector(hb_speedCellTapped)];
        speedCell.textLabel.textColor = [UIColor labelColor];
        return speedCell;
    }
    if ([item[@"kind"] isEqualToString:@"page"] || [item[@"kind"] isEqualToString:@"action"] || [item[@"kind"] isEqualToString:@"appearance"]) {
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if ([item[@"kind"] isEqualToString:@"bool"]) {
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = [self boolValueForKey:item[@"key"]];
        objc_setAssociatedObject(toggle, @selector(commitValue:forKey:),
                                 indexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.detailTextLabel.text = nil;
    } else {
        double value = [self numberValueForKey:item[@"key"] item:item];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%g", value];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = [self itemAtIndexPath:indexPath];
    if ([item[@"kind"] isEqualToString:@"page"]) {
        LYHWPluginSettingsViewController *sub = [[LYHWPluginSettingsViewController alloc] init];
        sub.pageTitle = item[@"title"];
        sub.sections = @[ @{ @"header": item[@"title"], @"items": item[@"items"] } ];
        [self.navigationController pushViewController:sub animated:YES];
        return;
    }
    if ([item[@"kind"] isEqualToString:@"appearance"]) {
        [DYLSettingsController presentFrom:self];
        return;
    }
    if ([item[@"kind"] isEqualToString:@"speed"]) {
        LYHWSpeedMenuItem *speedItem = [LYHWSpeedMenuItem uiSpeedItem];
        [LYHWSpeedAlert showEditorFrom:self item:speedItem onChanged:^(__unused float v) { [self.tableView reloadData]; }];
        return;
    }
    if ([item[@"kind"] isEqualToString:@"action"]) {
        if ([item[@"action"] isEqualToString:@"export"]) [self exportConfig];
        else [self importConfig];
        return;
    }
    if (![item[@"kind"] isEqualToString:@"num"]) return;

    double current = [self numberValueForKey:item[@"key"] item:item];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:item[@"title"]
                                            message:[NSString stringWithFormat:@"范围 %g ~ %g",
                                                     [item[@"min"] doubleValue], [item[@"max"] doubleValue]]
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeDecimalPad;
        field.text = [NSString stringWithFormat:@"%g", current];
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text ?: @"";
        double value = [text doubleValue];
        value = MAX([item[@"min"] doubleValue], MIN([item[@"max"] doubleValue], value));
        [weakSelf commitValue:@(value) forKey:item[@"key"]];
        [weakSelf.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)hb_speedCellTapped {
    __weak typeof(self) ws = self;
    [LYHWSpeedAlert showEditorFrom:self item:[LYHWSpeedMenuItem uiSpeedItem] onChanged:^(__unused float v) { [ws.tableView reloadData]; }];
}

- (void)hb_speedAlertConfirm:(id)sender {
    NSString *t = nil;
    @try { t = [sender valueForKey:@"textFieldText"]; } @catch (__unused id e) {}
    LYHWSetUISpeed((float)t.floatValue);
    [LYHWSpeedAlert showRestartPromptFrom:self item:[LYHWSpeedMenuItem uiSpeedItem]];
}

- (void)toast:(NSString *)title msg:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)exportConfig {
    NSDictionary *d = [[LYHWConfig shared] exportAll];
    NSData *data = [NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted error:nil];
    if (!data) { [self toast:@"导出失败" msg:@"配置无法序列化"]; return; }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [UIPasteboard generalPasteboard].string = json;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LYHW-config.json"];
    [data writeToFile:path atomically:YES];
    UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    vc.popoverPresentationController.sourceView = self.view;
    vc.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)importConfig {
    NSString *json = [UIPasteboard generalPasteboard].string;
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    id obj = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![obj isKindOfClass:[NSDictionary class]]) {
        [self toast:@"导入失败" msg:@"请先复制导出的配置 JSON 到剪贴板，再点导入配置。"];
        return;
    }
    __weak typeof(self) ws = self;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"导入配置"
        message:[NSString stringWithFormat:@"检测到剪贴板中有 %lu 项配置，导入将覆盖同名设置。", (unsigned long)[obj count]]
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"导入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSInteger n = [[LYHWConfig shared] importAll:obj];
        [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification object:nil];
        [ws.tableView reloadData];
        [ws toast:@"导入完成" msg:[NSString stringWithFormat:@"已导入 %ld 项，重新进入页面后生效。", (long)n]];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)toggleChanged:(UISwitch *)sender {
    NSIndexPath *indexPath = objc_getAssociatedObject(sender, @selector(commitValue:forKey:));
    if (!indexPath) return;
    NSDictionary *item = [self itemAtIndexPath:indexPath];
    [self commitValue:@(sender.on) forKey:item[@"key"]];
    if ([item[@"key"] isEqualToString:@"floatingTabBarEnabled"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"悬浮底栏设置已保存"
                                                                       message:sender.on ? @"为避免与原生液态底栏同时注入，请先确认“iOS 26 原生液态底栏”已关闭，然后完全退出并重新打开微信。悬浮底栏模式下主页卡片圆角会暂时停用。" : @"请完全退出并重新打开微信，恢复原底栏与主页卡片圆角。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end
