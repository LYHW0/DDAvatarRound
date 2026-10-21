#import "DDAvatarRound.h"

@interface DDAvatarCornerSettingsViewController ()
@end

@implementation DDAvatarCornerSettingsViewController {
    NSUserDefaults *defaults;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD头像圆角";
    self.tableView.backgroundColor = [UIColor colorWithRed:0.949 green:0.949 blue:0.949 alpha:1.0];
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 8;
    }
    
    defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        BOOL isOn = [defaults boolForKey:kRoundAvatarKey];
        return isOn ? 2 : 1;
    } else {
        BOOL isOn = [defaults boolForKey:kListCornerEnabledKey];
        return isOn ? 4 : 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"头像圆角" : @"列表圆角";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"调整头像的圆角程度，1.0为完全圆形";
    } else {
        return @"为微信、通讯录、发现、我的页面列表添加卡片式圆角";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"启用头像圆角";
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.on = [defaults boolForKey:kRoundAvatarKey];
            [switchView addTarget:self action:@selector(onAvatarSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = switchView;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"圆角程度";
            float radius = [defaults floatForKey:kAvatarCornerRadiusKey];
            if (radius == 0) radius = 1.0f;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f", radius];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"启用列表圆角";
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.on = [defaults boolForKey:kListCornerEnabledKey];
            [switchView addTarget:self action:@selector(onListCornerSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = switchView;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"圆角半径";
            float radius = [defaults floatForKey:kListCornerRadiusKey];
            if (radius == 0) radius = 16.0f;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0fpt", radius];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"左右边距";
            float margin = [defaults floatForKey:kSectionMarginKey];
            if (margin == 0) margin = 15.0f;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0fpt", margin];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"分组间距";
            float spacing = [defaults floatForKey:kSectionSpacingKey];
            if (spacing == 0) spacing = 12.0f;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0fpt", spacing];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0 && indexPath.row == 1) {
        [self showAvatarRadiusAlert];
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        [self showListCornerRadiusAlert];
    } else if (indexPath.section == 1 && indexPath.row == 2) {
        [self showSectionMarginAlert];
    } else if (indexPath.section == 1 && indexPath.row == 3) {
        [self showSectionSpacingAlert];
    }
}

- (void)onAvatarSwitchChanged:(UISwitch *)sender {
    [defaults setBool:sender.isOn forKey:kRoundAvatarKey];
    [defaults synchronize];
    isRoundAvatarEnabled = sender.isOn;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)onListCornerSwitchChanged:(UISwitch *)sender {
    [defaults setBool:sender.isOn forKey:kListCornerEnabledKey];
    [defaults synchronize];
    isListCornerEnabled = sender.isOn;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:@"需要重启微信以应用列表圆角效果"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAvatarRadiusAlert {
    float currentRadius = [defaults floatForKey:kAvatarCornerRadiusKey];
    if (currentRadius == 0) currentRadius = 1.0f;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"调整圆角程度"
                                                                   message:@"输入 0.0 到 1.0 之间的值"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [NSString stringWithFormat:@"%.2f", currentRadius];
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        float val = [text floatValue];
        if (val < 0) val = 0;
        if (val > 1.0f) val = 1.0f;
        
        [defaults setFloat:val forKey:kAvatarCornerRadiusKey];
        [defaults synchronize];
        customCornerRadius = val;
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showListCornerRadiusAlert {
    float currentRadius = [defaults floatForKey:kListCornerRadiusKey];
    if (currentRadius == 0) currentRadius = 16.0f;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"调整圆角半径"
                                                                   message:@"输入 0 到 40 之间的值（推荐 12-20）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [NSString stringWithFormat:@"%.0f", currentRadius];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        float val = [text floatValue];
        if (val < 0) val = 0;
        if (val > 40) val = 40;
        
        [defaults setFloat:val forKey:kListCornerRadiusKey];
        [defaults synchronize];
        customListCornerRadius = val;
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:1]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSectionMarginAlert {
    float currentMargin = [defaults floatForKey:kSectionMarginKey];
    if (currentMargin == 0) currentMargin = 15.0f;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"调整左右边距"
                                                                   message:@"输入 0 到 30 之间的值（推荐 10-20）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [NSString stringWithFormat:@"%.0f", currentMargin];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        float val = [text floatValue];
        if (val < 0) val = 0;
        if (val > 30) val = 30;
        
        [defaults setFloat:val forKey:kSectionMarginKey];
        [defaults synchronize];
        globalSectionMargin = val;
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:2 inSection:1]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSectionSpacingAlert {
    float currentSpacing = [defaults floatForKey:kSectionSpacingKey];
    if (currentSpacing == 0) currentSpacing = 12.0f;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"调整分组间距"
                                                                   message:@"输入 0 到 30 之间的值（推荐 8-15）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [NSString stringWithFormat:@"%.0f", currentSpacing];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        float val = [text floatValue];
        if (val < 0) val = 0;
        if (val > 30) val = 30;
        
        [defaults setFloat:val forKey:kSectionSpacingKey];
        [defaults synchronize];
        globalSectionSpacing = val;
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:3 inSection:1]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
