//
//  WPGroupColorPickerController.m
//

#import "WPGroupColorPickerController.h"
#import "WPGroupConfig.h"
#import <math.h>

@interface WPGroupColorPickerController ()
@property (nonatomic, copy) NSString *initialHex;
@property (nonatomic, strong) UIView *preview;
@property (nonatomic, strong) UISlider *hueSlider;
@property (nonatomic, strong) UISlider *satSlider;
@property (nonatomic, strong) UISlider *briSlider;
@property (nonatomic, strong) UITextField *hexField;
@property (nonatomic, strong) UILabel *hexLabel;
@property (nonatomic, assign) CGFloat h, s, b;
- (void)buildUI;
- (UISlider *)sliderWithY:(CGFloat)y action:(SEL)action max:(CGFloat)max;
- (void)setHex:(NSString *)hex;
- (UIColor *)currentColor;
- (void)refreshPreview;
- (void)sliderChanged:(UISlider *)sender;
- (void)presetTapped:(UIButton *)sender;
- (void)hexFieldChanged:(UITextField *)tf;
- (void)cancel;
- (void)done;

@end

@implementation WPGroupColorPickerController

- (instancetype)initWithTitle:(NSString *)title hex:(NSString *)hex {
    if ((self = [super init])) {
        self.title = title.length ? title : @"选择颜色";
        _initialHex = [hex copy] ?: @"#07C160";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStyleDone
                                        target:self action:@selector(done)];

    [self buildUI];
    [self setHex:self.initialHex];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat y = 100;

    self.preview = [[UIView alloc] initWithFrame:CGRectMake(24, y, w - 48, 72)];
    self.preview.layer.cornerRadius = 12;
    self.preview.layer.borderWidth = 0.5;
    self.preview.layer.borderColor = [UIColor separatorColor].CGColor;
    [self.view addSubview:self.preview];
    y = CGRectGetMaxY(self.preview.frame) + 16;

    self.hexLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, y, w - 48, 22)];
    self.hexLabel.textAlignment = NSTextAlignmentCenter;
    self.hexLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
    [self.view addSubview:self.hexLabel];
    y += 34;

    self.hueSlider = [self sliderWithY:y action:@selector(sliderChanged:) max:1.0];
    y += 56;
    self.satSlider = [self sliderWithY:y action:@selector(sliderChanged:) max:1.0];
    y += 56;
    self.briSlider = [self sliderWithY:y action:@selector(sliderChanged:) max:1.0];
    y += 70;

    // 预设色板
    UILabel *presetTitle = [[UILabel alloc] initWithFrame:CGRectMake(24, y, w - 48, 20)];
    presetTitle.text = @"常用颜色";
    presetTitle.font = [UIFont systemFontOfSize:13];
    presetTitle.textColor = [UIColor secondaryLabelColor];
    [self.view addSubview:presetTitle];
    y += 28;

    NSArray *presets = @[@"#07C160", @"#FFFFFF", @"#000000", @"#1C1C1E", @"#007AFF",
                         @"#FF9500", @"#FF3B30", @"#AF52DE", @"#5856D6", @"#8E8E93"];
    CGFloat cell = 32, gap = 12;
    CGFloat x = 24;
    for (NSString *hex in presets) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, y, cell, cell);
        btn.backgroundColor = [WPGroupConfig colorFromHexString:hex];
        btn.layer.cornerRadius = cell / 2;
        btn.layer.borderWidth = 0.5;
        btn.layer.borderColor = [UIColor separatorColor].CGColor;
        btn.accessibilityIdentifier = hex;
        [btn addTarget:self action:@selector(presetTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
        x += cell + gap;
        if (x + cell > w - 24) { x = 24; y += cell + gap; }
    }
    y += cell + gap + 8;

    self.hexField = [[UITextField alloc] initWithFrame:CGRectMake(24, y, w - 48, 40)];
    self.hexField.placeholder = @"手动输入 #RRGGBB";
    self.hexField.borderStyle = UITextBorderStyleRoundedRect;
    self.hexField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.hexField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.hexField.returnKeyType = UIReturnKeyDone;
    [self.hexField addTarget:self action:@selector(hexFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:self.hexField];
}

- (UISlider *)sliderWithY:(CGFloat)y action:(SEL)action max:(CGFloat)max {
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(24, y, CGRectGetWidth(self.view.bounds) - 48, 40)];
    slider.minimumValue = 0;
    slider.maximumValue = max;
    [slider addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:slider];
    return slider;
}

#pragma mark - 颜色换算

- (void)setHex:(NSString *)hex {
    UIColor *color = [WPGroupConfig colorFromHexString:hex];
    if (!color) return;
    CGFloat r = 0, g = 0, bl = 0, a = 0;
    [color getRed:&r green:&g blue:&bl alpha:&a];

    CGFloat maxV = MAX(r, MAX(g, bl));
    CGFloat minV = MIN(r, MIN(g, bl));
    CGFloat delta = maxV - minV;

    CGFloat hue = 0;
    if (delta > 0) {
        if (maxV == r) hue = fmodf((g - bl) / delta, 6.0f);
        else if (maxV == g) hue = (bl - r) / delta + 2.0f;
        else hue = (r - g) / delta + 4.0f;
        hue /= 6.0f;
        if (hue < 0) hue += 1.0f;
    }
    self.h = hue;
    self.s = maxV > 0 ? delta / maxV : 0;
    self.b = maxV;

    self.hueSlider.value = self.h;
    self.satSlider.value = self.s;
    self.briSlider.value = self.b;
    [self refreshPreview];
}

- (UIColor *)currentColor {
    CGFloat r = 0, g = 0, bl = 0;
    CGFloat i = floorf(self.h * 6);
    CGFloat f = self.h * 6 - i;
    CGFloat p = self.b * (1 - self.s);
    CGFloat q = self.b * (1 - f * self.s);
    CGFloat t = self.b * (1 - (1 - f) * self.s);
    switch ((int)i % 6) {
        case 0: r = self.b; g = t; bl = p; break;
        case 1: r = q; g = self.b; bl = p; break;
        case 2: r = p; g = self.b; bl = t; break;
        case 3: r = p; g = q; bl = self.b; break;
        case 4: r = t; g = p; bl = self.b; break;
        default: r = self.b; g = p; bl = q; break;
    }
    return [UIColor colorWithRed:r green:g blue:bl alpha:1];
}

- (void)refreshPreview {
    UIColor *color = [self currentColor];
    self.preview.backgroundColor = color;
    NSString *hex = [WPGroupConfig hexStringFromColor:color];
    self.hexLabel.text = hex;
    if (!self.hexField.isFirstResponder) self.hexField.text = hex;
}

#pragma mark - 事件

- (void)sliderChanged:(UISlider *)sender {
    self.h = self.hueSlider.value;
    self.s = self.satSlider.value;
    self.b = self.briSlider.value;
    [self refreshPreview];
}

- (void)presetTapped:(UIButton *)sender {
    [self setHex:sender.accessibilityIdentifier];
}

- (void)hexFieldChanged:(UITextField *)tf {
    NSString *text = tf.text;
    if (text.length >= 6) {
        UIColor *c = [WPGroupConfig colorFromHexString:text];
        if (c) {
            self.preview.backgroundColor = c;
            self.hexLabel.text = [WPGroupConfig hexStringFromColor:c];
        }
    }
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)done {
    NSString *hex = self.hexField.text.length ? self.hexField.text : self.hexLabel.text;
    UIColor *c = [WPGroupConfig colorFromHexString:hex];
    NSString *final = c ? [WPGroupConfig hexStringFromColor:c] : [WPGroupConfig hexStringFromColor:[self currentColor]];
    if (self.completion) self.completion(final);
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
