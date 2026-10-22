//
//  WPGroupSettingViewController.m
//

#import "WPGroupSettingViewController.h"
#import "WPCustomGroupViewController.h"
#import "WPGroupColorPickerController.h"
#import <stdlib.h>

/// 功能设置区每一行的下标（与逆向的 row 一一对应）
typedef NS_ENUM(NSInteger, WPGroupSettingRow) {
    WPGroupSettingRowExpand = 0,          // 点击展开设置 / 点击收起设置
    WPGroupSettingRowEnableFilter,        // 启用会话分组
    WPGroupSettingRowHideIndicator,       // 隐藏分组指示
    WPGroupSettingRowHideBadge,           // 隐藏分组角标
    WPGroupSettingRowTopFilter,           // 启用置顶过滤
    WPGroupSettingRowGlobalGesture,       // 启用全屏手势
    WPGroupSettingRowBottomBarGesture,    // 启用底栏手势
    WPGroupSettingRowRemoveTransition,    // 移除过渡动画
    WPGroupSettingRowHideAllBadge,        // 隐藏"全部"角标
    WPGroupSettingRowHideServiceBadge,    // 隐藏"服务号"角标
    WPGroupSettingRowHideBackground,      // 隐藏背景颜色
    WPGroupSettingRowFilterDuplicate,     // 过滤重复联系人
    WPGroupSettingRowDisableFoldTop,      // 禁用折叠视图
    WPGroupSettingRowBackgroundColor,     // 背景颜色
    WPGroupSettingRowIndicatorColor,      // 指示器颜色
    WPGroupSettingRowSelectedFontColor,   // 选中字体颜色
    WPGroupSettingRowUnselectedFontColor, // 未选字体颜色
    WPGroupSettingRowFontSize,            // 字体大小
    WPGroupSettingRowDefaultIndex,        // 默认索引
    WPGroupSettingRowIndicatorStyle,      // 指示器样式
    WPGroupSettingRowCount
};

static NSString * const kCellDefault = @"DefaultCell";
static NSString * const kCellSwitch  = @"SwitchCell";
static NSString * const kCellValue   = @"ValueCell";
static NSString * const kCellColor   = @"ColorCell";
static NSString * const kCellExpand  = @"ExpandCell";
static NSString * const kCellGroup   = @"GroupCell";
static NSString * const kCellRestart = @"RestartCell";

@interface WPGroupSettingViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSString *> *groups;
@property (nonatomic, assign) BOOL isSettingsSectionExpanded;
@property (nonatomic, assign) NSInteger settingsSwitchCount;
- (void)loadGroups;
- (void)saveGroups;
- (void)handleGroupListChanged:(NSNotification *)note;
- (void)setupTableView;
- (UITableViewCell *)switchCell:(UITableView *)tableView title:(NSString *)title row:(WPGroupSettingRow)row on:(BOOL)on;
- (UITableViewCell *)colorCell:(UITableView *)tableView title:(NSString *)title hex:(NSString *)hex;
- (NSString *)subtitleForGroup:(NSString *)name;
- (void)switchChanged:(UISwitch *)sender;
- (void)post:(NSString *)name;
- (void)showColorPickerForType:(NSInteger)type;
- (void)showFontSizePicker;
- (void)showDefaultIndexPicker;
- (void)showIndicatorStylePicker;
- (void)presentActionSheet:(UIAlertController *)sheet;
- (void)showGroupSelector;
- (void)showTagSelector;
- (void)showCustomGroupEditorWithName:(nullable NSString *)name;
- (void)resetDefaultSettings;
- (void)handleAddButtonLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)toast:(NSString *)text;
- (void)deleteGroupAtIndex:(NSInteger)row;
- (void)showEditNameAlertForGroupAtIndex:(NSInteger)index;
- (void)updateGroupNameAtIndex:(NSInteger)index withNewName:(NSString *)newName originalName:(NSString *)original;
- (void)restartApplication;
- (UIColor *)systemBackgroundColor;
@end

@implementation WPGroupSettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"分组设置";
    self.view.backgroundColor = [self systemBackgroundColor];

    _groups = [NSMutableArray array];
    _settingsSwitchCount = WPGroupSettingRowCount;
    _isSettingsSectionExpanded = NO;

    [self setupTableView];
    [self loadGroups];

    // 右上角 + ：点击添加分组，长按切换编辑模式
    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *plus = [UIImage systemImageNamed:@"plus"];
    [addBtn setImage:plus forState:UIControlStateNormal];
    addBtn.frame = CGRectMake(0, 0, 32, 32);
    [addBtn addTarget:self action:@selector(showGroupSelector) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(handleAddButtonLongPress:)];
    lp.minimumPressDuration = 0.5;
    [addBtn addGestureRecognizer:lp];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:addBtn];

    if (self.startInEditMode) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tableView setEditing:YES animated:YES];
        });
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleGroupListChanged:)
                                                 name:WPGroupListChanged object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIColor *)systemBackgroundColor {
    if (@available(iOS 13.0, *)) return [UIColor systemGroupedBackgroundColor];
    return [UIColor groupTableViewBackgroundColor];
}

#pragma mark - 数据

- (void)loadGroups {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    NSMutableArray *list = [NSMutableArray arrayWithArray:[WPGroupEngine.shared groupList]];

    // 自定义分组名一定要在列表里（防止手改配置漏掉）
    for (NSString *name in cfg.customGroupList.allKeys) {
        if (![list containsObject:name]) [list addObject:name];
    }
    self.groups = list;
    [self.tableView reloadData];
}

- (void)saveGroups {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    cfg.groupFilterList = [self.groups copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupListChanged object:nil];
    [WPGroupEngine.shared reloadSessions];
    if ([self.delegate respondsToSelector:@selector(groupSettingsDidChange:)]) {
        [self.delegate groupSettingsDidChange:self];
    }
}

- (void)handleGroupListChanged:(NSNotification *)note {
    [self loadGroups];
}

#pragma mark - 表格

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.isSettingsSectionExpanded ? self.settingsSwitchCount : 1;
    }
    if (section == 1) return self.groups.count;
    if (section == 2) return 1;
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"功能设置";
    if (section == 1) return @"当前分组";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return @"左滑可编辑或删除分组（自定义分组可编辑成员）\n添加标签内有类型选择（如删除后可重新找到）\n点击右上角+可重置默认颜色配置\n长按右上角+按钮可切换编辑模式";
    }
    return nil;
}

#pragma mark - 行构建

- (UITableViewCell *)switchCell:(UITableView *)tableView title:(NSString *)title
                            row:(WPGroupSettingRow)row on:(BOOL)on {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSwitch];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellSwitch];
        UISwitch *sw = [[UISwitch alloc] init];
        sw.tag = 1000 + row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if (@available(iOS 13.0, *)) sw.onTintColor = [UIColor systemGreenColor];
    }
    cell.textLabel.text = title;
    UISwitch *sw = (UISwitch *)cell.accessoryView;
    sw.on = on;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WPGroupConfig *cfg = WPGroupConfig.shared;

    if (indexPath.section == 0) {
        NSInteger row = indexPath.row;
        if (row == WPGroupSettingRowExpand) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellExpand];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellExpand];
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.textLabel.font = [UIFont systemFontOfSize:16];
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            cell.textLabel.text = self.isSettingsSectionExpanded ? @"点击收起设置" : @"点击展开设置";
            return cell;
        }

        switch (row) {
            case WPGroupSettingRowEnableFilter:
                return [self switchCell:tableView title:@"启用会话分组" row:row on:cfg.enableGroupFilter];
            case WPGroupSettingRowHideIndicator:
                return [self switchCell:tableView title:@"隐藏分组指示" row:row on:cfg.hideGroupIndicator];
            case WPGroupSettingRowHideBadge:
                return [self switchCell:tableView title:@"隐藏分组角标" row:row on:cfg.hideGroupBadge];
            case WPGroupSettingRowTopFilter:
                return [self switchCell:tableView title:@"启用置顶过滤" row:row on:cfg.enableTopFilter];
            case WPGroupSettingRowGlobalGesture:
                return [self switchCell:tableView title:@"启用全屏手势" row:row on:cfg.enableGlobalSwitchGroupGesture];
            case WPGroupSettingRowBottomBarGesture:
                return [self switchCell:tableView title:@"启用底栏手势" row:row on:cfg.enableBottomBarSwitchGroupGesture];
            case WPGroupSettingRowRemoveTransition:
                // 开关表示"移除动画"，即 enableGroupTransitionAnimation 取反
                return [self switchCell:tableView title:@"移除过渡动画" row:row on:!cfg.enableGroupTransitionAnimation];
            case WPGroupSettingRowHideAllBadge:
                return [self switchCell:tableView title:@"隐藏\"全部\"角标" row:row on:cfg.hideAllGroupBadge];
            case WPGroupSettingRowHideServiceBadge:
                return [self switchCell:tableView title:@"隐藏\"服务号\"角标" row:row on:cfg.hideServiceAccountBadge];
            case WPGroupSettingRowHideBackground:
                return [self switchCell:tableView title:@"隐藏背景颜色" row:row on:cfg.hideGroupBackgroundColor];
            case WPGroupSettingRowFilterDuplicate:
                return [self switchCell:tableView title:@"过滤重复联系人" row:row on:cfg.enableFilterDuplicateContacts];
            case WPGroupSettingRowDisableFoldTop:
                return [self switchCell:tableView title:@"禁用折叠视图" row:row on:cfg.disableFoldTopSession];

            case WPGroupSettingRowBackgroundColor:
                return [self colorCell:tableView title:@"背景颜色"
                                 hex:[cfg colorStringForKey:@"groupBackgroundColor" darkKey:@"groupBackgroundColorDark"]];
            case WPGroupSettingRowIndicatorColor:
                return [self colorCell:tableView title:@"指示器颜色"
                                 hex:[cfg colorStringForKey:@"groupIndicatorColor" darkKey:@"groupIndicatorColorDark"]];
            case WPGroupSettingRowSelectedFontColor:
                return [self colorCell:tableView title:@"选中字体颜色"
                                 hex:[cfg colorStringForKey:@"groupFontColor" darkKey:@"groupFontColorDark"]];
            case WPGroupSettingRowUnselectedFontColor:
                return [self colorCell:tableView title:@"未选字体颜色"
                                 hex:[cfg colorStringForKey:@"groupUnselectedFontColor" darkKey:@"groupUnselectedFontColorDark"]];

            case WPGroupSettingRowFontSize: {
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellValue];
                if (!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellValue];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
                cell.textLabel.text = @"字体大小";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f", cfg.groupFontSize];
                cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
                return cell;
            }
            case WPGroupSettingRowDefaultIndex: {
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellValue];
                if (!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellValue];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
                cell.textLabel.text = @"默认索引";
                NSInteger idx = cfg.defaultGroupIndex;
                NSString *name = (idx >= 0 && idx < (NSInteger)self.groups.count) ? self.groups[idx] : @"全部";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld - %@", (long)(idx + 1),
                                             [cfg mappedGroupName:name]];
                cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
                return cell;
            }
            case WPGroupSettingRowIndicatorStyle: {
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellValue];
                if (!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellValue];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
                cell.textLabel.text = @"指示器样式";
                cell.detailTextLabel.text = (cfg.groupIndicatorStyle == 0) ? @"线条" : @"圆圈";
                cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
                return cell;
            }
            default: break;
        }
    }

    if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellGroup];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellGroup];
        }
        NSString *name = self.groups[indexPath.row];
        cell.textLabel.text = [cfg mappedGroupName:name];
        cell.detailTextLabel.text = [self subtitleForGroup:name];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.imageView.image = nil;
        cell.showsReorderControl = YES;
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellRestart];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellRestart];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor systemRedColor];
    }
    cell.textLabel.text = @"重启应用";
    return cell;
}

- (NSString *)subtitleForGroup:(NSString *)name {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    NSArray *members = cfg.customGroupList[name];
    if (members) return [NSString stringWithFormat:@"自定义 · %lu 位成员", (unsigned long)members.count];
    if ([name isEqualToString:WPGroupNameAll]) return @"全部会话";
    if ([name isEqualToString:WPGroupNameChatRoom]) return @"群聊会话";
    if ([name isEqualToString:WPGroupNameFriend]) return @"好友单聊";
    if ([name isEqualToString:WPGroupNameService]) return @"服务号";
    if ([name isEqualToString:WPGroupNameEnterprise]) return @"企业号";
    return @"微信标签";
}

- (UITableViewCell *)colorCell:(UITableView *)tableView title:(NSString *)title hex:(NSString *)hex {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellColor];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellColor];
        UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
        swatch.tag = 99;
        swatch.layer.cornerRadius = 6;
        swatch.layer.borderWidth = 0.5;
        swatch.layer.borderColor = [UIColor separatorColor].CGColor;
        swatch.userInteractionEnabled = NO;
        cell.accessoryView = swatch;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.textLabel.text = title;
    UIView *swatch = [cell.accessoryView viewWithTag:99];
    swatch.backgroundColor = [WPGroupConfig colorFromHexString:hex] ?: [UIColor lightGrayColor];
    return cell;
}

#pragma mark - 开关

- (void)switchChanged:(UISwitch *)sender {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    WPGroupSettingRow row = (WPGroupSettingRow)(sender.tag - 1000);
    BOOL on = sender.isOn;

    switch (row) {
        case WPGroupSettingRowEnableFilter:
            cfg.enableGroupFilter = on;
            [self post:WPGroupFilterSettingChanged];
            break;
        case WPGroupSettingRowHideIndicator:
            cfg.hideGroupIndicator = on;
            [self post:WPGroupIndicatorSettingChanged];
            break;
        case WPGroupSettingRowHideBadge:
            cfg.hideGroupBadge = on;
            [self post:WPGroupBadgeSettingChanged];
            break;
        case WPGroupSettingRowTopFilter:
            cfg.enableTopFilter = on;
            [self post:WPGroupTopFilterSettingChanged];
            break;
        case WPGroupSettingRowGlobalGesture:
            cfg.enableGlobalSwitchGroupGesture = on;
            [self post:WPGroupGlobalGestureSettingChanged];
            break;
        case WPGroupSettingRowBottomBarGesture:
            cfg.enableBottomBarSwitchGroupGesture = on;
            [self post:WPGroupBottomBarGestureSettingChanged];
            break;
        case WPGroupSettingRowRemoveTransition:
            cfg.enableGroupTransitionAnimation = !on;
            [self post:WPGroupTransitionAnimationSettingChanged];
            break;
        case WPGroupSettingRowHideAllBadge:
            cfg.hideAllGroupBadge = on;
            [self post:WPGroupAllBadgeSettingChanged];
            break;
        case WPGroupSettingRowHideServiceBadge:
            cfg.hideServiceAccountBadge = on;
            [self post:WPGroupServiceAccountBadgeSettingChanged];
            break;
        case WPGroupSettingRowHideBackground:
            cfg.hideGroupBackgroundColor = on;
            [self post:WPGroupBackgroundColorSettingChanged];
            break;
        case WPGroupSettingRowFilterDuplicate:
            cfg.enableFilterDuplicateContacts = on;
            [self post:WPGroupFilterDuplicateContactsSettingChanged];
            break;
        case WPGroupSettingRowDisableFoldTop:
            cfg.disableFoldTopSession = on;
            [self post:WPGroupFoldTopSessionSettingChanged];
            break;
        default: break;
    }

    [WPGroupEngine.shared reloadSessions];
    if ([self.delegate respondsToSelector:@selector(groupSettingsDidChange:)]) {
        [self.delegate groupSettingsDidChange:self];
    }
}

- (void)post:(NSString *)name {
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:nil];
}

#pragma mark - 点击

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WPGroupConfig *cfg = WPGroupConfig.shared;

    if (indexPath.section == 0) {
        NSInteger row = indexPath.row;
        if (row == WPGroupSettingRowExpand) {
            self.isSettingsSectionExpanded = !self.isSettingsSectionExpanded;
            [tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                     withRowAnimation:UITableViewRowAnimationFade];
            return;
        }
        if (row == WPGroupSettingRowBackgroundColor) {
            [self showColorPickerForType:0];
        } else if (row == WPGroupSettingRowIndicatorColor) {
            [self showColorPickerForType:1];
        } else if (row == WPGroupSettingRowSelectedFontColor) {
            [self showColorPickerForType:2];
        } else if (row == WPGroupSettingRowUnselectedFontColor) {
            [self showColorPickerForType:3];
        } else if (row == WPGroupSettingRowFontSize) {
            [self showFontSizePicker];
        } else if (row == WPGroupSettingRowDefaultIndex) {
            [self showDefaultIndexPicker];
        } else if (row == WPGroupSettingRowIndicatorStyle) {
            [self showIndicatorStylePicker];
        }
        return;
    }

    if (indexPath.section == 2) {
        [self restartApplication];
        return;
    }

    if (indexPath.section == 1) {
        NSString *name = self.groups[indexPath.row];
        NSArray *members = cfg.customGroupList[name];
        if (members) {
            [self showCustomGroupEditorWithName:name];
        }
    }
}

#pragma mark - 各种选择器

- (void)showColorPickerForType:(NSInteger)type {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    NSString *value = nil;
    NSString *title = nil;
    switch (type) {
        case 0: title = @"背景颜色"; value = [cfg colorStringForKey:@"groupBackgroundColor" darkKey:@"groupBackgroundColorDark"]; break;
        case 1: title = @"指示器颜色"; value = [cfg colorStringForKey:@"groupIndicatorColor" darkKey:@"groupIndicatorColorDark"]; break;
        case 2: title = @"选中字体颜色"; value = [cfg colorStringForKey:@"groupFontColor" darkKey:@"groupFontColorDark"]; break;
        default: title = @"未选字体颜色"; value = [cfg colorStringForKey:@"groupUnselectedFontColor" darkKey:@"groupUnselectedFontColorDark"]; break;
    }

    WPGroupColorPickerController *picker = [[WPGroupColorPickerController alloc] initWithTitle:title hex:value];
    __weak typeof(self) weakSelf = self;
    picker.completion = ^(NSString *hex) {
        __strong typeof(weakSelf) self = weakSelf;
        WPGroupConfig *c = WPGroupConfig.shared;
        BOOL dark = NO;
        if (@available(iOS 13.0, *)) dark = (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
        switch (type) {
            case 0: dark ? (c.groupBackgroundColorDark = hex) : (c.groupBackgroundColor = hex); break;
            case 1: dark ? (c.groupIndicatorColorDark = hex) : (c.groupIndicatorColor = hex); break;
            case 2: dark ? (c.groupFontColorDark = hex) : (c.groupFontColor = hex); break;
            default: dark ? (c.groupUnselectedFontColorDark = hex) : (c.groupUnselectedFontColor = hex); break;
        }
        [self post:WPGroupFontColorSettingChanged];
        [self post:WPGroupBackgroundColorSettingChanged];
        [self post:WPGroupIndicatorSettingChanged];
        [self.tableView reloadData];
        if ([self.delegate respondsToSelector:@selector(groupSettingsDidChange:)]) {
            [self.delegate groupSettingsDidChange:self];
        }
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showFontSizePicker {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置字体大小"
                                                                  message:@"请输入字体大小 (10-20)"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.text = [NSString stringWithFormat:@"%.1f", cfg.groupFontSize];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        __strong typeof(weakSelf) self = weakSelf;
        CGFloat v = [alert.textFields.firstObject.text doubleValue];
        if (v < 10) v = 10;
        if (v > 20) v = 20;
        WPGroupConfig.shared.groupFontSize = v;
        [self post:WPGroupFontSizeSettingChanged];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:WPGroupSettingRowFontSize inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
        if ([self.delegate respondsToSelector:@selector(groupSettingsDidChange:)]) {
            [self.delegate groupSettingsDidChange:self];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showDefaultIndexPicker {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择默认索引"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSInteger current = cfg.defaultGroupIndex;
    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < (NSInteger)self.groups.count; i++) {
        NSString *name = [cfg mappedGroupName:self.groups[i]];
        NSString *title = (i == current)
            ? [NSString stringWithFormat:@"%ld - %@ (当前)", (long)(i + 1), name]
            : [NSString stringWithFormat:@"%ld - %@", (long)(i + 1), name];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            __strong typeof(weakSelf) self = weakSelf;
            WPGroupConfig.shared.defaultGroupIndex = i;
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:WPGroupSettingRowDefaultIndex inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationNone];
            if ([self.delegate respondsToSelector:@selector(groupSettingsDidChange:)]) {
                [self.delegate groupSettingsDidChange:self];
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet];
}

- (void)showIndicatorStylePicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择指示器样式"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *titles = @[@"线条", @"圆圈"];
    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < (NSInteger)titles.count; i++) {
        [sheet addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            __strong typeof(weakSelf) self = weakSelf;
            WPGroupConfig.shared.groupIndicatorStyle = i;
            [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupIndicatorSettingChanged object:nil];
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:WPGroupSettingRowIndicatorStyle inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationNone];
            if ([self.delegate respondsToSelector:@selector(groupSettingsDidChange:)]) {
                [self.delegate groupSettingsDidChange:self];
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet];
}

- (void)presentActionSheet:(UIAlertController *)sheet {
    // iPad 需要 sourceView
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                    CGRectGetMaxY(self.view.bounds) - 60, 1, 1);
        sheet.popoverPresentationController.permittedArrowDirections = (UIPopoverArrowDirection)0;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - 添加分组

- (void)showGroupSelector {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择分组类型"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"标签" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf showTagSelector];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"自选" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf showCustomGroupEditorWithName:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"重置默认设置" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf resetDefaultSettings];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet];
}

- (void)showTagSelector {
    NSArray<NSString *> *labels = nil;
    if ([self.delegate respondsToSelector:@selector(labelNamesForGroupSettings:)]) {
        labels = [self.delegate labelNamesForGroupSettings:self];
    }
    if (!labels.count) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"标签"
                                                                      message:@"宿主没有提供标签列表，无法添加标签分组"
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择标签"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSString *label in labels) {
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            __strong typeof(weakSelf) self = weakSelf;
            if (![self.groups containsObject:label]) {
                [self.groups addObject:label];
                [self saveGroups];
                [self.tableView reloadData];
                NSInteger row = [self.groups indexOfObject:label];
                if (row != NSNotFound) {
                    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:1]
                                          atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
                }
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet];
}

- (void)showCustomGroupEditorWithName:(NSString *)name {
    WPCustomGroupViewController *vc = [[WPCustomGroupViewController alloc] initWithGroupName:name];
    __weak typeof(self) weakSelf = self;
    vc.isEditMode = (name.length > 0);
    vc.saveCompletionBlock = ^(NSString *groupName, NSArray<NSString *> *members) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!groupName.length || !members.count) return;
        if (![self.groups containsObject:groupName]) {
            [self.groups addObject:groupName];
        }
        [self saveGroups];
        [self.tableView reloadData];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)resetDefaultSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WPGroup"
                                                                  message:@"确定要重置默认设置吗？"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        __strong typeof(weakSelf) self = weakSelf;
        [[WPGroupConfig shared] resetAppearanceDefaults];
        [self post:WPGroupBackgroundColorSettingChanged];
        [self post:WPGroupIndicatorSettingChanged];
        [self post:WPGroupFontColorSettingChanged];
        [self post:WPGroupFontSizeSettingChanged];
        [self.tableView reloadData];
        if ([self.delegate respondsToSelector:@selector(groupSettingsDidChange:)]) {
            [self.delegate groupSettingsDidChange:self];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 长按编辑模式

- (void)handleAddButtonLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    BOOL editing = !self.tableView.isEditing;
    [self.tableView setEditing:editing animated:YES];
    [self toast:editing ? @"已进入编辑模式" : @"已退出编辑模式"];
}

- (void)toast:(NSString *)text {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:text
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

#pragma mark - 编辑与左滑

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1) return NO;
    NSString *name = self.groups[indexPath.row];
    NSArray *systemGroups = @[WPGroupNameAll, WPGroupNameChatRoom, WPGroupNameFriend,
                              WPGroupNameService, WPGroupNameEnterprise];
    return ![systemGroups containsObject:name];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSString *name = self.groups[from.row];
    [self.groups removeObjectAtIndex:from.row];
    [self.groups insertObject:name atIndex:to.row];
    [self saveGroups];
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView
                    editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1) return nil;
    NSString *name = self.groups[indexPath.row];
    WPGroupConfig *cfg = WPGroupConfig.shared;
    NSArray *systemGroups = @[WPGroupNameAll, WPGroupNameChatRoom, WPGroupNameFriend,
                              WPGroupNameService, WPGroupNameEnterprise];
    if ([systemGroups containsObject:name]) return nil;

    NSMutableArray *actions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    if (cfg.customGroupList[name]) {
        UITableViewRowAction *members = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                          title:@"编辑成员"
                                                                        handler:^(UITableViewRowAction *a, NSIndexPath *ip) {
            __strong typeof(weakSelf) self = weakSelf;
            [self showCustomGroupEditorWithName:name];
        }];
        members.backgroundColor = [UIColor systemGreenColor];
        [actions addObject:members];
    }

    UITableViewRowAction *rename = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                     title:@"编辑"
                                                                   handler:^(UITableViewRowAction *a, NSIndexPath *ip) {
        __strong typeof(weakSelf) self = weakSelf;
        [self showEditNameAlertForGroupAtIndex:ip.row];
    }];
    rename.backgroundColor = [UIColor systemBlueColor];
    [actions addObject:rename];

    UITableViewRowAction *delete = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                     title:@"删除"
                                                                   handler:^(UITableViewRowAction *a, NSIndexPath *ip) {
        __strong typeof(weakSelf) self = weakSelf;
        [self deleteGroupAtIndex:ip.row];
    }];
    [actions addObject:delete];

    return actions;
}

- (void)deleteGroupAtIndex:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.groups.count) return;
    NSString *name = self.groups[row];
    WPGroupConfig *cfg = WPGroupConfig.shared;

    [self.groups removeObjectAtIndex:row];
    if (cfg.customGroupList[name]) {
        NSMutableDictionary *m = [cfg.customGroupList mutableCopy];
        [m removeObjectForKey:name];
        cfg.customGroupList = m;
    }
    [self saveGroups];
    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:1]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)showEditNameAlertForGroupAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.groups.count) return;
    NSString *name = self.groups[index];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"修改分组名称"
                                                                  message:@"请输入新的分组名称"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = name;
        tf.text = name;
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        __strong typeof(weakSelf) self = weakSelf;
        NSString *newName = [alert.textFields.firstObject.text
                             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (!newName.length) return;
        [self updateGroupNameAtIndex:index withNewName:newName originalName:name];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

/// 重命名走的是"显示名映射"，系统分组/标签/自定义分组都能改名
- (void)updateGroupNameAtIndex:(NSInteger)index withNewName:(NSString *)newName originalName:(NSString *)original {
    if (index < 0 || index >= (NSInteger)self.groups.count) return;
    WPGroupConfig *cfg = WPGroupConfig.shared;

    NSMutableDictionary *mapping = [cfg.groupNameMapping mutableCopy] ?: [NSMutableDictionary dictionary];
    if ([newName isEqualToString:original]) {
        [mapping removeObjectForKey:original];
    } else {
        mapping[original] = newName;
    }
    cfg.groupNameMapping = mapping;

    [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupListChanged object:nil];
    [self.tableView reloadData];
    if ([self.delegate respondsToSelector:@selector(groupSettingsDidChange:)]) {
        [self.delegate groupSettingsDidChange:self];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete) {
        [self deleteGroupAtIndex:indexPath.row];
    }
}

#pragma mark - 重启

- (void)restartApplication {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重启应用"
                                                                  message:@"部分设置需要重启后生效，是否立即重启？"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        __strong typeof(weakSelf) self = weakSelf;
        if ([self.delegate respondsToSelector:@selector(groupSettingsRequestRestart:)]) {
            [self.delegate groupSettingsRequestRestart:self];
        } else {
            // 宿主没实现时，退到后台由系统回收（不硬崩溃）
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                exit(0);
            });
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
