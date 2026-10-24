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
    #define P(t, ...) LYHWPage(t, @[__VA_ARGS__])
    NSArray *pages = @[
        P(@"微信主页", LYHWItem(@"卡片圆角", @"mainFrameCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"卡片阴影", @"cardShadowEnabled", @"bool", 0, 1),
                      LYHWItem(@"隐藏点击特效", @"cellTapEffectHidden", @"bool", 0, 1),
                      LYHWItem(@"阴影强度(0~1)", @"cardShadowStrength", @"num", 0, 1),
                      LYHWItem(@"头像圆角", @"avatarCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"头像圆角比例(%)", @"avatarCornerRadius", @"num", 10, 100),
                      LYHWItem(@"搜索框圆角", @"searchCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"搜索框圆角半径", @"searchCornerRadius", @"num", 0, 30),
                      LYHWItem(@"输入框圆角", @"inputCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"输入框圆角半径", @"inputCornerRadius", @"num", 0, 30),
                      LYHWItem(@"顶栏圆角", @"topbarCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"顶栏圆角半径", @"topbarCornerRadius", @"num", 0, 80),
                      LYHWItem(@"底栏圆角", @"toolbarCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"底栏圆角半径", @"toolbarCornerRadius", @"num", 0, 40)),
        P(@"通讯录页", LYHWItem(@"卡片圆角", @"homepageCornerEnabled", @"bool", 0, 1)),
        P(@"发现页", LYHWItem(@"卡片圆角", @"discoverPageCornerEnabled", @"bool", 0, 1),
                     LYHWItem(@"圆角半径", @"globalCornerRadius", @"num", 2, 30),
                     LYHWItem(@"左右留白", @"globalCornerMargin", @"num", 0, 30),
                     LYHWItem(@"朋友圈卡片圆角", @"timelineCornerEnabled", @"bool", 0, 1),
                     LYHWItem(@"朋友圈卡片圆角半径", @"timelineCornerRadius", @"num", 2, 40),
                     LYHWItem(@"朋友圈图片/视频圆角", @"timelineMediaCornerEnabled", @"bool", 0, 1),
                     LYHWItem(@"图片/视频圆角半径", @"timelineMediaCornerRadius", @"num", 2, 40),
                     LYHWItem(@"朋友圈评论圆角", @"timelineCommentCornerEnabled", @"bool", 0, 1),
                     LYHWItem(@"评论圆角半径", @"timelineCommentCornerRadius", @"num", 2, 30)),
        P(@"我的页面", LYHWItem(@"卡片圆角", @"myPageCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"圆角半径", @"myPageCornerRadius", @"num", 2, 40),
                      LYHWItem(@"左右留白", @"myPageCornerMargin", @"num", 0, 40),
                      LYHWItem(@"服务页圆角", @"servicePageCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"服务页圆角半径", @"servicePageCornerRadius", @"num", 2, 40)),
        P(@"微信设置页", LYHWItem(@"卡片圆角", @"settingPageCornerEnabled", @"bool", 0, 1)),
        P(@"资料页圆角", LYHWItem(@"好友资料页圆角", @"profilePageCornerEnabled", @"bool", 0, 1),
                       LYHWItem(@"群聊资料页圆角", @"groupInfoCornerEnabled", @"bool", 0, 1)),
        P(@"聊天消息圆角",
                      LYHWItem(@"聊天图片/视频圆角", @"chatImageCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"聊天图片/视频半径", @"chatImageCornerRadius", @"num", 0, 60),
                      LYHWItem(@"聊天图片/视频边框", @"chatImageCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"聊天表情圆角", @"emojiCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"聊天表情半径", @"emojiCornerRadius", @"num", 0, 60),
                      LYHWItem(@"聊天表情边框", @"emojiCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"聊天时间条圆角", @"chatTimeRoundCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"聊天时间条半径", @"chatTimeRoundCornerRadius", @"num", 0, 60),
                      LYHWItem(@"聊天时间条边框", @"chatTimeRoundCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"引用消息圆角", @"msgReferCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"引用消息半径", @"msgReferCornerRadius", @"num", 0, 60),
                      LYHWItem(@"引用消息边框", @"msgReferCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"位置卡片圆角", @"chatLocationCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"位置卡片半径", @"chatLocationCornerRadius", @"num", 0, 60),
                      LYHWItem(@"位置卡片边框", @"chatLocationCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"文件卡片圆角", @"chatFileCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"文件卡片半径", @"chatFileCornerRadius", @"num", 0, 60),
                      LYHWItem(@"文件卡片边框", @"chatFileCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"音乐卡片圆角", @"chatMusicCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"音乐卡片半径", @"chatMusicCornerRadius", @"num", 0, 60),
                      LYHWItem(@"音乐卡片边框", @"chatMusicCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"名片卡片圆角", @"chatCardCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"名片卡片半径", @"chatCardCornerRadius", @"num", 0, 60),
                      LYHWItem(@"名片卡片边框", @"chatCardCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"红包/转账圆角", @"chatRedPacketCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"红包/转账半径", @"chatRedPacketCornerRadius", @"num", 0, 60),
                      LYHWItem(@"红包/转账边框", @"chatRedPacketCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"收藏转发圆角", @"chatFavoriteCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"收藏转发半径", @"chatFavoriteCornerRadius", @"num", 0, 60),
                      LYHWItem(@"收藏转发边框", @"chatFavoriteCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"公众号文章圆角", @"chatArticleCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"公众号文章半径", @"chatArticleCornerRadius", @"num", 0, 60),
                      LYHWItem(@"公众号文章边框", @"chatArticleCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"聊天记录圆角", @"chatHistoryCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"聊天记录半径", @"chatHistoryCornerRadius", @"num", 0, 60),
                      LYHWItem(@"聊天记录边框", @"chatHistoryCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"小程序圆角", @"chatMiniProgramCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"小程序半径", @"chatMiniProgramCornerRadius", @"num", 0, 60),
                      LYHWItem(@"小程序边框", @"chatMiniProgramCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"群置顶提示圆角", @"chatPinTipsCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"群置顶提示半径", @"chatPinTipsCornerRadius", @"num", 0, 60),
                      LYHWItem(@"群置顶提示边框", @"chatPinTipsCornerBorderSize", @"num", 0, 6)),
        P(@"动态与内容圆角",
                      LYHWItem(@"朋友圈图片/视频圆角", @"momentCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"朋友圈图片/视频半径", @"momentCornerRadius", @"num", 0, 60),
                      LYHWItem(@"朋友圈图片/视频边框", @"momentCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"视频号圆角", @"finderCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"视频号半径", @"finderCornerRadius", @"num", 0, 60),
                      LYHWItem(@"视频号边框", @"finderCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"收藏页圆角", @"favoriteCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"收藏页半径", @"favoriteCornerRadius", @"num", 0, 60),
                      LYHWItem(@"收藏页边框", @"favoriteCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"相册选图圆角", @"photoAlbumCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"相册选图半径", @"photoAlbumCornerRadius", @"num", 0, 60),
                      LYHWItem(@"相册选图边框", @"photoAlbumCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"搜索缩略图圆角", @"chatSearchThumbCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"搜索缩略图半径", @"chatSearchThumbCornerRadius", @"num", 0, 60),
                      LYHWItem(@"搜索缩略图边框", @"chatSearchThumbCornerBorderSize", @"num", 0, 6),
                      LYHWItem(@"文件浏览圆角", @"fileBrowseCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"文件浏览半径", @"fileBrowseCornerRadius", @"num", 0, 60),
                      LYHWItem(@"文件浏览边框", @"fileBrowseCornerBorderSize", @"num", 0, 6)),
        P(@"服务页圆角",
                      LYHWItem(@"服务页/钱包圆角", @"serviceCornerEnabled", @"bool", 0, 1),
                      LYHWItem(@"服务页/钱包半径", @"serviceCornerRadius", @"num", 0, 60),
                      LYHWItem(@"服务页/钱包边框", @"serviceCornerBorderSize", @"num", 0, 6)),
        @{ @"title": @"自定义界面速度", @"kind": @"speed", @"key": @"editUiWindowsSpeed" },
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

- (BOOL)boolValueForKey:(NSString *)key {
    id value = nil;
    @try { value = [[LYHWConfig shared] valueForKey:key]; } @catch (__unused id e) {}
    if (!value) value = [[LYHWConfig shared] objectForKey:key def:nil];
    return [value boolValue];
}

- (double)numberValueForKey:(NSString *)key item:(NSDictionary *)item {
    id value = nil;
    @try { value = [[LYHWConfig shared] valueForKey:key]; } @catch (__unused id e) {}
    if (!value) value = [[LYHWConfig shared] objectForKey:key def:nil];
    if (!value) return 0.0;
    double v = [value doubleValue];
    return MAX([item[@"min"] doubleValue], MIN([item[@"max"] doubleValue], v));
}

- (void)commitValue:(id)value forKey:(NSString *)key {
    [[LYHWConfig shared] setObject:value forKey:key];
    [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification
                                                        object:nil];
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
    if ([item[@"kind"] isEqualToString:@"page"] || [item[@"kind"] isEqualToString:@"action"]) {
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
}

@end
