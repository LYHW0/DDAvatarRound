#import "L62Strings.h"
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
    return @{ L62Decode(0): title, L62Decode(1): L62Decode(2), L62Decode(3): items };
}

static NSDictionary *LYHWItem(NSString *title, NSString *key, NSString *kind,
                             double minValue, double maxValue) {
    return @{ L62Decode(0): title, L62Decode(4): key, L62Decode(1): kind,
              L62Decode(5): @(minValue), L62Decode(6): @(maxValue) };
}

// 按图1的“页面入口 → 页面设置”组织重复的开关/半径/边框项目。
static void LYHWAddCornerGroup(NSMutableArray *a, NSString *title, NSString *prefix, BOOL border) {
    [a addObject:LYHWItem([title stringByAppendingString:L62Decode(7)], [prefix stringByAppendingString:L62Decode(8)], L62Decode(9), 0, 1)];
    [a addObject:LYHWItem([title stringByAppendingString:L62Decode(10)], [prefix stringByAppendingString:L62Decode(11)], L62Decode(12), 0, 60)];
    if (border) [a addObject:LYHWItem([title stringByAppendingString:L62Decode(13)], [prefix stringByAppendingString:L62Decode(14)], L62Decode(12), 0, 6)];
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

    self.title = self.pageTitle ?: L62Decode(15);
    self.tableView.rowHeight = 52.0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    if (self.sections) return;
    // 一级菜单按页面分类，结构仿照用户提供的图1；你的页脚和配置管理保留。
    #define P(t, ...) LYHWPageWithItems(t, @[__VA_ARGS__])
    NSMutableArray *chat = [NSMutableArray array];
    [chat addObject:LYHWItem(L62Decode(16), L62Decode(17), L62Decode(9), 0, 1)];
    [chat addObject:LYHWItem(L62Decode(18), L62Decode(19), L62Decode(12), 0, 30)];
    [chat addObject:LYHWItem(L62Decode(20), L62Decode(21), L62Decode(9), 0, 1)];
    [chat addObject:LYHWItem(L62Decode(22), L62Decode(23), L62Decode(12), 0, 80)];
    [chat addObject:LYHWItem(L62Decode(24), L62Decode(25), L62Decode(9), 0, 1)];
    [chat addObject:LYHWItem(L62Decode(26), L62Decode(27), L62Decode(12), 0, 40)];
    LYHWAddCornerGroup(chat, L62Decode(28), L62Decode(29), YES);
    LYHWAddCornerGroup(chat, L62Decode(30), L62Decode(31), YES);
    LYHWAddCornerGroup(chat, L62Decode(32), L62Decode(33), YES);
    LYHWAddCornerGroup(chat, L62Decode(34), L62Decode(35), YES);
    LYHWAddCornerGroup(chat, L62Decode(36), L62Decode(37), YES);
    LYHWAddCornerGroup(chat, L62Decode(38), L62Decode(39), YES);
    LYHWAddCornerGroup(chat, L62Decode(40), L62Decode(41), YES);
    LYHWAddCornerGroup(chat, L62Decode(42), L62Decode(43), YES);
    LYHWAddCornerGroup(chat, L62Decode(44), L62Decode(45), YES);
    LYHWAddCornerGroup(chat, L62Decode(46), L62Decode(47), YES);
    LYHWAddCornerGroup(chat, L62Decode(48), L62Decode(49), YES);
    LYHWAddCornerGroup(chat, L62Decode(50), L62Decode(51), YES);
    LYHWAddCornerGroup(chat, L62Decode(52), L62Decode(53), YES);
    LYHWAddCornerGroup(chat, L62Decode(54), L62Decode(55), YES);

    NSMutableArray *content = [NSMutableArray array];
    LYHWAddCornerGroup(content, L62Decode(56), L62Decode(57), YES);
    LYHWAddCornerGroup(content, L62Decode(58), L62Decode(59), YES);
    LYHWAddCornerGroup(content, L62Decode(60), L62Decode(61), YES);
    LYHWAddCornerGroup(content, L62Decode(62), L62Decode(63), YES);
    LYHWAddCornerGroup(content, L62Decode(64), L62Decode(65), YES);

    NSMutableArray *service = [NSMutableArray array];
    LYHWAddCornerGroup(service, L62Decode(66), L62Decode(67), YES);

    NSArray *pages = @[
        P(L62Decode(68), LYHWItem(L62Decode(69), L62Decode(70), L62Decode(9), 0, 1),
                      LYHWItem(L62Decode(71), L62Decode(72), L62Decode(9), 0, 1),
                      LYHWItem(L62Decode(73), L62Decode(74), L62Decode(9), 0, 1)),
        P(L62Decode(75), LYHWItem(L62Decode(76), L62Decode(77), L62Decode(9), 0, 1),
                      LYHWItem(L62Decode(78), L62Decode(79), L62Decode(9), 0, 1),
                      LYHWItem(L62Decode(80), L62Decode(81), L62Decode(9), 0, 1),
                      LYHWItem(L62Decode(82), L62Decode(83), L62Decode(12), 0, 1),
                      LYHWItem(L62Decode(84), L62Decode(85), L62Decode(9), 0, 1),
                      LYHWItem(L62Decode(86), L62Decode(87), L62Decode(12), 0, 30)),
        P(L62Decode(88), LYHWItem(L62Decode(76), L62Decode(89), L62Decode(9), 0, 1)),
        P(L62Decode(90), LYHWItem(L62Decode(76), L62Decode(91), L62Decode(9), 0, 1),
                     LYHWItem(L62Decode(92), L62Decode(93), L62Decode(12), 2, 30),
                     LYHWItem(L62Decode(94), L62Decode(95), L62Decode(12), 0, 30),
                     LYHWItem(L62Decode(96), L62Decode(97), L62Decode(9), 0, 1)),
        P(L62Decode(98), LYHWItem(L62Decode(76), L62Decode(99), L62Decode(9), 0, 1),
                      LYHWItem(L62Decode(92), L62Decode(100), L62Decode(12), 2, 40),
                      LYHWItem(L62Decode(94), L62Decode(101), L62Decode(12), 0, 40)),
        P(L62Decode(102), LYHWItem(L62Decode(76), L62Decode(103), L62Decode(9), 0, 1),
                        LYHWItem(L62Decode(92), L62Decode(104), L62Decode(12), 0, 60),
                        LYHWItem(L62Decode(94), L62Decode(105), L62Decode(12), 0, 40)),
        P(L62Decode(106), LYHWItem(L62Decode(107), L62Decode(108), L62Decode(9), 0, 1),
                       LYHWItem(L62Decode(92), L62Decode(109), L62Decode(12), 0, 60),
                       LYHWItem(L62Decode(94), L62Decode(110), L62Decode(12), 0, 40)),
        P(L62Decode(111), LYHWItem(L62Decode(112), L62Decode(113), L62Decode(9), 0, 1),
                         LYHWItem(L62Decode(92), L62Decode(114), L62Decode(12), 0, 60),
                         LYHWItem(L62Decode(94), L62Decode(115), L62Decode(12), 0, 40)),
        P(L62Decode(116), LYHWItem(L62Decode(117), L62Decode(118), L62Decode(9), 0, 1),
                         LYHWItem(L62Decode(92), L62Decode(119), L62Decode(12), 0, 60),
                         LYHWItem(L62Decode(94), L62Decode(120), L62Decode(12), 0, 40)),
        LYHWPageWithItems(L62Decode(121), chat),
        P(L62Decode(122), LYHWItem(L62Decode(123), L62Decode(124), L62Decode(9), 0, 1),
                       LYHWItem(L62Decode(125), L62Decode(126), L62Decode(12), 2, 40),
                       LYHWItem(L62Decode(127), L62Decode(128), L62Decode(9), 0, 1),
                       LYHWItem(L62Decode(129), L62Decode(130), L62Decode(12), 2, 40),
                       LYHWItem(L62Decode(131), L62Decode(132), L62Decode(9), 0, 1),
                       LYHWItem(L62Decode(133), L62Decode(134), L62Decode(12), 2, 30)),
        LYHWPageWithItems(L62Decode(135), content),
        LYHWPageWithItems(L62Decode(136), service),
        P(L62Decode(137), LYHWItem(L62Decode(137), L62Decode(138), L62Decode(9), 0, 1),
                     LYHWItem(L62Decode(139), L62Decode(140), L62Decode(12), 10, 100))
    ];
    #undef P
    self.sections = @[ @{ L62Decode(141): L62Decode(15), L62Decode(3): pages },
                       @{ L62Decode(141): L62Decode(142), L62Decode(3): @[
                           @{ L62Decode(0): L62Decode(143), L62Decode(1): L62Decode(144), L62Decode(144): L62Decode(145) },
                           @{ L62Decode(0): L62Decode(146), L62Decode(1): L62Decode(144), L62Decode(144): L62Decode(147) } ] } ];

    if (!self.pageTitle) {
        UILabel *by = [UILabel new];
        by.text = L62Decode(148);
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
    NSArray *items = section[L62Decode(3)];
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
    return MAX([item[L62Decode(5)] doubleValue], MIN([item[L62Decode(6)] doubleValue], v));
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
    return (NSInteger)[self.sections[(NSUInteger)section][L62Decode(3)] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[(NSUInteger)section][L62Decode(141)];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ([self.pageTitle isEqualToString:L62Decode(68)] && section == 0) {
        return L62Decode(149);
    }
    if ([self.pageTitle isEqualToString:L62Decode(68)] && section == 1) {
        return L62Decode(150);
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
    cell.textLabel.text = item[L62Decode(0)];

    if ([item[L62Decode(1)] isEqualToString:L62Decode(151)]) {
        LYHWSpeedMenuItem *speedItem = [LYHWSpeedMenuItem uiSpeedItem];
        UITableViewCell *speedCell = [LYHWSpeedCellFactory cellForItem:speedItem target:self action:@selector(hb_speedCellTapped)];
        speedCell.textLabel.textColor = [UIColor labelColor];
        return speedCell;
    }
    if ([item[L62Decode(1)] isEqualToString:L62Decode(2)] || [item[L62Decode(1)] isEqualToString:L62Decode(144)]) {
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if ([item[L62Decode(1)] isEqualToString:L62Decode(9)]) {
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = [self boolValueForKey:item[L62Decode(4)]];
        objc_setAssociatedObject(toggle, @selector(commitValue:forKey:),
                                 indexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.detailTextLabel.text = nil;
    } else {
        double value = [self numberValueForKey:item[L62Decode(4)] item:item];
        cell.detailTextLabel.text = [NSString stringWithFormat:L62Decode(152), value];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = [self itemAtIndexPath:indexPath];
    if ([item[L62Decode(1)] isEqualToString:L62Decode(2)]) {
        LYHWPluginSettingsViewController *sub = [[LYHWPluginSettingsViewController alloc] init];
        sub.pageTitle = item[L62Decode(0)];
        if ([item[L62Decode(0)] isEqualToString:L62Decode(68)]) {
            NSArray *items = item[L62Decode(3)];
            sub.sections = @[
                @{ L62Decode(141): L62Decode(153), L62Decode(3): @[items.firstObject] },
                @{ L62Decode(141): L62Decode(153), L62Decode(3): [items subarrayWithRange:NSMakeRange(1, items.count - 1)] }
            ];
        } else {
            sub.sections = @[ @{ L62Decode(141): item[L62Decode(0)], L62Decode(3): item[L62Decode(3)] } ];
        }
        [self.navigationController pushViewController:sub animated:YES];
        return;
    }
    if ([item[L62Decode(1)] isEqualToString:L62Decode(151)]) {
        LYHWSpeedMenuItem *speedItem = [LYHWSpeedMenuItem uiSpeedItem];
        [LYHWSpeedAlert showEditorFrom:self item:speedItem onChanged:^(__unused float v) { [self.tableView reloadData]; }];
        return;
    }
    if ([item[L62Decode(1)] isEqualToString:L62Decode(144)]) {
        if ([item[L62Decode(144)] isEqualToString:L62Decode(145)]) [self exportConfig];
        else [self importConfig];
        return;
    }
    if (![item[L62Decode(1)] isEqualToString:L62Decode(12)]) return;

    double current = [self numberValueForKey:item[L62Decode(4)] item:item];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:item[L62Decode(0)]
                                            message:[NSString stringWithFormat:L62Decode(154),
                                                     [item[L62Decode(5)] doubleValue], [item[L62Decode(6)] doubleValue]]
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeDecimalPad;
        field.text = [NSString stringWithFormat:L62Decode(152), current];
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:L62Decode(155) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:L62Decode(156) style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text ?: @"";
        double value = [text doubleValue];
        value = MAX([item[L62Decode(5)] doubleValue], MIN([item[L62Decode(6)] doubleValue], value));
        [weakSelf commitValue:@(value) forKey:item[L62Decode(4)]];
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
    @try { t = [sender valueForKey:L62Decode(157)]; } @catch (__unused id e) {}
    LYHWSetUISpeed((float)t.floatValue);
    [LYHWSpeedAlert showRestartPromptFrom:self item:[LYHWSpeedMenuItem uiSpeedItem]];
}

- (void)toast:(NSString *)title msg:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:L62Decode(158) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)exportConfig {
    NSDictionary *d = [[LYHWConfig shared] exportAll];
    NSData *data = [NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted error:nil];
    if (!data) { [self toast:L62Decode(159) msg:L62Decode(160)]; return; }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [UIPasteboard generalPasteboard].string = json;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:L62Decode(161)];
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
        [self toast:L62Decode(162) msg:L62Decode(163)];
        return;
    }
    __weak typeof(self) ws = self;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:L62Decode(146)
        message:[NSString stringWithFormat:L62Decode(164), (unsigned long)[obj count]]
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:L62Decode(155) style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:L62Decode(165) style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSInteger n = [[LYHWConfig shared] importAll:obj];
        [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification object:nil];
        [ws.tableView reloadData];
        [ws toast:L62Decode(166) msg:[NSString stringWithFormat:L62Decode(167), (long)n]];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)toggleChanged:(UISwitch *)sender {
    NSIndexPath *indexPath = objc_getAssociatedObject(sender, @selector(commitValue:forKey:));
    if (!indexPath) return;
    NSDictionary *item = [self itemAtIndexPath:indexPath];
    [self commitValue:@(sender.on) forKey:item[L62Decode(4)]];
}

@end
