#import "DDAvatarRound.h"

@implementation DDAvatarCornerSettingsViewController {
    id _originalDelegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD头像圆角";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    _tableViewManager = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];
    
    _originalDelegate = _tableViewManager.delegate;
    _tableViewManager.delegate = self;
    
    [self buildTable];
}

- (void)buildTable {
    [_tableViewManager clearAllSection];
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
    
    // ========== 头像圆角区块 ==========
    WCTableViewSectionManager *avatarSection = [[objc_getClass("WCTableViewSectionManager") alloc] init];
    BOOL isOn = [defaults boolForKey:kRoundAvatarKey];
    [avatarSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onMainSwitchChanged:) target:self title:@"启用圆角头像" on:isOn]];
    
    if (isOn) {
        float radius = [defaults floatForKey:kAvatarCornerRadiusKey];
        if (radius == 0) radius = 1.0f;
        NSString *rightValue = [NSString stringWithFormat:@"%.1f", radius];
        WCTableViewCellManager *radiusCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(onAvatarRadiusCellTapped) target:self title:@"↳设置圆角程度" rightValue:rightValue];
        radiusCell.userInfo = @"AvatarRadiusCell";
        [avatarSection addCell:radiusCell];
    }
    
    [_tableViewManager addSection:avatarSection];
    
    // ========== 列表圆角区块 ==========
    WCTableViewSectionManager *listSection = [[objc_getClass("WCTableViewSectionManager") alloc] init];
    BOOL isListOn = [defaults boolForKey:kListCornerEnabledKey];
    [listSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onListCornerSwitchChanged:) target:self title:@"启用列表圆角" on:isListOn]];
    
    if (isListOn) {
        float listRadius = [defaults floatForKey:kListCornerRadiusKey];
        if (listRadius == 0) listRadius = 8.0f;
        NSString *rightValue = [NSString stringWithFormat:@"%.0fpt", listRadius];
        WCTableViewCellManager *radiusCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(onListRadiusCellTapped) target:self title:@"↳列表圆角半径" rightValue:rightValue];
        radiusCell.userInfo = @"ListRadiusCell";
        [listSection addCell:radiusCell];
        
        CGFloat pinnedHeight = [defaults doubleForKey:kPinnedSectionHeightKey];
        NSString *pinnedStr = pinnedHeight > 0 ? [NSString stringWithFormat:@"%.0fpt", pinnedHeight] : @"默认";
        WCTableViewCellManager *pinnedCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(onPinnedHeightCellTapped) target:self title:@"置顶会话距顶部间距" rightValue:pinnedStr];
        pinnedCell.userInfo = @"PinnedHeightCell";
        [listSection addCell:pinnedCell];
        
        CGFloat gap = [defaults doubleForKey:kBelowPinnedGapKey];
        NSString *gapStr = gap > 0 ? [NSString stringWithFormat:@"%.0fpt", gap] : @"默认";
        WCTableViewCellManager *gapCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(onGapCellTapped) target:self title:@"普通会话距置顶间距" rightValue:gapStr];
        gapCell.userInfo = @"GapCell";
        [listSection addCell:gapCell];
    }
    
    [_tableViewManager addSection:listSection];
    [_tableViewManager reloadTableView];
}

- (void)onMainSwitchChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
    [defaults setBool:sender.isOn forKey:kRoundAvatarKey];
    [defaults synchronize];
    
    isRoundAvatarEnabled = sender.isOn;
    
    [self buildTable];
    [self showRestartAlert];
}

- (void)onAvatarRadiusCellTapped {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
    float currentRadius = [defaults floatForKey:kAvatarCornerRadiusKey];
    if (currentRadius == 0) currentRadius = 1.0f;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置圆角程度" 
                                                                   message:@"输入 0.1 ~ 1.0 之间的数值\n0.1 = 轻微圆角\n1.0 = 完全圆形" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"圆角程度";
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.text = [NSString stringWithFormat:@"%.1f", currentRadius];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        float val = [text floatValue];
        if (val < 0.1f) val = 0.1f;
        if (val > 1.0f) val = 1.0f;
        [defaults setFloat:val forKey:kAvatarCornerRadiusKey];
        [defaults synchronize];
        
        customCornerRadius = val;
        
        [self buildTable];
        [self showRestartAlert];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onListCornerSwitchChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
    [defaults setBool:sender.isOn forKey:kListCornerEnabledKey];
    [defaults synchronize];
    
    isListCornerEnabled = sender.isOn;
    if (!sender.isOn) {
        customListCornerRadius = 0.0f;
    } else {
        float r = [defaults floatForKey:kListCornerRadiusKey];
        customListCornerRadius = (r > 0) ? r : 8.0f;
    }
    
    [self buildTable];
    [self showRestartAlert];
}

- (void)onListRadiusCellTapped {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
    float currentRadius = [defaults floatForKey:kListCornerRadiusKey];
    if (currentRadius == 0) currentRadius = 8.0f;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置列表圆角半径" 
                                                                   message:@"输入 0 ~ 30 之间的数值（pt）\n0 = 无圆角\n30 = 完全圆角" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"圆角半径";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%.0f", currentRadius];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        float val = [text floatValue];
        if (val < 0) val = 0;
        if (val > 30) val = 30;
        [defaults setFloat:val forKey:kListCornerRadiusKey];
        [defaults synchronize];
        
        customListCornerRadius = val;
        
        [self buildTable];
        [self showRestartAlert];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onPinnedHeightCellTapped {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
    CGFloat currentHeight = [defaults doubleForKey:kPinnedSectionHeightKey];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置置顶间距" 
                                                                   message:@"输入置顶会话距离顶部的间距（pt）\n留空或输入 0 表示使用默认值" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"间距（pt）";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = currentHeight > 0 ? [NSString stringWithFormat:@"%.0f", currentHeight] : @"";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        if (text.length > 0) {
            CGFloat val = [text floatValue];
            if (val < 0) val = 0;
            [defaults setDouble:val forKey:kPinnedSectionHeightKey];
            pinnedSectionHeight = val;
        } else {
            [defaults removeObjectForKey:kPinnedSectionHeightKey];
            pinnedSectionHeight = 0;
        }
        [defaults synchronize];
        
        [self buildTable];
        [self showRestartAlert];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onGapCellTapped {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
    CGFloat currentGap = [defaults doubleForKey:kBelowPinnedGapKey];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置普通间距" 
                                                                   message:@"输入普通会话距离置顶会话的间距（pt）\n留空或输入 0 表示使用默认值" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"间距（pt）";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = currentGap > 0 ? [NSString stringWithFormat:@"%.0f", currentGap] : @"";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        if (text.length > 0) {
            CGFloat val = [text floatValue];
            if (val < 0) val = 0;
            [defaults setDouble:val forKey:kBelowPinnedGapKey];
            belowPinnedContentGap = val;
        } else {
            [defaults removeObjectForKey:kBelowPinnedGapKey];
            belowPinnedContentGap = 0;
        }
        [defaults synchronize];
        
        [self buildTable];
        [self showRestartAlert];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showRestartAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:@"设置已保存，需要重启微信才能生效。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *later = [UIAlertAction actionWithTitle:@"稍后重启" style:UIAlertActionStyleDefault handler:nil];
    UIAlertAction *restart = [UIAlertAction actionWithTitle:@"立即重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        exit(0);
    }];
    [alert addAction:later];
    [alert addAction:restart];
    [self presentViewController:alert animated:YES completion:nil];
}

// WCTableViewManager delegate forwarding
- (BOOL)respondsToSelector:(SEL)aSelector {
    return [super respondsToSelector:aSelector] || [_originalDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if ([_originalDelegate respondsToSelector:aSelector]) return _originalDelegate;
    return [super forwardingTargetForSelector:aSelector];
}

@end
