//
//  WCRPluginUI.m
//  WCRefineRebuild
//

#import "WCRPluginUI.h"
#import "WCRConfig.h"
#import <objc/runtime.h>

static NSString * const kCellID = @"WCRPluginCell";

static NSDictionary *WCRItem(NSString *title, NSString *key, NSString *kind,
                             double minValue, double maxValue) {
    return @{ @"title": title, @"key": key, @"kind": kind,
              @"min": @(minValue), @"max": @(maxValue) };
}

@interface WCRPluginSettingsViewController ()
@property (nonatomic, strong) NSArray<NSDictionary *> *sections;
@end

@implementation WCRPluginSettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"微信美化";
    self.tableView.rowHeight = 48.0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.sections = @[
        @{ @"header": @"页面卡片圆角", @"items": @[
               WCRItem(@"微信页（消息列表）", @"mainFrameCornerEnabled", @"bool", 0, 1),
               WCRItem(@"通讯录页", @"homepageCornerEnabled", @"bool", 0, 1),
               WCRItem(@"发现页", @"discoverPageCornerEnabled", @"bool", 0, 1),
               WCRItem(@"设置页", @"settingPageCornerEnabled", @"bool", 0, 1),
               WCRItem(@"我的页", @"myPageCornerEnabled", @"bool", 0, 1),
               WCRItem(@"卡片阴影", @"cardShadowEnabled", @"bool", 0, 1),
        ] },
        @{ @"header": @"发现页卡片参数", @"items": @[
               WCRItem(@"圆角半径", @"globalCornerRadius", @"num", 2, 30),
               WCRItem(@"左右留白", @"globalCornerMargin", @"num", 0, 30),
        ] },
        @{ @"header": @"我的页卡片参数", @"items": @[
               WCRItem(@"圆角半径", @"myPageCornerRadius", @"num", 2, 40),
               WCRItem(@"左右留白", @"myPageCornerMargin", @"num", 0, 40),
        ] },
        @{ @"header": @"底部栏", @"items": @[
               WCRItem(@"悬浮胶囊 TabBar", @"floatingTabBarEnabled", @"bool", 0, 1),
        ] },
        @{ @"header": @"头像", @"items": @[
               WCRItem(@"头像圆角", @"avatarCornerEnabled", @"bool", 0, 1),
               WCRItem(@"圆角比例(%)", @"avatarCornerRadius", @"num", 10, 100),
               WCRItem(@"头像描边", @"avatarCornerBorderEnabled", @"bool", 0, 1),
               WCRItem(@"描边宽度", @"avatarCornerBorderSize", @"num", 0, 10),
        ] },
        @{ @"header": @"菜单", @"items": @[
               WCRItem(@"菜单圆角", @"menuCornerEnabled", @"bool", 0, 1),
               WCRItem(@"菜单圆角半径", @"menuCornerRadius", @"num", 0, 30),
               WCRItem(@"加号菜单圆角", @"plusMenuCornerEnabled", @"bool", 0, 1),
               WCRItem(@"菜单宽度", @"menuWidth", @"num", 0, 400),
        ] },
        @{ @"header": @"资料卡", @"items": @[
               WCRItem(@"资料卡圆角", @"profileCornerEnabled", @"bool", 0, 1),
               WCRItem(@"卡片美化", @"profileCardBeautifyEnabled", @"bool", 0, 1),
               WCRItem(@"卡片圆角半径", @"profileCornerRadius", @"num", 0, 30),
               WCRItem(@"卡片透明度", @"profileCardCardAlpha", @"num", 0, 1),
        ] },
    ];

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
    id value = [[WCRConfig shared] objectForKey:key def:nil];
    if (!value) return NO;
    return [value boolValue];
}

- (double)numberValueForKey:(NSString *)key item:(NSDictionary *)item {
    id value = [[WCRConfig shared] objectForKey:key def:nil];
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
    if (section == (NSInteger)self.sections.count - 1) {
        return @"改动即时生效；个别项目需重新进入页面才会体现。";
    }
    return nil;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)ip {
    NSInteger n = [tv numberOfRowsInSection:ip.section];
    cell.backgroundColor = [UIColor clearColor];
    UIView *card = [UIView new];
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor]; }];
    card.layer.cornerRadius = 26;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    CACornerMask m = 0;
    if (ip.row == 0) m |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (ip.row == n - 1) m |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    card.layer.maskedCorners = m;
    UIView *host = [UIView new];
    [host addSubview:card];
    card.frame = CGRectMake(16, 0, tv.bounds.size.width - 32, cell.bounds.size.height);
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    cell.backgroundView = host;
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

    if ([item[@"kind"] isEqualToString:@"bool"]) {
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
