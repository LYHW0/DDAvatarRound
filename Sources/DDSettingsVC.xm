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
    
    WCTableViewSectionManager *section = [[objc_getClass("WCTableViewSectionManager") alloc] init];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
    BOOL isOn = [defaults boolForKey:kRoundAvatarKey];
    
    [section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onMainSwitchChanged:) target:self title:@"启用圆角头像" on:isOn]];
    
    if (isOn) {
        float radius = [defaults floatForKey:kAvatarCornerRadiusKey];
        if (radius == 0) radius = 1.0f;
        NSString *rightValue = [NSString stringWithFormat:@"%.1f", radius];
        WCTableViewCellManager *radiusCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(onRadiusCellTapped) target:self title:@"↳设置圆角程度" rightValue:rightValue];
        radiusCell.userInfo = @"RadiusCell";
        [section addCell:radiusCell];
    }
    
    [_tableViewManager addSection:section];
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

- (void)onRadiusCellTapped {
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

- (void)showRestartAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:@"头像形状设置已保存，需要重启微信才能生效。"
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
