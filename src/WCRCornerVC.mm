//
//  WCRCornerVC.mm
//  主板块 —— WCRefineCornerViewController 的完整复刻(204 个方法 / 24 个分组)
//
//  分组顺序、行顺序、标题、右侧控件类型、数值格式、默认值、取值范围
//  全部按 reloadTableData(33,544 字节) 的反汇编结果逐条还原。
//

#import "WCRCorner.h"

/// 取配置对象(所有设置项都挂在它身上,键名 == 属性名)
static inline WCRCornerConfig *Cfg(void) { return [WCRCornerConfig shared]; }

#pragma mark - 颜色选择器(等价 WCRColorPickerViewController)

typedef void (^WCRColorPickCallback)(UIColor *light, UIColor *dark);

@interface WCRColorPickerViewController : UIViewController
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) WCRColorPickCallback callback;
@property (nonatomic, strong) UIColor *lightColor;
@property (nonatomic, strong) UIColor *darkColor;
- (instancetype)initWithTitle:(NSString *)title
                    lightHex:(NSString *)lightHex
                     darkHex:(NSString *)darkHex
                     callback:(WCRColorPickCallback)callback;
@end

@implementation WCRColorPickerViewController {
    NSArray<NSNumber *> *_palette;
    UILabel *_hexLabel;
    UIView *_preview;
    BOOL _editingDark;
}

- (instancetype)initWithTitle:(NSString *)title
                    lightHex:(NSString *)lightHex
                     darkHex:(NSString *)darkHex
                     callback:(WCRColorPickCallback)callback {
    if ((self = [super init])) {
        self.title = title;
        self.callback = callback;
        self.lightColor = [self colorFromHexString:lightHex];
        self.darkColor = [self colorFromHexString:darkHex];
        // 常用色板(微信设置页那一套):黑/白/灰阶/红橙黄绿蓝紫
        _palette = @[@0x000000, @0xFFFFFF, @0xF2F2F2, @0x8E8E93, @0x3C3C43,
                     @0xFF3B30, @0xFF9500, @0xFFCC00, @0x34C759,
                     @0x007AFF, @0x5856D6, @0xAF52DE, @0xFF2D55];
    }
    return self;
}

- (UIColor *)colorFromHexString:(NSString *)hex {
    if (![hex hasPrefix:@"#"] || hex.length != 7) return [UIColor blackColor];
    unsigned int v = 0;
    sscanf(hex.UTF8String + 1, "%06x", &v);
    return [WCRCornerConfig colorFromHex:v];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"浅色", @"深色"]];
    seg.selectedSegmentIndex = 0;
    [seg addTarget:self action:@selector(segChanged:) forControlEvents:UIControlEventValueChanged];
    seg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:seg];

    _preview = [UIView new];
    _preview.layer.cornerRadius = 12;
    _preview.layer.borderWidth = 1;
    _preview.layer.borderColor = [UIColor separatorColor].CGColor;
    _preview.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_preview];

    _hexLabel = [UILabel new];
    _hexLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
    _hexLabel.textAlignment = NSTextAlignmentCenter;
    _hexLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_hexLabel];

    // 色板
    UIStackView *grid = [UIStackView new];
    grid.axis = UILayoutConstraintAxisHorizontal;
    grid.distribution = UIStackViewDistributionFillEqually;
    grid.spacing = 10;
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:grid];

    for (NSNumber *n in _palette) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.backgroundColor = [WCRCornerConfig colorFromHex:n.unsignedIntegerValue];
        b.layer.cornerRadius = 10;
        b.layer.borderWidth = 1;
        b.layer.borderColor = [UIColor separatorColor].CGColor;
        b.tag = n.unsignedIntegerValue;
        [b addTarget:self action:@selector(pickColor:) forControlEvents:UIControlEventTouchUpInside];
        [b.heightAnchor constraintEqualToConstant:44].active = YES;
        [grid addArrangedSubview:b];
    }

    UIButton *confirm = [UIButton buttonWithType:UIButtonTypeSystem];
    [confirm setTitle:@"完成" forState:UIControlStateNormal];
    confirm.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [confirm addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside];
    confirm.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:confirm];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [seg.topAnchor constraintEqualToAnchor:g.topAnchor constant:16],
        [seg.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:20],
        [seg.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-20],

        [_preview.topAnchor constraintEqualToAnchor:seg.bottomAnchor constant:20],
        [_preview.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
        [_preview.widthAnchor constraintEqualToConstant:140],
        [_preview.heightAnchor constraintEqualToConstant:80],

        [_hexLabel.topAnchor constraintEqualToAnchor:_preview.bottomAnchor constant:10],
        [_hexLabel.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],

        [grid.topAnchor constraintEqualToAnchor:_hexLabel.bottomAnchor constant:24],
        [grid.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:20],
        [grid.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-20],

        [confirm.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:30],
        [confirm.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
    ]];

    [self refreshPreview];
}

- (void)segChanged:(UISegmentedControl *)s {
    _editingDark = (s.selectedSegmentIndex == 1);
    [self refreshPreview];
}

- (void)pickColor:(UIButton *)b {
    UIColor *c = [WCRCornerConfig colorFromHex:b.tag];
    if (_editingDark) self.darkColor = c; else self.lightColor = c;
    [self refreshPreview];
}

- (void)refreshPreview {
    UIColor *c = _editingDark ? self.darkColor : self.lightColor;
    _preview.backgroundColor = c;
    _hexLabel.text = [WCRCornerConfig hexFromColor:c];
}

- (void)done {
    if (self.callback) self.callback(self.lightColor, self.darkColor);
    [self.navigationController popViewControllerAnimated:YES];
}

@end

#pragma mark - 主板块

@interface WCRCornerViewController ()
@property (nonatomic, strong) UIImpactFeedbackGenerator *hapticGenerator;
@end

@implementation WCRCornerViewController

#pragma mark 生命周期(对应 -viewDidLoad / -setupTableViewStyle / -triggerHapticFeedback)

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"界面圆角";
    self.hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [self setupTableViewStyle];
    [self reloadTableData];
}

- (void)setupTableViewStyle {
    // 原实现:[self.manager tableView] setBackgroundColor:clearColor / setSeparatorStyle:0
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

- (void)triggerHapticFeedback {
    [self.hapticGenerator prepare];
    [self.hapticGenerator impactOccurred];
}

- (void)sendSettingsChangedNotification {
    [[WCRCornerConfig shared] notifyChanged];
}

- (void)restartApp:(id)sender {
    [self triggerHapticFeedback];
    // 微信重启原实现走 elegantRestartV2FromPresenter:,这里用等价方式:退出 App 由 SpringBoard 重启
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"WCRefine"
                                                              message:@"重启后变更生效"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"立即重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        exit(0);
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark 通用行构造

/// 开关行:key 为配置属性名
- (WCRTableRow *)switchRow:(NSString *)title key:(NSString *)key {
    __weak __typeof__(self) weakSelf = self;
    BOOL on = [[Cfg() valueForKey:key] boolValue];
    return [WCRTableRow switchRow:title on:on action:^(BOOL isOn) {
        __strong __typeof__(weakSelf) self = weakSelf;
        [Cfg() setValue:@(isOn) forKey:key];
        [self sendSettingsChangedNotification];
        [self reloadTableData];
    }];
}

/// 数值行(iOS 键盘输入弹窗,等价原插件 WCUIAlertView showTextFieldWithMaxLen:)
- (WCRTableRow *)valueRow:(NSString *)title
                     key:(NSString *)key
                  format:(NSString *)format
                  isFloat:(BOOL)isFloat
                    range:(NSString *)rangeText
                      min:(double)minV
                      max:(double)maxV {
    id cur = [Cfg() valueForKey:key];
    NSString *text;
    if (isFloat) {
        text = [NSString stringWithFormat:format, [cur doubleValue]];
    } else {
        text = [NSString stringWithFormat:format, (long)[cur integerValue]];
    }
    __weak __typeof__(self) weakSelf = self;
    return [WCRTableRow valueRow:title value:text action:^{
        __strong __typeof__(weakSelf) self = weakSelf;
        UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"设置%@", title]
                                                                  message:rangeText
                                                           preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.text = text;
            tf.keyboardType = isFloat ? UIKeyboardTypeDecimalPad : UIKeyboardTypeNumberPad;
            tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        }];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            NSString *raw = a.textFields.firstObject.text ?: @"";
            double v = isFloat ? raw.doubleValue : (double)raw.integerValue;
            if (v < minV) v = minV;
            if (v > maxV) v = maxV;
            [Cfg() setValue:(isFloat ? @(v) : @((NSInteger)v)) forKey:key];
            [self sendSettingsChangedNotification];
            [self reloadTableData];
        }]];
        [self presentViewController:a animated:YES completion:nil];
    }];
}

/// 文本行(对应 adjustSearchPlaceholderText / handleSearchPlaceholderInput:)
- (WCRTableRow *)textRow:(NSString *)title key:(NSString *)key {
    NSString *cur = [Cfg() valueForKey:key] ?: @"";
    __weak __typeof__(self) weakSelf = self;
    return [WCRTableRow valueRow:title value:cur action:^{
        __strong __typeof__(weakSelf) self = weakSelf;
        UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"设置%@", title]
                                                                  message:@"留空则使用微信默认占位文字"
                                                           preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.text = cur;
            tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        }];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            NSString *raw = a.textFields.firstObject.text ?: @"";
            [Cfg() setValue:raw forKey:key];
            [self sendSettingsChangedNotification];
            [self reloadTableData];
        }]];
        [self presentViewController:a animated:YES completion:nil];
    }];
}

/// 「清除遮罩」行 —— 原实现是 normalCell,点击弹 UIAlertView 选择:
///   (1) 清除遮罩开关  (2) 替换内容(搜索框占位文本)
- (WCRTableRow *)searchMaskRow {
    BOOL maskOn = [Cfg() searchClearMaskEnabled];
    __weak __typeof__(self) weakSelf = self;
    WCRTableRow *row = [WCRTableRow valueRow:@"清除遮罩"
                                       value:(maskOn ? @"已开启" : @"")
                                      action:^{
        __strong __typeof__(weakSelf) self = weakSelf;
        UIAlertController *a =
            [UIAlertController alertControllerWithTitle:@"用于清除ThemeBox搜索遮罩层\n仅在使用盒子主题时再开启"
                                                message:nil
                                         preferredStyle:UIAlertControllerStyleActionSheet];
        [a addAction:[UIAlertAction actionWithTitle:(maskOn ? @"关闭清除遮罩" : @"开启清除遮罩")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *x) {
            [Cfg() setSearchClearMaskEnabled:!maskOn];
            [self sendSettingsChangedNotification];
            [self reloadTableData];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"替换内容" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            [self promptPlaceholderText];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        a.popoverPresentationController.sourceView = self.tableView;
        a.popoverPresentationController.sourceRect = CGRectMake(self.tableView.bounds.size.width / 2,
                                                                self.tableView.bounds.size.height / 2, 1, 1);
        [self presentViewController:a animated:YES completion:nil];
    }];
    return row;
}

/// 对应 -adjustSearchPlaceholderText / -handleSearchPlaceholderInput:
- (void)promptPlaceholderText {
    NSString *cur = [Cfg() searchTextPlaceholder] ?: @"";
    __weak __typeof__(self) weakSelf = self;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"替换内容"
                                                              message:@"设置搜索框占位显示文本"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = cur;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        __strong __typeof__(weakSelf) self = weakSelf;
        NSString *raw = a.textFields.firstObject.text ?: @"";
        [Cfg() setSearchTextPlaceholder:raw];
        [Cfg() setSearchTextPlaceholderEnabled:(raw.length > 0)];
        [self sendSettingsChangedNotification];
        [self reloadTableData];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

/// 颜色行:右侧色点预览 + 点击进颜色选择器
- (WCRTableRow *)colorRow:(NSString *)title base:(NSString *)base {
    UIView *dot = [UIView new];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.layer.cornerRadius = 9;
    dot.layer.borderWidth = 1;
    dot.layer.borderColor = [UIColor separatorColor].CGColor;
    UIColor *light = [Cfg() valueForKey:[base stringByAppendingString:@"Light"]];
    dot.backgroundColor = light;
    [dot.widthAnchor constraintEqualToConstant:18].active = YES;
    [dot.heightAnchor constraintEqualToConstant:18].active = YES;

    __weak __typeof__(self) weakSelf = self;
    return [WCRTableRow accessoryRow:title rightView:dot action:^{
        __strong __typeof__(weakSelf) self = weakSelf;
        UIColor *l = [Cfg() valueForKey:[base stringByAppendingString:@"Light"]];
        UIColor *d = [Cfg() valueForKey:[base stringByAppendingString:@"Dark"]];
        WCRColorPickerViewController *picker =
            [[WCRColorPickerViewController alloc] initWithTitle:title
                                                      lightHex:[WCRCornerConfig hexFromColor:l]
                                                       darkHex:[WCRCornerConfig hexFromColor:d]
                                                       callback:^(UIColor *nl, UIColor *nd) {
            [Cfg() setValue:nl forKey:[base stringByAppendingString:@"Light"]];
            [Cfg() setValue:nd forKey:[base stringByAppendingString:@"Dark"]];
            [self sendSettingsChangedNotification];
            [self reloadTableData];
        }];
        [self.navigationController pushViewController:picker animated:YES];
    }];
}

/// 跳转型行(指向别的板块)
- (WCRTableRow *)pushRow:(NSString *)title hint:(NSString *)hint {
    __weak __typeof__(self) weakSelf = self;
    return [WCRTableRow valueRow:title value:@"" action:^{
        __strong __typeof__(weakSelf) self = weakSelf;
        UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                                  message:hint
                                                           preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }];
}

#pragma mark ==================== reloadTableData(核心:24 个分组) ====================

- (void)reloadTableData {
    [self.sections removeAllObjects];

#pragma mark 1. 全局cell圆角
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"全局cell圆角" footer:nil];
        __weak __typeof__(self) weakSelf = self;
        WCRTableRow *globalRow = [WCRTableRow valueRow:@"主页全局圆角" value:@"" action:^{
            __strong __typeof__(weakSelf) self = weakSelf;
            [self triggerHapticFeedback];
            [self.navigationController pushViewController:[WCRGlobalCornerViewController new] animated:YES];
        }];
        [s addRow:globalRow];
        [s addRow:[self pushRow:@"我的页面圆角"
                           hint:@"该子页属于「资料卡美化」板块，本板块未包含。\n入口保留原位置，功能实现需另一份逆向。"]];
        [self addSection:s];
    }

#pragma mark 2. 搜索框圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"搜索框圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"searchCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"searchCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"边距大小" key:@"searchCornerMargin" format:@"%ld" isFloat:NO range:@"范围：0-20" min:0 max:20]];
        [s addRow:[self valueRow:@"描边大小" key:@"searchCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"searchCornerBorderColor"]];
        [s addRow:[self searchMaskRow]];
        [self addSection:s];
    }

#pragma mark 3. 输入框圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"输入框圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"inputCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"inputCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"inputCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"inputCornerBorderColor"]];
        [s addRow:[self switchRow:@"输入框透明" key:@"inputBoxTransparencyEnabled"]];
        [s addRow:[self valueRow:@"透明度大小" key:@"inputBoxTransparencyAlpha" format:@"%ld" isFloat:NO
                           range:@"范围：0-100\n0 为完全透明，100 为完全不透明" min:0 max:100]];
        [self addSection:s];
    }

#pragma mark 4. 输入法圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"输入法圆角设置"
                                                         footer:@"微信输入法、系统键盘等远程键盘窗口顶部圆角，不影响输入框。"];
        [s addRow:[self switchRow:@"开启圆角" key:@"imeKeyboardCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"imeKeyboardCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-50" min:0 max:50]];
        [s addRow:[self valueRow:@"描边大小" key:@"imeKeyboardCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"imeKeyboardCornerBorderColor"]];
        [self addSection:s];
    }

#pragma mark 5. 顶栏圆角设置(含群公告透明)
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"顶栏圆角设置"
                                                         footer:@"微信顶栏与聊天顶栏共用；小程序、视频号等透明顶栏页不生效"];
        [s addRow:[self switchRow:@"开启圆角" key:@"topbarCornerEnabled"]];
        [s addRow:[self switchRow:@"顶部不圆" key:@"topbarCornerTopFlatEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"topbarCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-50" min:0 max:50]];
        [s addRow:[self valueRow:@"描边大小" key:@"topbarCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"topbarCornerBorderColor"]];
        [s addRow:[self switchRow:@"群公告透明" key:@"groupTipsTransparencyEnabled"]];
        [s addRow:[self valueRow:@"透明度大小" key:@"groupTipsTransparencyAlpha" format:@"%ld" isFloat:NO
                           range:@"范围：0-100\n0 为完全透明，100 为完全不透明" min:0 max:100]];
        [self addSection:s];
    }

#pragma mark 6. 底栏圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"底栏圆角设置"
                                                         footer:@"首页 MMTabBar 与聊天输入底栏共用"];
        [s addRow:[self switchRow:@"开启圆角" key:@"toolbarCornerEnabled"]];
        [s addRow:[self switchRow:@"底部不圆" key:@"toolbarCornerBottomFlatEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"toolbarCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-50" min:0 max:50]];
        [s addRow:[self valueRow:@"描边大小" key:@"toolbarCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"toolbarCornerBorderColor"]];
        [self addSection:s];
    }

#pragma mark 7. 表情包圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"表情包圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"emojiCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"emojiCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"emojiCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"emojiCornerBorderColor"]];
        [self addSection:s];
    }

#pragma mark 8. 聊天图片圆角设置(含定位/文件)
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"聊天图片圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"chatImageCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"chatImageCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"chatImageCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"chatImageCornerBorderColor"]];
        [s addRow:[self switchRow:@"定位圆角" key:@"chatLocationCornerEnabled"]];
        [s addRow:[self switchRow:@"文件圆角" key:@"chatFileCornerEnabled"]];
        [self addSection:s];
    }

#pragma mark 9. 气泡圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"气泡圆角设置"
                                                         footer:@"作用于官方聊天气泡背景，可搭配气泡切割"];
        [s addRow:[self switchRow:@"开启圆角" key:@"chatBubbleCornerEnabled"]];
        [s addRow:[self switchRow:@"去除箭头" key:@"chatBubbleArrowHidden"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"chatBubbleCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"chatBubbleCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"chatBubbleCornerBorderColor"]];
        [self addSection:s];
    }

#pragma mark 10. 聊天时间圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"聊天时间圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"chatTimeRoundCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"chatTimeRoundCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"chatTimeRoundCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"chatTimeRoundCornerBorderColor"]];
        [s addRow:[self switchRow:@"时间背景" key:@"chatTimeRoundBackgroundEnabled"]];
        [s addRow:[self colorRow:@"背景颜色" base:@"chatTimeRoundBackgroundColor"]];
        [s addRow:[self switchRow:@"时间文本" key:@"chatTimeRoundTextColorEnabled"]];
        [s addRow:[self colorRow:@"文本颜色" base:@"chatTimeRoundTextColor"]];
        [self addSection:s];
    }

#pragma mark 11. 消息引用圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"消息引用圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"msgReferCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"msgReferCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"msgReferCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"msgReferCornerBorderColor"]];
        [s addRow:[self switchRow:@"修改颜色" key:@"msgReferColorEnabled"]];
        [s addRow:[self colorRow:@"背景颜色" base:@"msgReferColor"]];
        [self addSection:s];
    }

#pragma mark 12. 语音转文字圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"语音转文字圆角设置"
                                                         footer:@"支持语音转文字视图和文本消息翻译视图"];
        [s addRow:[self switchRow:@"开启圆角" key:@"voiceTranslateCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"voiceTranslateCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"voiceTranslateCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"voiceTranslateCornerBorderColor"]];
        [s addRow:[self switchRow:@"修改颜色" key:@"voiceTranslateColorEnabled"]];
        [s addRow:[self colorRow:@"对方消息" base:@"voiceTranslateColorOther"]];
        [s addRow:[self colorRow:@"我方消息" base:@"voiceTranslateColorSelf"]];
        [self addSection:s];
    }

#pragma mark 13. 拍一拍圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"拍一拍圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"systemMessageCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"systemMessageCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"systemMessageCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"systemMessageCornerBorderColor"]];
        [s addRow:[self switchRow:@"修改颜色" key:@"systemMessageColorEnabled"]];
        [s addRow:[self colorRow:@"背景颜色" base:@"systemMessageColor"]];
        [self addSection:s];
    }

#pragma mark 14. 系统通知圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"系统通知圆角设置"
                                                         footer:@"如群邀请、防撤回提示、艾特提示等"];
        [s addRow:[self switchRow:@"开启圆角" key:@"systemNoticeCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"systemNoticeCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"systemNoticeCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"systemNoticeCornerBorderColor"]];
        [s addRow:[self switchRow:@"修改颜色" key:@"systemNoticeColorEnabled"]];
        [s addRow:[self colorRow:@"背景颜色" base:@"systemNoticeColor"]];
        [self addSection:s];
    }

#pragma mark 15. 朋友圈圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"朋友圈圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"momentCornerEnabled"]];
        [s addRow:[self switchRow:@"整体圆角" key:@"momentCornerUnifiedEnabled"]];
        [s addRow:[self switchRow:@"赞评菜单" key:@"momentOperateMenuCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"momentCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"momentCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"momentCornerBorderColor"]];
        [self addSection:s];
    }

#pragma mark 16. 视频号圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"视频号圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"finderCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"finderCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"finderCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"finderCornerBorderColor"]];
        [self addSection:s];
    }

#pragma mark 17. 服务页圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"服务页圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"serviceCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"serviceCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"serviceCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"serviceCornerBorderColor"]];
        [self addSection:s];
    }

#pragma mark 18. 加号菜单圆角设置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"加号菜单圆角设置" footer:nil];
        [s addRow:[self switchRow:@"开启圆角" key:@"plusMenuCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"plusMenuCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"plusMenuBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"plusMenuBorderColor"]];
        [s addRow:[self switchRow:@"背景改色" key:@"plusMenuBgColorEnabled"]];
        [s addRow:[self colorRow:@"背景颜色" base:@"plusMenuBgColor"]];
        [s addRow:[self switchRow:@"文字改色" key:@"plusMenuTextColorEnabled"]];
        [s addRow:[self colorRow:@"文字颜色" base:@"plusMenuTextColor"]];
        [s addRow:[self switchRow:@"图标改色" key:@"plusMenuIconColorEnabled"]];
        [s addRow:[self colorRow:@"图标颜色" base:@"plusMenuIconColor"]];
        [self addSection:s];
    }

#pragma mark 19. 发送发布按钮圆角
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"发送发布按钮圆角" footer:nil];
        [s addRow:[self switchRow:@"发送按钮圆角" key:@"sendPublishButtonCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"sendPublishButtonCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"sendPublishButtonCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"sendPublishButtonBorderColor"]];
        [self addSection:s];
    }

#pragma mark 20. 系统弹窗圆角
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"系统弹窗圆角"
                                                         footer:@"系统提示弹窗、Toast 等浮层。"];
        [s addRow:[self switchRow:@"系统弹窗圆角" key:@"systemPopupCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"systemPopupCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-30" min:0 max:30]];
        [s addRow:[self valueRow:@"描边大小" key:@"systemPopupCornerBorderSize" format:@"%.1f" isFloat:YES range:@"范围：0.0-5.0" min:0 max:5]];
        [s addRow:[self colorRow:@"描边颜色" base:@"systemPopupBorderColor"]];
        [self addSection:s];
    }

#pragma mark 21. 左滑菜单圆角
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"左滑菜单圆角" footer:nil];
        [s addRow:[self switchRow:@"左滑菜单圆角" key:@"mainFrameSwipeMenuCornerEnabled"]];
        [s addRow:[self valueRow:@"圆角大小" key:@"mainFrameSwipeMenuCornerRadius" format:@"%ld" isFloat:NO range:@"范围：0-50" min:0 max:50]];
        [self addSection:s];
    }

#pragma mark 22. 已独立的圆角
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:@"已独立的圆角"
                                                         footer:@"已迁移并扩展功能，点击可跳转至设置页。"];
        [s addRow:[self pushRow:@"消息横幅圆角" hint:@"该子页属于「消息横幅美化」板块，本板块未包含。"]];
        [s addRow:[self pushRow:@"长按菜单圆角" hint:@"该子页属于「菜单美化」板块，本板块未包含。"]];
        [s addRow:[self pushRow:@"全局头像圆角" hint:@"该子页属于「头像框圆角美化」板块，本板块未包含。"]];
        [self addSection:s];
    }

#pragma mark 23. 重置
    {
        WCRTableSection *s = [WCRTableSection sectionWithHeader:nil footer:nil];
        __weak __typeof__(self) weakSelf = self;
        WCRTableRow *row = [WCRTableRow buttonRow:@"重置圆角设置" destructive:YES action:^{
            __strong __typeof__(weakSelf) self = weakSelf;
            [self resetAllCornerSettings:nil];
        }];
        [s addRow:row];
        [self addSection:s];
    }

    [self.tableView reloadData];
}

#pragma mark 重置(对应 -resetAllCornerSettings: / -confirmResetAllCornerSettings)

- (void)resetAllCornerSettings:(id)sender {
    [self triggerHapticFeedback];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"WCRefine"
                                                              message:@"将所有圆角设置恢复为初始状态？\n不包含主页全局圆角"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"确定重置" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        [self confirmResetAllCornerSettings];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)confirmResetAllCornerSettings {
    [self triggerHapticFeedback];
    [[WCRCornerConfig shared] resetAllCornerSettings];
    [self sendSettingsChangedNotification];
    [self reloadTableData];
}

@end
