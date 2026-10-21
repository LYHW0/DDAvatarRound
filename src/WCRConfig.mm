//
//  WCRConfig.mm
//  配置层 —— 对应原插件 WCRefineConfig(4861 方法) 里与圆角相关的 330 个存取器
//
//  逆向结论(逐条对应原二进制行为):
//    * 存储是一个 NSDictionary,键 == 存取器 selector 名
//    * getter 命中空值时写回默认值并立刻落盘(原实现里能看到 objectForKey: → 判空 →
//      numberWithXxx: → setObject:forKey: → saveConfigDictionary:)
//    * setter 先 clamp 再落盘;半径类 clamp 上限各不相同,见头文件 X-Macro 表
//    * 布尔项原实现用 numberWithBool:,整型用 numberWithInt:/numberWithInteger:,
//      描边宽度用 numberWithDouble:,颜色用 UIColor 归档
//

#import "WCRCorner.h"

NSString *const WCRCornerSettingsChangedNotification = @"WCRCornerSettingsChangedNotification";

static NSString *WCRConfigPath(void) {
    // Sideloaded apps are sandboxed; store configuration inside this app's container.
    NSString *library = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences"];
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:library
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    return [library stringByAppendingPathComponent:@"com.wcr.corner.reverse.plist"];
}

#pragma mark - C++ 小工具(纯逻辑,不依赖 ObjC)

namespace wcr {

/// 把任意整数夹到 [lo, hi]。原插件 setter 里就是 subs/b.le 两条比较。
static inline long long clampLL(long long v, long long lo, long long hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline double clampD(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

/// 0xRRGGBB -> 分量
static inline void unpack(unsigned int hex, double &r, double &g, double &b) {
    r = ((hex >> 16) & 0xFF) / 255.0;
    g = ((hex >> 8) & 0xFF) / 255.0;
    b = (hex & 0xFF) / 255.0;
}

} // namespace wcr

#pragma mark - 配置实现

@interface WCRCornerConfig ()
- (void)resetAllColors;
@end

@implementation WCRCornerConfig {
    NSMutableDictionary<NSString *, id> *_store;
}

+ (instancetype)shared {
    static WCRCornerConfig *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[self alloc] init]; });
    return inst;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:WCRConfigPath()];
        _store = saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark 底层读写

- (void)persist {
    NSURL *url = [NSURL fileURLWithPath:WCRConfigPath()];
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:_store
                                                            format:NSPropertyListBinaryFormat_v1_0
                                                           options:0
                                                             error:&error];
    BOOL written = data && [data writeToURL:url options:NSDataWritingAtomic error:&error];
    if (!written) {
        NSLog(@"[WCCornerReverse] config write failed at %@: %@", url.path, error);
    }
}

// KVC expects setters such as setSearchCornerEnabled:, while the X-macro
// accessors intentionally preserve the upstream lowercase selector names.
// Route UI edits through those accessors so clamping and persistence still run.
- (void)setValue:(id)value forKey:(NSString *)key {
    if (!key.length) return;
#define WCR_KVC_SET_BOOL(name, def) \
    if ([key isEqualToString:@#name]) { [self set##name:[value boolValue]]; return; }
    WCR_BOOL_ITEMS(WCR_KVC_SET_BOOL)
#undef WCR_KVC_SET_BOOL
#define WCR_KVC_SET_INT(name, def, lo, hi) \
    if ([key isEqualToString:@#name]) { [self set##name:[value integerValue]]; return; }
    WCR_INT_ITEMS(WCR_KVC_SET_INT)
#undef WCR_KVC_SET_INT
#define WCR_KVC_SET_FLOAT(name, def, lo, hi) \
    if ([key isEqualToString:@#name]) { [self set##name:[value doubleValue]]; return; }
    WCR_FLOAT_ITEMS(WCR_KVC_SET_FLOAT)
#undef WCR_KVC_SET_FLOAT
#define WCR_KVC_SET_STRING(name, def) \
    if ([key isEqualToString:@#name]) { [self set##name:value]; return; }
    WCR_STRING_ITEMS(WCR_KVC_SET_STRING)
#undef WCR_KVC_SET_STRING
#define WCR_KVC_SET_COLOR(base, light, dark) \
    if ([key isEqualToString:@#base "Light"]) { [self set##base##Light:value]; return; } \
    if ([key isEqualToString:@#base "Dark"]) { [self set##base##Dark:value]; return; }
    WCR_COLOR_ITEMS(WCR_KVC_SET_COLOR)
#undef WCR_KVC_SET_COLOR
    [super setValue:value forKey:key];
}

- (void)notifyChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:WCRCornerSettingsChangedNotification
                                                        object:nil];
}

- (BOOL)boolForKey:(NSString *)key def:(BOOL)def {
    id v = _store[key];
    if (!v) {
        _store[key] = @(def);
        [self persist];
        return def;
    }
    return [v boolValue];
}

- (void)setBool:(BOOL)v forKey:(NSString *)key {
    _store[key] = @(v ? YES : NO);
    [self persist];
}

- (long long)llForKey:(NSString *)key def:(long long)def lo:(long long)lo hi:(long long)hi {
    id v = _store[key];
    if (!v) {
        _store[key] = @(def);
        [self persist];
        return def;
    }
    return wcr::clampLL([v longLongValue], lo, hi);
}

- (void)setLL:(long long)v forKey:(NSString *)key lo:(long long)lo hi:(long long)hi {
    _store[key] = @(wcr::clampLL(v, lo, hi));
    [self persist];
}

- (double)dblForKey:(NSString *)key def:(double)def lo:(double)lo hi:(double)hi {
    id v = _store[key];
    if (!v) {
        _store[key] = @(def);
        [self persist];
        return def;
    }
    return wcr::clampD([v doubleValue], lo, hi);
}

- (void)setDbl:(double)v forKey:(NSString *)key lo:(double)lo hi:(double)hi {
    _store[key] = @(wcr::clampD(v, lo, hi));
    [self persist];
}

- (UIColor *)colorForKey:(NSString *)key defHex:(NSUInteger)hex {
    id v = _store[key];
    if (!v) {
        _store[key] = @(hex);
        [self persist];
        return [WCRCornerConfig colorFromHex:hex];
    }
    return [WCRCornerConfig colorFromHex:[v unsignedIntegerValue]];
}

- (void)setColor:(UIColor *)c forKey:(NSString *)key {
    _store[key] = @([WCRCornerConfig hexValueFromColor:c]);
    [self persist];
}

#pragma mark 自动生成存取器

#define WCR_IMPL_BOOL(key, dv)                                     \
    - (BOOL)key { return [self boolForKey:@#key def:(dv)]; }       \
    - (void)set##key:(BOOL)v { [self setBool:v forKey:@#key]; }
WCR_BOOL_ITEMS(WCR_IMPL_BOOL)
#undef WCR_IMPL_BOOL

#define WCR_IMPL_INT(key, dv, lv, hv)                                                     \
    - (NSInteger)key { return (NSInteger)[self llForKey:@#key def:(dv) lo:(lv) hi:(hv)]; } \
    - (void)set##key:(NSInteger)v { [self setLL:v forKey:@#key lo:(lv) hi:(hv)]; }
WCR_INT_ITEMS(WCR_IMPL_INT)
#undef WCR_IMPL_INT

#define WCR_IMPL_FLOAT(key, dv, lv, hv)                                         \
    - (CGFloat)key { return [self dblForKey:@#key def:(dv) lo:(lv) hi:(hv)]; } \
    - (void)set##key:(CGFloat)v { [self setDbl:v forKey:@#key lo:(lv) hi:(hv)]; }
WCR_FLOAT_ITEMS(WCR_IMPL_FLOAT)
#undef WCR_IMPL_FLOAT

#define WCR_K(base, suffix) [@#base stringByAppendingString:suffix]
#define WCR_IMPL_COLOR(base, lhex, dhex)                                        \
    - (UIColor *)base##Light {                                                  \
        return [self colorForKey:WCR_K(base, @"Light") defHex:(lhex)];          \
    }                                                                           \
    - (void)set##base##Light:(UIColor *)c {                                     \
        [self setColor:c forKey:WCR_K(base, @"Light")];                         \
    }                                                                           \
    - (UIColor *)base##Dark {                                                   \
        return [self colorForKey:WCR_K(base, @"Dark") defHex:(dhex)];           \
    }                                                                           \
    - (void)set##base##Dark:(UIColor *)c {                                      \
        [self setColor:c forKey:WCR_K(base, @"Dark")];                          \
    }
WCR_COLOR_ITEMS(WCR_IMPL_COLOR)
#undef WCR_IMPL_COLOR

#define WCR_IMPL_STRING(key, dv)                                         \
    - (NSString *)key {                                                  \
        NSString *v = _store[@#key];                                     \
        if (!v) { v = (dv); _store[@#key] = v; [self persist]; }          \
        return v;                                                        \
    }                                                                    \
    - (void)set##key:(NSString *)v { _store[@#key] = [v copy] ?: @""; [self persist]; }
WCR_STRING_ITEMS(WCR_IMPL_STRING)
#undef WCR_IMPL_STRING

#pragma mark 派生值

- (NSInteger)globalCornerCustomExcludedCount {
    NSString *raw = [self globalCornerCustomExcludedVCClassNames];
    if (raw.length == 0) return 0;
    NSArray *parts = [raw componentsSeparatedByString:@","];
    NSInteger n = 0;
    for (NSString *p in parts) {
        if ([p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length) n++;
    }
    return n;
}

#pragma mark 颜色转换

+ (UIColor *)colorFromHex:(NSUInteger)hex {
    double r, g, b;
    wcr::unpack((unsigned int)hex, r, g, b);
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

+ (NSUInteger)hexValueFromColor:(UIColor *)color {
    if (!color) return 0;
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w = 0;
        if ([color getWhite:&w alpha:&a]) { r = g = b = w; }
    }
    return ((NSUInteger)(r * 255.0 + 0.5) << 16) |
           ((NSUInteger)(g * 255.0 + 0.5) << 8) |
            (NSUInteger)(b * 255.0 + 0.5);
}

+ (NSString *)hexFromColor:(UIColor *)color {
    if (!color) return @"#000000";
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w = 0;
        if ([color getWhite:&w alpha:&a]) { r = g = b = w; }
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (unsigned)(r * 255.0 + 0.5), (unsigned)(g * 255.0 + 0.5), (unsigned)(b * 255.0 + 0.5)];
}

+ (BOOL)darkMode {
    // 与微信一致:优先看当前 trait,其次看系统偏好(后台线程安全)
    if ([NSThread isMainThread]) {
        UITraitCollection *tc = [UIScreen mainScreen].traitCollection;
        if (tc && tc.userInterfaceStyle != UIUserInterfaceStyleUnspecified) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark;
        }
    }
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] != nil;
}

#pragma mark 重置(对应 -confirmResetAllCornerSettings,原实现 8012 字节)

- (void)resetAllCornerSettings {
    // —— 搜索框
    self.searchCornerEnabled = NO;
    self.searchCornerRadius = 15;
    self.searchCornerMargin = 8;
    self.searchCornerBorderSize = 0;
    self.searchClearMaskEnabled = NO;
    self.searchTextPlaceholderEnabled = NO;
    self.searchTextPlaceholder = @"平安喜樂 ✧٩(ˊωˋ*)و✧ ";

    // —— 输入框
    self.inputCornerEnabled = NO;
    self.inputCornerRadius = 15;
    self.inputCornerBorderSize = 0;
    self.inputBoxTransparencyEnabled = NO;
    self.inputBoxTransparencyAlpha = 30;

    // —— 输入法
    self.imeKeyboardCornerEnabled = NO;
    self.imeKeyboardCornerRadius = 30;
    self.imeKeyboardCornerBorderSize = 0;

    // —— 顶栏
    self.topbarCornerEnabled = NO;
    self.topbarCornerRadius = 20;
    self.topbarCornerTopFlatEnabled = NO;
    self.topbarCornerBorderSize = 0;
    self.groupTipsTransparencyEnabled = NO;
    self.groupTipsTransparencyAlpha = 30;

    // —— 底栏
    self.toolbarCornerEnabled = NO;
    self.toolbarCornerRadius = 20;
    self.toolbarCornerBottomFlatEnabled = NO;
    self.toolbarCornerBorderSize = 0;

    // —— 表情 / 图片 / 文件 / 定位
    self.emojiCornerEnabled = NO;
    self.emojiCornerRadius = 15;
    self.emojiCornerBorderSize = 0;
    self.chatImageCornerEnabled = NO;
    self.chatImageCornerRadius = 15;
    self.chatImageCornerBorderSize = 0;
    self.chatFileCornerEnabled = NO;
    self.chatLocationCornerEnabled = NO;

    // —— 气泡
    self.chatBubbleCornerEnabled = NO;
    self.chatBubbleCornerRadius = 12;
    self.chatBubbleCornerBorderSize = 0;
    self.chatBubbleArrowHidden = NO;

    // —— 聊天时间
    self.chatTimeRoundCornerEnabled = NO;
    self.chatTimeRoundCornerRadius = 8;
    self.chatTimeRoundCornerBorderSize = 0;
    self.chatTimeRoundBackgroundEnabled = NO;
    self.chatTimeRoundTextColorEnabled = NO;

    // —— 消息引用
    self.msgReferCornerEnabled = NO;
    self.msgReferCornerRadius = 10;
    self.msgReferCornerBorderSize = 0;
    self.msgReferColorEnabled = NO;

    // —— 拍一拍
    self.systemMessageCornerEnabled = NO;
    self.systemMessageCornerRadius = 10;
    self.systemMessageCornerBorderSize = 0;
    self.systemMessageColorEnabled = NO;

    // —— 系统通知
    self.systemNoticeCornerEnabled = NO;
    self.systemNoticeCornerRadius = 10;
    self.systemNoticeCornerBorderSize = 0;
    self.systemNoticeColorEnabled = NO;

    // —— 语音转文字
    self.voiceTranslateCornerEnabled = NO;
    self.voiceTranslateCornerRadius = 10;
    self.voiceTranslateCornerBorderSize = 0;
    self.voiceTranslateColorEnabled = NO;

    // —— 快捷回复气泡(重置时仍会写,原实现同样处理)
    // self.quickReplyMsgCornerRadius = 25;  // 属于快捷回复模块,本板块不暴露

    // —— 朋友圈(整体圆角/赞评菜单默认开)
    self.momentCornerEnabled = NO;
    self.momentCornerUnifiedEnabled = YES;
    self.momentOperateMenuCornerEnabled = YES;
    self.momentCornerRadius = 10;
    self.momentCornerBorderSize = 0;

    // —— 视频号 / 服务号
    self.finderCornerEnabled = NO;
    self.finderCornerRadius = 10;
    self.finderCornerBorderSize = 0;
    self.serviceCornerEnabled = NO;
    self.serviceCornerRadius = 10;
    self.serviceCornerBorderSize = 0;

    // —— 加号菜单
    self.plusMenuCornerEnabled = NO;
    self.plusMenuCornerRadius = 15;
    self.plusMenuBorderSize = 0;
    self.plusMenuBgColorEnabled = NO;
    self.plusMenuTextColorEnabled = NO;
    self.plusMenuIconColorEnabled = NO;

    // —— 发送按钮
    self.sendPublishButtonCornerEnabled = NO;
    self.sendPublishButtonCornerRadius = 10;
    self.sendPublishButtonCornerBorderSize = 0;

    // —— 系统弹窗
    self.systemPopupCornerEnabled = NO;
    self.systemPopupCornerRadius = 15;
    self.systemPopupCornerBorderSize = 0;

    // —— 左滑菜单
    self.mainFrameSwipeMenuCornerEnabled = YES;
    self.mainFrameSwipeMenuCornerRadius = 20;

    // —— 颜色全部回到默认(原实现逐个 setXxxColorLight/Dark)
    [self resetAllColors];

    [self persist];
}

- (void)resetAllColors {
#define WCR_RESET_COLOR(base, lhex, dhex)                            \
    [self set##base##Light:[WCRCornerConfig colorFromHex:(lhex)]];    \
    [self set##base##Dark:[WCRCornerConfig colorFromHex:(dhex)]];
    WCR_COLOR_ITEMS(WCR_RESET_COLOR)
#undef WCR_RESET_COLOR
}

@end
