//
//  ZFXFloatTabSettings.m
//

#import "ZFXFloatTabSettings.h"
#import "ZFXFloatTabBar.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static void ZFXPostChanged(void) {
    [[NSNotificationCenter defaultCenter] postNotificationName:ZFXSettingsChangedNotification object:nil];
}

static UIViewController *ZFXTopViewController(void) {
    UIWindow *win = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in [(UIWindowScene *)scene windows]) {
                if (w.isKeyWindow) { win = w; break; }
            }
            if (win) break;
        }
    }
    if (!win) win = [UIApplication sharedApplication].keyWindow;

    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:[UINavigationController class]]) {
        vc = [(UINavigationController *)vc topViewController];
    }
    return vc;
}

static BOOL ZFXIsDark(void) {
    if (@available(iOS 13.0, *)) {
        return [UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

#pragma mark - 结构定义

@implementation ZFXSettingRow
@end

@implementation ZFXSettingSection
@end

static ZFXSettingRow *ZFXRow(NSString *title, NSString *key, ZFXRowType type) {
    ZFXSettingRow *r = [ZFXSettingRow new];
    r.title = title; r.key = key; r.type = type;
    return r;
}

static ZFXSettingRow *ZFXSwitch(NSString *title, NSString *key) {
    return ZFXRow(title, key, ZFXRowTypeSwitch);
}

static ZFXSettingRow *ZFXSegment(NSString *title, NSString *key, NSArray<NSString *> *opts) {
    ZFXSettingRow *r = ZFXRow(title, key, ZFXRowTypeSegment);
    r.options = opts;
    return r;
}

static ZFXSettingRow *ZFXSlider(NSString *title, NSString *key, NSInteger mn, NSInteger mx, NSInteger def) {
    ZFXSettingRow *r = ZFXRow(title, key, ZFXRowTypeSlider);
    r.minValue = mn; r.maxValue = mx; r.defaultValue = def;
    return r;
}

static ZFXSettingRow *ZFXColor(NSString *title, NSString *key) {
    return ZFXRow(title, key, ZFXRowTypeColor);
}

static ZFXSettingSection *ZFXSection(NSString *header, NSArray<ZFXSettingRow *> *rows) {
    ZFXSettingSection *s = [ZFXSettingSection new];
    s.header = header; s.rows = rows;
    return s;
}

NSArray<ZFXSettingSection *> *ZFXBuildSettingSections(void) {
    return @[
        // ── 功能开关（9 行）─────────────────────────────
        ZFXSection(@"功能开关", @[
            ZFXSwitch(@"启用悬浮底栏", ZFXKeyFloatTab),
            ZFXSwitch(@"关闭遮罩",     ZFXKeyNoMask),
            ZFXSwitch(@"立体效果",     ZFXKeyStereo),
            ZFXSwitch(@"遮罩发光",     ZFXKeyMaskGlow),
            ZFXSwitch(@"长按弹窗",     ZFXKeyLongPopup),
            ZFXSwitch(@"遮罩滑动",     ZFXKeyMaskSlide),
            ZFXSwitch(@"隐藏红点",     ZFXKeyHideDot),
            ZFXSwitch(@"隐藏角标",     ZFXKeyHideBadge),
            ZFXSwitch(@"隐藏文字",     ZFXKeyHideText),
        ]),
        // ── 样式与基础（2 行）───────────────────────────
        ZFXSection(@"样式与基础", @[
            ZFXSegment(@"样式", ZFXKeyStyle,
                       @[@"初始样式", @"液态样式", @"组合样式", @"自定义样式"]),
            ZFXSegment(@"动画", ZFXKeyIconAnim,
                       @[@"关", @"1", @"2", @"3", @"4", @"5"]),
        ]),
        // ── 颜色配置（5 行）─────────────────────────────
        ZFXSection(@"颜色配置 (仅开启自定义样式全量生效)", @[
            ZFXColor(@"按钮颜色",       ZFXKeyBtnColor),
            ZFXColor(@"遮罩颜色(浅色)", ZFXKeyMaskLight),
            ZFXColor(@"遮罩颜色(深色)", ZFXKeyMaskDark),
            ZFXColor(@"背景颜色(浅色)", ZFXKeyBgLight),
            ZFXColor(@"背景颜色(深色)", ZFXKeyBgDark),
        ]),
        // ── 尺寸与外观（7 行）───────────────────────────
        ZFXSection(@"尺寸与外观", @[
            ZFXSlider(@"宽度设置", ZFXKeyWidth,       -50, 50, -1),
            ZFXSlider(@"上下设置", ZFXKeyY,           -40, 40, -4),
            ZFXSlider(@"高度设置", ZFXKeyHeight,      -40, 40, 12),
            ZFXSlider(@"底栏透明", ZFXKeyAlpha,         0, 100, 100),
            ZFXSlider(@"遮罩透明", ZFXKeyMaskAlpha,     0, 100, 100),
            ZFXSlider(@"圆角度数", ZFXKeyRadius,      -50, 50, -1),
            ZFXSlider(@"按钮放大", ZFXKeyButtonScale,   0, 100, 0),
        ]),
    ];
}

#pragma mark - 设置页

@interface ZFXFloatTabSettingsViewController ()
@property (nonatomic, copy) NSArray<ZFXSettingSection *> *sections;
@end

@implementation ZFXFloatTabSettingsViewController

+ (void)presentFromViewController:(UIViewController *)presenter {
    ZFXFloatTabSettingsViewController *vc = [[ZFXFloatTabSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [presenter presentViewController:nav animated:YES completion:nil];
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        self.title = @"悬浮底栏";
        _sections = ZFXBuildSettingSections();
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [ZFXPrefs registerDefaults];

    if (self.navigationController.viewControllers.firstObject == self) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                          target:self
                                                          action:@selector(close)];
    }
    if (!self.navigationController) return;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark 数据源

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.sections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section].header;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"开启后，悬浮底栏将在下次重启 APP 后生效。底下的样式、动画、颜色和尺寸配置会在开启后展示。\n\n"
               @"开启此功能时，会默认开启按住左边右滑以及默认开启按住右边左滑返回到主页的功能，请关闭其他插件同类左滑返回主页的功能。";
    }
    if (section == 1) {
        return @"开启“长按弹窗”以后，按住底栏第二个按钮，即可方便地调节悬浮底栏的位置以及大小。";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    ZFXSettingRow *row = self.sections[indexPath.section].rows[indexPath.row];
    return row.type == ZFXRowTypeSlider ? 76.0 : 50.0;
}

#pragma mark 单元格

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ZFXSettingRow *row = self.sections[indexPath.section].rows[indexPath.row];
    static NSString *reuse = @"zfx.row";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuse];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    cell.textLabel.text = row.title;
    cell.accessoryView = nil;
    cell.detailTextLabel.text = nil;
    [cell.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    switch (row.type) {
        case ZFXRowTypeSwitch: {
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [ZFXPrefs boolForKey:row.key def:[self builtinDefaultForRow:row]];
            sw.tag = indexPath.section * 1000 + indexPath.row;
            [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            objc_setAssociatedObject(sw, "zfx.key", row.key, OBJC_ASSOCIATION_COPY_NONATOMIC);
            cell.accessoryView = sw;
            break;
        }
        case ZFXRowTypeSegment: {
            UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:row.options];
            seg.selectedSegmentIndex = [ZFXPrefs intForKey:row.key def:0];
            [seg addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
            objc_setAssociatedObject(seg, "zfx.key", row.key, OBJC_ASSOCIATION_COPY_NONATOMIC);
            seg.apportionsSegmentWidthsByContent = YES;
            cell.accessoryView = seg;
            cell.textLabel.text = row.title;
            break;
        }
        case ZFXRowTypeSlider: {
            UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(16, 44, cell.contentView.bounds.size.width - 32, 28)];
            slider.minimumValue = (float)row.minValue;
            slider.maximumValue = (float)row.maxValue;
            slider.value = (float)[ZFXPrefs intForKey:row.key def:row.defaultValue];
            slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
            objc_setAssociatedObject(slider, "zfx.key", row.key, OBJC_ASSOCIATION_COPY_NONATOMIC);
            objc_setAssociatedObject(slider, "zfx.row", row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [cell.contentView addSubview:slider];

            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)slider.value];
            break;
        }
        case ZFXRowTypeColor: {
            NSString *hex = [ZFXPrefs stringForKey:row.key];
            UIColor *color = [ZFXPrefs colorFromHex:hex fallback:[UIColor whiteColor]];
            UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
            swatch.backgroundColor = color;
            swatch.layer.cornerRadius = 8.0;
            swatch.layer.borderWidth = 0.5;
            swatch.layer.borderColor = [UIColor separatorColor].CGColor;
            cell.accessoryView = swatch;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.detailTextLabel.text = hex.length ? hex : @"默认";
            break;
        }
    }
    return cell;
}

- (BOOL)builtinDefaultForRow:(ZFXSettingRow *)row {
    if ([row.key isEqualToString:ZFXKeyStereo]    ||
        [row.key isEqualToString:ZFXKeyLongPopup] ||
        [row.key isEqualToString:ZFXKeyMaskSlide]) return YES;
    return NO;
}

#pragma mark 事件

- (void)switchChanged:(UISwitch *)sw {
    NSString *key = objc_getAssociatedObject(sw, "zfx.key");
    if (!key) return;
    [ZFXPrefs setBool:sw.isOn forKey:key];
    ZFXPostChanged();
}

- (void)segmentChanged:(UISegmentedControl *)seg {
    NSString *key = objc_getAssociatedObject(seg, "zfx.key");
    if (!key) return;
    [ZFXPrefs setInt:seg.selectedSegmentIndex forKey:key];
    ZFXPostChanged();
}

- (void)openFullSettings {
    UIViewController *top = ZFXTopViewController();
    if (!top) return;
    [self dismiss];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ZFXFloatTabSettingsViewController presentFromViewController:top];
    });
}

- (void)sliderChanged:(UISlider *)slider {
    NSString *key = objc_getAssociatedObject(slider, "zfx.key");
    if (!key) return;
    NSInteger v = (NSInteger)lroundf(slider.value);
    [ZFXPrefs setInt:v forKey:key];
    ZFXPostChanged();

    UITableViewCell *cell = (UITableViewCell *)slider.superview.superview;
    if ([cell isKindOfClass:[UITableViewCell class]]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)v];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ZFXSettingRow *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.type != ZFXRowTypeColor) return;

    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSString *current = [ZFXPrefs stringForKey:row.key] ?: @"#FFFFFF";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"请输入十六进制颜色代码"
                                                                  message:@"支持 6 位 (如 #FF0000) 或带透明度的 8 位 (如 #FF000080)"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = current;
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.placeholder = @"#FFFFFF";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:row.key];
        ZFXPostChanged();
        [tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *text = alert.textFields.firstObject.text ?: @"";
        NSString *clean = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([ZFXPrefs colorFromHex:clean fallback:nil] == nil) {
            return;
        }
        [ZFXPrefs setString:clean forKey:row.key];
        ZFXPostChanged();
        [tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - 长按调节卡片

@interface ZFXQuickSettingsCard ()
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) NSMutableArray<UISlider *> *sliders;
@property (nonatomic, strong) NSMutableArray<NSString *> *sliderKeys;
@property (nonatomic, strong) NSMutableArray<UILabel *> *valueLabels;
@property (nonatomic, strong) NSMutableArray<UILabel *> *nameLabels;
@end

@implementation ZFXQuickSettingsCard

+ (void)presentInWindow:(UIWindow *)window {
    if (!window) return;
    ZFXQuickSettingsCard *card = [[ZFXQuickSettingsCard alloc] initWithFrame:window.bounds];
    [card showInWindow:window];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.18];

        _panel = [[UIView alloc] initWithFrame:CGRectZero];
        _panel.layer.cornerRadius = 18.0;
        if (@available(iOS 13.0, *)) _panel.layer.cornerCurve = kCACornerCurveContinuous;
        _panel.clipsToBounds = YES;
        [self addSubview:_panel];

        _blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
        [_panel addSubview:_blur];

        _sliders = [NSMutableArray array];
        _sliderKeys = [NSMutableArray array];
        _valueLabels = [NSMutableArray array];
        _nameLabels = [NSMutableArray array];

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
        title.text = @"悬浮底栏调整";
        title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        title.textColor = [UIColor labelColor];
        title.tag = 9001;
        [_panel addSubview:title];

        // 与设置页同名的 7 个滑块
        NSArray *defs = @[
            @[@"宽度",  ZFXKeyWidth,       @(-50), @(50),  @(-1)],
            @[@"上下",  ZFXKeyY,           @(-40), @(40),  @(-4)],
            @[@"高度",  ZFXKeyHeight,      @(-40), @(40),  @(12)],
            @[@"透明",  ZFXKeyAlpha,       @(0),   @(100), @(100)],
            @[@"遮罩",  ZFXKeyMaskAlpha,   @(0),   @(100), @(100)],
            @[@"圆角",  ZFXKeyRadius,      @(-50), @(50),  @(-1)],
            @[@"放大",  ZFXKeyButtonScale, @(0),   @(100), @(0)],
        ];

        for (NSArray *d in defs) {
            UILabel *lb = [[UILabel alloc] initWithFrame:CGRectZero];
            lb.text = d[0];
            lb.font = [UIFont systemFontOfSize:11];
            lb.textColor = [UIColor secondaryLabelColor];
            [_panel addSubview:lb];
            [_nameLabels addObject:lb];

            UISlider *s = [[UISlider alloc] initWithFrame:CGRectZero];
            s.minimumValue = [d[2] floatValue];
            s.maximumValue = [d[3] floatValue];
            s.value = (float)[ZFXPrefs intForKey:d[1] def:[d[4] integerValue]];
            [s addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
            [_panel addSubview:s];

            UILabel *v = [[UILabel alloc] initWithFrame:CGRectZero];
            v.text = [NSString stringWithFormat:@"%ld", (long)s.value];
            v.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];
            v.textColor = [UIColor secondaryLabelColor];
            v.textAlignment = NSTextAlignmentRight;
            [_panel addSubview:v];

            [_sliders addObject:s];
            [_sliderKeys addObject:d[1]];
            [_valueLabels addObject:v];
        }

        UIButton *full = [UIButton buttonWithType:UIButtonTypeSystem];
        [full setTitle:@"完整设置" forState:UIControlStateNormal];
        full.titleLabel.font = [UIFont systemFontOfSize:13];
        [full addTarget:self action:@selector(openFullSettings) forControlEvents:UIControlEventTouchUpInside];
        full.tag = 9003;
        [_panel addSubview:full];

        UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
        [close setTitle:@"完成" forState:UIControlStateNormal];
        close.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [close addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
        close.tag = 9002;
        [_panel addSubview:close];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)showInWindow:(UIWindow *)window {
    self.frame = window.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [window addSubview:self];

    CGFloat margin = 14.0;
    CGFloat panelW = window.bounds.size.width - margin * 2;
    CGFloat rowH = 44.0;
    CGFloat panelH = 52.0 + rowH * self.sliders.count + 46.0;
    CGFloat panelY = window.bounds.size.height - panelH - 90.0 - (window.safeAreaInsets.bottom > 0 ? 0 : 20);

    self.panel.frame = CGRectMake(margin, panelY, panelW, panelH);

    UIView *title = [self.panel viewWithTag:9001];
    title.frame = CGRectMake(16, 14, panelW - 32, 22);

    CGFloat y = 52.0;
    for (NSUInteger i = 0; i < self.sliders.count; i++) {
        self.nameLabels[i].frame = CGRectMake(16, y + 2, 32, 16);
        self.sliders[i].frame = CGRectMake(52, y, panelW - 52 - 56, 28);
        self.valueLabels[i].frame = CGRectMake(panelW - 52, y + 6, 36, 16);
        y += rowH;
    }

    UIButton *close = (UIButton *)[self.panel viewWithTag:9002];
    close.frame = CGRectMake(panelW - 66, 10, 56, 30);

    UIButton *full = (UIButton *)[self.panel viewWithTag:9003];
    full.frame = CGRectMake(panelW - 140, 10, 72, 30);

    self.blur.frame = self.panel.bounds;
    self.alpha = 0.0;
    self.panel.transform = CGAffineTransformMakeTranslation(0, 24);
    [UIView animateWithDuration:0.24 animations:^{
        self.alpha = 1.0;
        self.panel.transform = CGAffineTransformIdentity;
    }];
}

- (void)openFullSettings {
    UIViewController *top = ZFXTopViewController();
    if (!top) return;
    [self dismiss];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ZFXFloatTabSettingsViewController presentFromViewController:top];
    });
}

- (void)sliderChanged:(UISlider *)slider {
    NSUInteger idx = [self.sliders indexOfObject:slider];
    if (idx == NSNotFound) return;
    NSInteger v = (NSInteger)lroundf(slider.value);
    [ZFXPrefs setInt:v forKey:self.sliderKeys[idx]];
    self.valueLabels[idx].text = [NSString stringWithFormat:@"%ld", (long)v];
    ZFXPostChanged();
}

- (void)backgroundTapped:(UITapGestureRecognizer *)g {
    CGPoint p = [g locationInView:self];
    if (!CGRectContainsPoint(self.panel.frame, p)) [self dismiss];
}

- (void)dismiss {
    [UIView animateWithDuration:0.18 animations:^{
        self.alpha = 0.0;
        self.panel.transform = CGAffineTransformMakeTranslation(0, 18);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
