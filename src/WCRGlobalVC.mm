//
//  WCRGlobalVC.mm
//  子页面「主页全局圆角」—— WCRefineGlobalCornerSettingsViewController 的完整复刻
//
//  逆向自 reloadTableData(4,912 字节):一个 section「全局圆角」,
//  含 6 个页面开关 + 一整套通用参数(圆角/边距/间距/置顶上下间距/背景色/
//  描边大小/描边颜色/描边样式/置顶透明),外加「禁用页面」自行添加列表。
//

#import "WCRCorner.h"

static inline WCRCornerConfig *Cfg(void) { return [WCRCornerConfig shared]; }

#pragma mark - 禁用页面列表(对应 openCustomExcludedGlobalCornerPagesSheet)

@interface WCRExcludedPagesViewController : UITableViewController
@end

@implementation WCRExcludedPagesViewController {
    NSMutableArray<NSString *> *_items;
}

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        NSString *raw = [Cfg() globalCornerCustomExcludedVCClassNames];
        _items = raw.length ? [[raw componentsSeparatedByString:@","] mutableCopy] : [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"禁用页面";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self
                                                      action:@selector(addPage)];
}

- (void)addPage {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"添加 VC 类名"
                                                              message:@"例如：WCRefineCornerViewController"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"VC 类名";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSString *name = [a.textFields.firstObject.text
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (name.length && ![self->_items containsObject:name]) {
            [self->_items addObject:name];
            [self save];
        }
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)save {
    [Cfg() setGlobalCornerCustomExcludedVCClassNames:[_items componentsJoinedByString:@","]];
    [Cfg() notifyChanged];
    [[NSNotificationCenter defaultCenter] postNotificationName:WCRCornerSettingsChangedNotification object:nil];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    c.textLabel.text = _items[(NSUInteger)indexPath.row];
    c.textLabel.font = [UIFont systemFontOfSize:15];
    return c;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_items removeObjectAtIndex:(NSUInteger)indexPath.row];
        [self save];
    }
}

@end

#pragma mark - 全局圆角

@interface WCRGlobalCornerViewController ()
@property (nonatomic, strong) UIImpactFeedbackGenerator *hapticGenerator;
@end

@implementation WCRGlobalCornerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"全局圆角";
    self.hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    self.tableView.backgroundColor = [UIColor clearColor];
    [self reloadTableData];
}

- (void)triggerHapticFeedback {
    [self.hapticGenerator prepare];
    [self.hapticGenerator impactOccurred];
}

#pragma mark 行构造

- (WCRTableRow *)switchRow:(NSString *)title key:(NSString *)key {
    BOOL on = [[Cfg() valueForKey:key] boolValue];
    __weak __typeof__(self) weakSelf = self;
    return [WCRTableRow switchRow:title on:on action:^(BOOL isOn) {
        __strong __typeof__(weakSelf) self = weakSelf;
        [Cfg() setValue:@(isOn) forKey:key];
        [Cfg() notifyChanged];
        [self reloadTableData];
    }];
}

- (WCRTableRow *)valueRow:(NSString *)title
                     key:(NSString *)key
                  format:(NSString *)format
                 isFloat:(BOOL)isFloat
                    hint:(NSString *)hint
                     min:(double)minV
                     max:(double)maxV {
    id cur = [Cfg() valueForKey:key];
    NSString *text = isFloat ? [NSString stringWithFormat:format, [cur doubleValue]]
                             : [NSString stringWithFormat:format, (long)[cur integerValue]];
    __weak __typeof__(self) weakSelf = self;
    return [WCRTableRow valueRow:title value:text action:^{
        __strong __typeof__(weakSelf) self = weakSelf;
        [self triggerHapticFeedback];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"设置%@", title]
                                                                  message:hint
                                                           preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.text = text;
            tf.keyboardType = isFloat ? UIKeyboardTypeDecimalPad : UIKeyboardTypeNumberPad;
        }];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            NSString *raw = a.textFields.firstObject.text ?: @"";
            double v = isFloat ? raw.doubleValue : (double)raw.integerValue;
            if (v < minV) v = minV;
            if (v > maxV) v = maxV;
            [Cfg() setValue:(isFloat ? @(v) : @((NSInteger)v)) forKey:key];
            [Cfg() notifyChanged];
            [self reloadTableData];
        }]];
        [self presentViewController:a animated:YES completion:nil];
    }];
}

- (WCRTableRow *)colorRow:(NSString *)title base:(NSString *)base {
    UIView *dot = [UIView new];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = [Cfg() valueForKey:[base stringByAppendingString:@"Light"]];
    dot.layer.cornerRadius = 9;
    dot.layer.borderWidth = 1;
    dot.layer.borderColor = [UIColor separatorColor].CGColor;
    [dot.widthAnchor constraintEqualToConstant:18].active = YES;
    [dot.heightAnchor constraintEqualToConstant:18].active = YES;

    __weak __typeof__(self) weakSelf = self;
    return [WCRTableRow accessoryRow:title rightView:dot action:^{
        __strong __typeof__(weakSelf) self = weakSelf;
        UIColor *l = [Cfg() valueForKey:[base stringByAppendingString:@"Light"]];
        UIColor *d = [Cfg() valueForKey:[base stringByAppendingString:@"Dark"]];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"选择%@", title]
                                                                  message:[NSString stringWithFormat:@"当前：%@", [WCRCornerConfig hexFromColor:l]]
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSNumber *hex in @[@0x000000, @0xFFFFFF, @0xF2F2F2, @0x8E8E93, @0xFF3B30, @0x007AFF, @0x34C759, @0xFFCC00]) {
            UIColor *c = [WCRCornerConfig colorFromHex:hex.unsignedIntegerValue];
            [a addAction:[UIAlertAction actionWithTitle:[WCRCornerConfig hexFromColor:c]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *x) {
                [Cfg() setValue:c forKey:[base stringByAppendingString:@"Light"]];
                // 深色版本自动取反相亮度,保持与原插件"浅/深成对"的机制
                CGFloat r, g, b, al;
                [c getRed:&r green:&g blue:&b alpha:&al];
                CGFloat lum = 0.299 * r + 0.587 * g + 0.114 * b;
                UIColor *dk = lum > 0.6 ? [UIColor blackColor] : [UIColor whiteColor];
                [Cfg() setValue:dk forKey:[base stringByAppendingString:@"Dark"]];
                [Cfg() notifyChanged];
                [self reloadTableData];
            }]];
        }
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }];
}

#pragma mark reloadTableData

- (WCRTableRow *)strokeStyleRow {
    NSInteger styleVal = [[Cfg() valueForKey:@"globalCornerStrokeStyle"] integerValue];
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"实线", @"虚线", @"点线"]];
    seg.selectedSegmentIndex = (styleVal < 0 || styleVal > 2) ? 0 : styleVal;
    seg.apportionsSegmentWidthsByContent = YES;
    [seg addTarget:self action:@selector(strokeStyleChanged:) forControlEvents:UIControlEventValueChanged];
    [seg.widthAnchor constraintEqualToConstant:150].active = YES;
    WCRTableRow *row = [WCRTableRow accessoryRow:@"描边样式" rightView:seg action:nil];
    return row;
}

- (void)strokeStyleChanged:(UISegmentedControl *)seg {
    [self triggerHapticFeedback];
    [Cfg() setValue:@(seg.selectedSegmentIndex) forKey:@"globalCornerStrokeStyle"];
    [Cfg() notifyChanged];
}

- (void)reloadTableData {
    [self.sections removeAllObjects];

    WCRTableSection *s = [WCRTableSection sectionWithHeader:@"全局圆角" footer:nil];

    // 顺序严格按原版 reloadTableData 的 cell 构造顺序
    [s addRow:[self switchRow:@"主页圆角" key:@"homepageCornerEnabled"]];
    [s addRow:[self switchRow:@"微信页面" key:@"mainFrameCornerEnabled"]];
    [s addRow:[self switchRow:@"我的页面" key:@"myPageCornerEnabled"]];
    [s addRow:[self switchRow:@"好友资料" key:@"friendProfileCornerEnabled"]];
    [s addRow:[self switchRow:@"发现页面" key:@"discoverPageCornerEnabled"]];

    // 「禁用页面」右侧是「未设置 / 已设置」(不是数字)
    NSInteger excluded = [Cfg() globalCornerCustomExcludedCount];
    __weak __typeof__(self) weakSelf = self;
    WCRTableRow *excludedRow = [WCRTableRow valueRow:@"禁用页面"
                                               value:(excluded > 0 ? @"已设置" : @"未设置")
                                              action:^{
        __strong __typeof__(weakSelf) self = weakSelf;
        [self triggerHapticFeedback];
        [self.navigationController pushViewController:[WCRExcludedPagesViewController new] animated:YES];
    }];
    [s addRow:excludedRow];

    [s addRow:[self switchRow:@"TP 模式" key:@"tpModeCornerEnabled"]];

    [s addRow:[self valueRow:@"圆角大小" key:@"globalCornerRadius" format:@"%ld" isFloat:NO
                        hint:@"设置全局圆角大小\n\n范围：0-50" min:0 max:50]];
    [s addRow:[self valueRow:@"边距大小" key:@"globalCornerMargin" format:@"%ld" isFloat:NO
                        hint:@"设置全局边距大小\n\n范围：0-100" min:0 max:100]];
    [s addRow:[self valueRow:@"间距大小" key:@"globalCornerSpacing" format:@"%ld" isFloat:NO
                        hint:@"设置全局间距大小\n\n范围：0-50" min:0 max:50]];
    [s addRow:[self valueRow:@"置顶上间距" key:@"mainFramePinnedTopSpacing" format:@"%ld" isFloat:NO
                        hint:@"设置搜索框与置顶聊天之间的间距\n\n范围：0-50" min:0 max:50]];
    [s addRow:[self valueRow:@"置顶下间距" key:@"mainFrameBelowPinnedSpacing" format:@"%ld" isFloat:NO
                        hint:@"设置置顶聊天与普通聊天之间的间距\n\n范围：0-50" min:0 max:50]];

    // 「间距一统」:开启前要过确认弹窗(原版 confirmEnableMainFrameSpacingUnify)
    BOOL unify = [[Cfg() valueForKey:@"mainFrameSpacingUnifyEnabled"] boolValue];
    WCRTableRow *unifyRow = [WCRTableRow switchRow:@"间距一统" on:unify action:^(BOOL isOn) {
        __strong __typeof__(weakSelf) self = weakSelf;
        [self triggerHapticFeedback];
        if (!isOn) {
            [Cfg() setValue:@NO forKey:@"mainFrameSpacingUnifyEnabled"];
            [Cfg() notifyChanged];
            [self reloadTableData];
            [self showRestartHint:@"已恢复默认间距模式\n本功能需要重启后方可生效"];
            return;
        }
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"WCRefine"
                                                                  message:@"此功能可能导致首页卡片故障\n若用首页卡片不建议开启\n是否确认开启？"
                                                           preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x) {
            [self reloadTableData];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"确认开启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
            [Cfg() setValue:@YES forKey:@"mainFrameSpacingUnifyEnabled"];
            [Cfg() notifyChanged];
            [self reloadTableData];
            [self showRestartHint:@"已开启间距一统\n本功能需要重启后方可生效"];
        }]];
        [self presentViewController:a animated:YES completion:nil];
    }];
    [s addRow:unifyRow];

    [s addRow:[self colorRow:@"背景颜色" base:@"globalCornerBackgroundColor"]];
    [s addRow:[self valueRow:@"描边大小" key:@"globalCornerStroke" format:@"%.1f" isFloat:YES
                        hint:@"设置全局描边大小\n\n范围：0.0-5.0" min:0 max:5]];
    [s addRow:[self colorRow:@"描边颜色" base:@"globalCornerStrokeColor"]];
    [s addRow:[self strokeStyleRow]];
    [s addRow:[self valueRow:@"置顶透明" key:@"globalCornerPinButtonV2" format:@"%.2f" isFloat:YES
                        hint:@"仅调整折叠置顶按钮背景透明度，文字和箭头保持不透明\n\n范围：0.0-1.0，0=全透明，1=不透明" min:0 max:1]];

    [self addSection:s];
    [self.tableView reloadData];
}

/// 原版统一弹窗:「重启后生效 / 稍后重启 / 立即重启」
- (void)showRestartHint:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"WCRefine"
                                                              message:message
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"稍后重启" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"立即重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        [self restartApp:nil];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

/// 对应 -restartApp:
- (void)restartApp:(id)sender {
    [self triggerHapticFeedback];
    exit(0);
}

@end
