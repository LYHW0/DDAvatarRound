#import "L63Strings.h"
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
    return @{ L63Decode(0): title, L63Decode(1): L63Decode(2), L63Decode(3): items };
}

static NSDictionary *LYHWItem(NSString *title, NSString *key, NSString *kind,
                             double minValue, double maxValue) {
    return @{ L63Decode(0): title, L63Decode(4): key, L63Decode(1): kind,
              L63Decode(5): @(minValue), L63Decode(6): @(maxValue) };
}

// 按图1的“页面入口 → 页面设置”组织重复的开关/半径/边框项目。
static void LYHWAddCornerGroup(NSMutableArray *a, NSString *title, NSString *prefix, BOOL border) {
    [a addObject:LYHWItem([title stringByAppendingString:L63Decode(7)], [prefix stringByAppendingString:L63Decode(8)], L63Decode(9), 0, 1)];
    [a addObject:LYHWItem([title stringByAppendingString:L63Decode(10)], [prefix stringByAppendingString:L63Decode(11)], L63Decode(12), 0, 60)];
    if (border) [a addObject:LYHWItem([title stringByAppendingString:L63Decode(13)], [prefix stringByAppendingString:L63Decode(14)], L63Decode(12), 0, 6)];
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

    self.title = self.pageTitle ?: L63Decode(15);
    self.tableView.rowHeight = 52.0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    if (self.sections) return;
    // 一级菜单按页面分类，结构仿照用户提供的图1；你的页脚和配置管理保留。
    #define P(t, ...) LYHWPageWithItems(t, @[__VA_ARGS__])
    NSMutableArray *chat = [NSMutableArray array];
    [chat addObject:LYHWItem(L63Decode(16), L63Decode(17), L63Decode(9), 0, 1)];
    [chat addObject:LYHWItem(L63Decode(18), L63Decode(19), L63Decode(12), 0, 30)];
    [chat addObject:LYHWItem(L63Decode(20), L63Decode(21), L63Decode(9), 0, 1)];
    [chat addObject:LYHWItem(L63Decode(22), L63Decode(23), L63Decode(12), 0, 80)];
    [chat addObject:LYHWItem(L63Decode(24), L63Decode(25), L63Decode(9), 0, 1)];
    [chat addObject:LYHWItem(L63Decode(26), L63Decode(27), L63Decode(12), 0, 40)];
    LYHWAddCornerGroup(chat, L63Decode(28), L63Decode(29), YES);
    LYHWAddCornerGroup(chat, L63Decode(30), L63Decode(31), YES);
    LYHWAddCornerGroup(chat, L63Decode(32), L63Decode(33), YES);
    LYHWAddCornerGroup(chat, L63Decode(34), L63Decode(35), YES);
    LYHWAddCornerGroup(chat, L63Decode(36), L63Decode(37), YES);
    LYHWAddCornerGroup(chat, L63Decode(38), L63Decode(39), YES);
    LYHWAddCornerGroup(chat, L63Decode(40), L63Decode(41), YES);
    LYHWAddCornerGroup(chat, L63Decode(42), L63Decode(43), YES);
    LYHWAddCornerGroup(chat, L63Decode(44), L63Decode(45), YES);
    LYHWAddCornerGroup(chat, L63Decode(46), L63Decode(47), YES);
    LYHWAddCornerGroup(chat, L63Decode(48), L63Decode(49), YES);
    LYHWAddCornerGroup(chat, L63Decode(50), L63Decode(51), YES);
    LYHWAddCornerGroup(chat, L63Decode(52), L63Decode(53), YES);
    LYHWAddCornerGroup(chat, L63Decode(54), L63Decode(55), YES);

    NSMutableArray *content = [NSMutableArray array];
    LYHWAddCornerGroup(content, L63Decode(56), L63Decode(57), YES);
    LYHWAddCornerGroup(content, L63Decode(58), L63Decode(59), YES);
    LYHWAddCornerGroup(content, L63Decode(60), L63Decode(61), YES);
    LYHWAddCornerGroup(content, L63Decode(62), L63Decode(63), YES);
    LYHWAddCornerGroup(content, L63Decode(64), L63Decode(65), YES);

    NSMutableArray *service = [NSMutableArray array];
    LYHWAddCornerGroup(service, L63Decode(66), L63Decode(67), YES);

    NSArray *pages = @[
        P(L63Decode(68), LYHWItem(L63Decode(69), L63Decode(70), L63Decode(9), 0, 1),
                      LYHWItem(L63Decode(71), L63Decode(72), L63Decode(9), 0, 1),
                      LYHWItem(L63Decode(73), L63Decode(74), L63Decode(9), 0, 1)),
        P(L63Decode(75), LYHWItem(L63Decode(76), L63Decode(77), L63Decode(9), 0, 1),
                      LYHWItem(L63Decode(78), L63Decode(79), L63Decode(9), 0, 1),
                      LYHWItem(L63Decode(80), L63Decode(81), L63Decode(9), 0, 1),
                      LYHWItem(L63Decode(82), L63Decode(83), L63Decode(12), 0, 1),
                      LYHWItem(L63Decode(84), L63Decode(85), L63Decode(9), 0, 1),
                      LYHWItem(L63Decode(86), L63Decode(87), L63Decode(12), 0, 30)),
        P(L63Decode(88), LYHWItem(L63Decode(76), L63Decode(89), L63Decode(9), 0, 1)),
        P(L63Decode(90), LYHWItem(L63Decode(76), L63Decode(91), L63Decode(9), 0, 1),
                     LYHWItem(L63Decode(92), L63Decode(93), L63Decode(12), 2, 30),
                     LYHWItem(L63Decode(94), L63Decode(95), L63Decode(12), 0, 30),
                     LYHWItem(L63Decode(96), L63Decode(97), L63Decode(9), 0, 1)),
        P(L63Decode(98), LYHWItem(L63Decode(76), L63Decode(99), L63Decode(9), 0, 1),
                      LYHWItem(L63Decode(92), L63Decode(100), L63Decode(12), 2, 40),
                      LYHWItem(L63Decode(94), L63Decode(101), L63Decode(12), 0, 40)),
        P(L63Decode(102), LYHWItem(L63Decode(76), L63Decode(103), L63Decode(9), 0, 1),
                        LYHWItem(L63Decode(92), L63Decode(104), L63Decode(12), 0, 60),
                        LYHWItem(L63Decode(94), L63Decode(105), L63Decode(12), 0, 40)),
        P(L63Decode(106), LYHWItem(L63Decode(107), L63Decode(108), L63Decode(9), 0, 1),
                       LYHWItem(L63Decode(92), L63Decode(109), L63Decode(12), 0, 60),
                       LYHWItem(L63Decode(94), L63Decode(110), L63Decode(12), 0, 40)),
        P(L63Decode(111), LYHWItem(L63Decode(112), L63Decode(113), L63Decode(9), 0, 1),
                         LYHWItem(L63Decode(92), L63Decode(114), L63Decode(12), 0, 60),
                         LYHWItem(L63Decode(94), L63Decode(115), L63Decode(12), 0, 40)),
        P(L63Decode(116), LYHWItem(L63Decode(117), L63Decode(118), L63Decode(9), 0, 1),
                         LYHWItem(L63Decode(92), L63Decode(119), L63Decode(12), 0, 60),
                         LYHWItem(L63Decode(94), L63Decode(120), L63Decode(12), 0, 40)),
        LYHWPageWithItems(L63Decode(121), chat),
        P(L63Decode(122), LYHWItem(L63Decode(123), L63Decode(124), L63Decode(9), 0, 1),
                       LYHWItem(L63Decode(125), L63Decode(126), L63Decode(12), 2, 40),
                       LYHWItem(L63Decode(127), L63Decode(128), L63Decode(9), 0, 1),
                       LYHWItem(L63Decode(129), L63Decode(130), L63Decode(12), 2, 40),
                       LYHWItem(L63Decode(131), L63Decode(132), L63Decode(9), 0, 1),
                       LYHWItem(L63Decode(133), L63Decode(134), L63Decode(12), 2, 30)),
        LYHWPageWithItems(L63Decode(135), content),
        LYHWPageWithItems(L63Decode(136), service),
        P(L63Decode(137), LYHWItem(L63Decode(137), L63Decode(138), L63Decode(9), 0, 1),
                     LYHWItem(L63Decode(139), L63Decode(140), L63Decode(12), 10, 100))
    ];
    #undef P
    self.sections = @[ @{ L63Decode(141): L63Decode(15), L63Decode(3): pages },
                       @{ L63Decode(141): L63Decode(142), L63Decode(3): @[
                           @{ L63Decode(0): L63Decode(143), L63Decode(1): L63Decode(144), L63Decode(144): L63Decode(145) },
                           @{ L63Decode(0): L63Decode(146), L63Decode(1): L63Decode(144), L63Decode(144): L63Decode(147) } ] } ];

    if (!self.pageTitle) {
        UILabel *by = [UILabel new];
        by.text = L63Decode(148);
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
    NSArray *items = section[L63Decode(3)];
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
    return MAX([item[L63Decode(5)] doubleValue], MIN([item[L63Decode(6)] doubleValue], v));
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
    return (NSInteger)[self.sections[(NSUInteger)section][L63Decode(3)] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[(NSUInteger)section][L63Decode(141)];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ([self.pageTitle isEqualToString:L63Decode(68)] && section == 0) {
        return L63Decode(149);
    }
    if ([self.pageTitle isEqualToString:L63Decode(68)] && section == 1) {
        return L63Decode(150);
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
    cell.textLabel.text = item[L63Decode(0)];

    if ([item[L63Decode(1)] isEqualToString:L63Decode(151)]) {
        LYHWSpeedMenuItem *speedItem = [LYHWSpeedMenuItem uiSpeedItem];
        UITableViewCell *speedCell = [LYHWSpeedCellFactory cellForItem:speedItem target:self action:@selector(hb_speedCellTapped)];
        speedCell.textLabel.textColor = [UIColor labelColor];
        return speedCell;
    }
    if ([item[L63Decode(1)] isEqualToString:L63Decode(2)] || [item[L63Decode(1)] isEqualToString:L63Decode(144)]) {
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if ([item[L63Decode(1)] isEqualToString:L63Decode(9)]) {
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = [self boolValueForKey:item[L63Decode(4)]];
        objc_setAssociatedObject(toggle, @selector(commitValue:forKey:),
                                 indexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.detailTextLabel.text = nil;
    } else {
        double value = [self numberValueForKey:item[L63Decode(4)] item:item];
        cell.detailTextLabel.text = [NSString stringWithFormat:L63Decode(152), value];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = [self itemAtIndexPath:indexPath];
    if ([item[L63Decode(1)] isEqualToString:L63Decode(2)]) {
        LYHWPluginSettingsViewController *sub = [[LYHWPluginSettingsViewController alloc] init];
        sub.pageTitle = item[L63Decode(0)];
        if ([item[L63Decode(0)] isEqualToString:L63Decode(68)]) {
            NSArray *items = item[L63Decode(3)];
            sub.sections = @[
                @{ L63Decode(141): L63Decode(153), L63Decode(3): @[items.firstObject] },
                @{ L63Decode(141): L63Decode(153), L63Decode(3): [items subarrayWithRange:NSMakeRange(1, items.count - 1)] }
            ];
        } else {
            sub.sections = @[ @{ L63Decode(141): item[L63Decode(0)], L63Decode(3): item[L63Decode(3)] } ];
        }
        [self.navigationController pushViewController:sub animated:YES];
        return;
    }
    if ([item[L63Decode(1)] isEqualToString:L63Decode(151)]) {
        LYHWSpeedMenuItem *speedItem = [LYHWSpeedMenuItem uiSpeedItem];
        [LYHWSpeedAlert showEditorFrom:self item:speedItem onChanged:^(__unused float v) { [self.tableView reloadData]; }];
        return;
    }
    if ([item[L63Decode(1)] isEqualToString:L63Decode(144)]) {
        if ([item[L63Decode(144)] isEqualToString:L63Decode(145)]) [self exportConfig];
        else [self importConfig];
        return;
    }
    if (![item[L63Decode(1)] isEqualToString:L63Decode(12)]) return;

    double current = [self numberValueForKey:item[L63Decode(4)] item:item];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:item[L63Decode(0)]
                                            message:[NSString stringWithFormat:L63Decode(154),
                                                     [item[L63Decode(5)] doubleValue], [item[L63Decode(6)] doubleValue]]
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeDecimalPad;
        field.text = [NSString stringWithFormat:L63Decode(152), current];
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:L63Decode(155) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:L63Decode(156) style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text ?: @"";
        double value = [text doubleValue];
        value = MAX([item[L63Decode(5)] doubleValue], MIN([item[L63Decode(6)] doubleValue], value));
        [weakSelf commitValue:@(value) forKey:item[L63Decode(4)]];
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
    @try { t = [sender valueForKey:L63Decode(157)]; } @catch (__unused id e) {}
    LYHWSetUISpeed((float)t.floatValue);
    [LYHWSpeedAlert showRestartPromptFrom:self item:[LYHWSpeedMenuItem uiSpeedItem]];
}

- (void)toast:(NSString *)title msg:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:L63Decode(158) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)exportConfig {
    NSDictionary *d = [[LYHWConfig shared] exportAll];
    NSData *data = [NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted error:nil];
    if (!data) { [self toast:L63Decode(159) msg:L63Decode(160)]; return; }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [UIPasteboard generalPasteboard].string = json;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:L63Decode(161)];
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
        [self toast:L63Decode(162) msg:L63Decode(163)];
        return;
    }
    __weak typeof(self) ws = self;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:L63Decode(146)
        message:[NSString stringWithFormat:L63Decode(164), (unsigned long)[obj count]]
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:L63Decode(155) style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:L63Decode(165) style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSInteger n = [[LYHWConfig shared] importAll:obj];
        [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification object:nil];
        [ws.tableView reloadData];
        [ws toast:L63Decode(166) msg:[NSString stringWithFormat:L63Decode(167), (long)n]];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)toggleChanged:(UISwitch *)sender {
    NSIndexPath *indexPath = objc_getAssociatedObject(sender, @selector(commitValue:forKey:));
    if (!indexPath) return;
    NSDictionary *item = [self itemAtIndexPath:indexPath];
    [self commitValue:@(sender.on) forKey:item[L63Decode(4)]];
}

@end
