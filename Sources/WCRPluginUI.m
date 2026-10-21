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
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"微信美化";
    self.tableView.rowHeight = 48.0;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.sections = @[
        @{ @"header": @"界面圆角", @"items": @[
               WCRItem(@"主页圆角", @"homepageCornerEnabled", @"bool", 0, 1),
               WCRItem(@"主框架卡片圆角", @"mainFrameCornerEnabled", @"bool", 0, 1),
               WCRItem(@"发现页圆角", @"discoverPageCornerEnabled", @"bool", 0, 1),
               WCRItem(@"我的页圆角", @"myPageCornerEnabled", @"bool", 0, 1),
               WCRItem(@"全局圆角半径", @"globalCornerRadius", @"num", 2, 30),
               WCRItem(@"卡片左右留白", @"globalCornerMargin", @"num", 0, 30),
               WCRItem(@"卡片间距", @"globalCornerSpacing", @"num", 0, 20),
        ] },
        @{ @"header": @"头像", @"items": @[
               WCRItem(@"头像圆角", @"avatarCornerEnabled", @"bool", 0, 1),
               WCRItem(@"圆角比例(%)", @"avatarCornerRadius", @"num", 10, 100),
               WCRItem(@"头像描边", @"avatarCornerBorderEnabled", @"bool", 0, 1),
               WCRItem(@"描边宽度", @"avatarCornerBorderSize", @"num", 0, 10),
        ] },
        @{ @"header": @"消息横幅", @"items": @[
               WCRItem(@"横幅美化", @"msgBannerBeautifyEnabled", @"bool", 0, 1),
               WCRItem(@"横幅宽度", @"msgBannerWidth", @"num", 0, 400),
               WCRItem(@"横幅高度", @"msgBannerHeight", @"num", 40, 120),
               WCRItem(@"横幅停留秒数", @"msgBannerStaySeconds", @"num", 1, 10),
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
