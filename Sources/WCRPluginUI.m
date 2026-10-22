//
//  WCRPluginUI.m
//  WCRefineRebuild
//

#import "WCRPluginUI.h"
#import "WCRConfig.h"
#import <objc/runtime.h>

static NSString * const kCellID = @"WCRPluginCell";

static NSDictionary *WCRPage(NSString *title, NSArray *items) {
    return @{ @"title": title, @"kind": @"page", @"items": items };
}

static NSDictionary *WCRItem(NSString *title, NSString *key, NSString *kind,
                             double minValue, double maxValue) {
    return @{ @"title": title, @"key": key, @"kind": kind,
              @"min": @(minValue), @"max": @(maxValue) };
}

@interface WCRPluginSettingsViewController ()
@property (nonatomic, strong) NSArray<NSDictionary *> *sections;
@property (nonatomic, copy) NSString *pageTitle;
@end

@implementation WCRPluginSettingsViewController

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

    self.title = self.pageTitle ?: @"微信美化";
    self.tableView.rowHeight = 52.0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    if (self.sections) return;
    #define P(t, ...) WCRPage(t, @[__VA_ARGS__])
    NSArray *pages = @[
        P(@"微信主页", WCRItem(@"卡片圆角", @"mainFrameCornerEnabled", @"bool", 0, 1)),
        P(@"通讯录页", WCRItem(@"卡片圆角", @"homepageCornerEnabled", @"bool", 0, 1)),
        P(@"发现页", WCRItem(@"卡片圆角", @"discoverPageCornerEnabled", @"bool", 0, 1),
                     WCRItem(@"圆角半径", @"globalCornerRadius", @"num", 2, 30),
                     WCRItem(@"左右留白", @"globalCornerMargin", @"num", 0, 30)),
        P(@"我的页面", WCRItem(@"卡片圆角", @"myPageCornerEnabled", @"bool", 0, 1),
                      WCRItem(@"圆角半径", @"myPageCornerRadius", @"num", 2, 40),
                      WCRItem(@"左右留白", @"myPageCornerMargin", @"num", 0, 40)),
        P(@"服务页", WCRItem(@"服务页圆角", @"servicePageCornerEnabled", @"bool", 0, 1),
                    WCRItem(@"圆角半径", @"servicePageCornerRadius", @"num", 2, 40)),
        P(@"转发页面", WCRItem(@"转发选择器圆角", @"forwardPickerCornerEnabled", @"bool", 0, 1),
                      WCRItem(@"圆角半径", @"forwardPickerCornerRadius", @"num", 2, 40)),
        P(@"微信设置页", WCRItem(@"卡片圆角", @"settingPageCornerEnabled", @"bool", 0, 1)),
        P(@"好友资料页", WCRItem(@"卡片圆角", @"profilePageCornerEnabled", @"bool", 0, 1)),
        P(@"群聊资料页", WCRItem(@"卡片圆角", @"groupInfoCornerEnabled", @"bool", 0, 1)),
        P(@"朋友圈圆角", WCRItem(@"朋友圈卡片圆角", @"timelineCornerEnabled", @"bool", 0, 1),
                       WCRItem(@"卡片圆角半径", @"timelineCornerRadius", @"num", 2, 40),
                       WCRItem(@"图片/视频圆角", @"timelineMediaCornerEnabled", @"bool", 0, 1),
                       WCRItem(@"图片/视频圆角半径", @"timelineMediaCornerRadius", @"num", 2, 40),
                       WCRItem(@"评论圆角", @"timelineCommentCornerEnabled", @"bool", 0, 1),
                       WCRItem(@"评论圆角半径", @"timelineCommentCornerRadius", @"num", 2, 30)),
        P(@"顶栏 / 底栏", WCRItem(@"顶栏圆角", @"topbarCornerEnabled", @"bool", 0, 1),
                        WCRItem(@"顶栏圆角半径", @"topbarCornerRadius", @"num", 0, 40),
                        WCRItem(@"底栏圆角", @"toolbarCornerEnabled", @"bool", 0, 1),
                        WCRItem(@"底栏圆角半径", @"toolbarCornerRadius", @"num", 0, 40),
                        WCRItem(@"悬浮胶囊 TabBar", @"floatingTabBarEnabled", @"bool", 0, 1)),
        P(@"搜索框 / 输入框", WCRItem(@"搜索框圆角", @"searchCornerEnabled", @"bool", 0, 1),
                          WCRItem(@"搜索框圆角半径", @"searchCornerRadius", @"num", 0, 30),
                          WCRItem(@"输入框圆角", @"inputCornerEnabled", @"bool", 0, 1),
                          WCRItem(@"输入框圆角半径", @"inputCornerRadius", @"num", 0, 30)),
        P(@"卡片阴影", WCRItem(@"全局卡片阴影", @"cardShadowEnabled", @"bool", 0, 1),
                      WCRItem(@"阴影强度(0~1)", @"cardShadowStrength", @"num", 0, 1)),
        P(@"头像圆角", WCRItem(@"头像圆角", @"avatarCornerEnabled", @"bool", 0, 1),
                      WCRItem(@"圆角比例(%)", @"avatarCornerRadius", @"num", 10, 100)),
    ];
    #undef P
    self.sections = @[ @{ @"header": @"微信美化", @"items": pages } ];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"完成"
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(closeTapped)];
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
    @try { value = [[WCRConfig shared] valueForKey:key]; } @catch (__unused id e) {}
    if (!value) value = [[WCRConfig shared] objectForKey:key def:nil];
    return [value boolValue];
}

- (double)numberValueForKey:(NSString *)key item:(NSDictionary *)item {
    id value = nil;
    @try { value = [[WCRConfig shared] valueForKey:key]; } @catch (__unused id e) {}
    if (!value) value = [[WCRConfig shared] objectForKey:key def:nil];
    if (!value) return 0.0;
    double v = [value doubleValue];
    return MAX([item[@"min"] doubleValue], MIN([item[@"max"] doubleValue], v));
}

- (void)commitValue:(id)value forKey:(NSString *)key {
    [[WCRConfig shared] setObject:value forKey:key];
    [[NSNotificationCenter defaultCenter] postNotificationName:WCRSettingsChangedNotification
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
    if (!self.pageTitle && section == (NSInteger)self.sections.count - 1) {
        return @"改动即时生效；个别项目需重新进入页面才会体现。";
    }
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

    if ([item[@"kind"] isEqualToString:@"page"]) {
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
        WCRPluginSettingsViewController *sub = [[WCRPluginSettingsViewController alloc] init];
        sub.pageTitle = item[@"title"];
        sub.sections = @[ @{ @"header": item[@"title"], @"items": item[@"items"] } ];
        [self.navigationController pushViewController:sub animated:YES];
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

- (void)toggleChanged:(UISwitch *)sender {
    NSIndexPath *indexPath = objc_getAssociatedObject(sender, @selector(commitValue:forKey:));
    if (!indexPath) return;
    NSDictionary *item = [self itemAtIndexPath:indexPath];
    [self commitValue:@(sender.on) forKey:item[@"key"]];
}

@end
