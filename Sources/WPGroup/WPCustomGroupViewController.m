//
//  WPCustomGroupViewController.m
//

#import "WPCustomGroupViewController.h"
#import "WPGroupConfig.h"
#import "WPGroupEngine.h"

static NSString * const kGroupNameCell = @"GroupNameCell";
static NSString * const kMemberCell = @"MemberCell";
static NSString * const kAddMemberCell = @"AddMemberCell";

@interface WPCustomGroupViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *groupNameField;
@property (nonatomic, strong) NSMutableArray<NSString *> *selectedContactNames;
@property (nonatomic, copy) NSString *groupNameDraft;
- (void)setupUI;
- (void)loadExistingGroupData;
- (void)showContactSelector;
- (void)groupNameFieldDidChange:(UITextField *)tf;
- (void)cancelButtonTapped;
- (void)saveButtonTapped;
- (void)showAlert:(NSString *)title message:(NSString *)message;

@end

@implementation WPCustomGroupViewController

- (instancetype)initWithGroupName:(NSString *)groupName {
    if ((self = [super init])) {
        _groupName = [groupName copy];
        _isEditMode = groupName.length > 0;
        _selectedContactNames = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.isEditMode ? @"编辑自定义分组" : @"新建自定义分组";
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(cancelButtonTapped)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone
                                        target:self action:@selector(saveButtonTapped)];

    [self setupUI];
    [self loadExistingGroupData];
}

#pragma mark - UI

- (void)setupUI {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = self.view.backgroundColor;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
}

- (void)loadExistingGroupData {
    if (!self.isEditMode || !self.groupName.length) {
        self.groupNameDraft = self.groupName ?: @"";
        return;
    }
    NSArray *members = WPGroupConfig.shared.customGroupList[self.groupName];
    if ([members isKindOfClass:[NSArray class]]) {
        [self.selectedContactNames removeAllObjects];
        [self.selectedContactNames addObjectsFromArray:members];
    }
    self.groupNameDraft = self.groupName;
}

#pragma mark - 表格

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;                        // 分组名称
    return self.selectedContactNames.count + 1;        // 成员 + 添加成员
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"分组名称";
    if (section == 1) return @"分组成员";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return @"添加的成员会出现在这个分组里，一个分组至少需要一位成员。";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kGroupNameCell];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kGroupNameCell];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(16, 0, CGRectGetWidth(tableView.bounds) - 32, 44)];
            tf.placeholder = @"请输入分组名称";
            tf.textColor = [UIColor labelColor];
            tf.returnKeyType = UIReturnKeyDone;
            tf.delegate = self;
            tf.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [tf addTarget:self action:@selector(groupNameFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            [cell.contentView addSubview:tf];
            self.groupNameField = tf;
        }
        self.groupNameField.text = self.groupNameDraft;
        return cell;
    }

    if (indexPath.row < (NSInteger)self.selectedContactNames.count) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kMemberCell];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMemberCell];
        }
        NSString *wxid = self.selectedContactNames[indexPath.row];
        NSString *display = nil;
        if ([self.dataSource respondsToSelector:@selector(customGroup:displayNameForWxid:)]) {
            display = [self.dataSource customGroup:self displayNameForWxid:wxid];
        }
        cell.textLabel.text = display.length ? display : wxid;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAddMemberCell];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kAddMemberCell];
        cell.textLabel.textColor = [UIColor systemGreenColor];
    }
    cell.textLabel.text = @"添加成员";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row == (NSInteger)self.selectedContactNames.count) {
        [self showContactSelector];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && style == UITableViewCellEditingStyleDelete
        && indexPath.row < (NSInteger)self.selectedContactNames.count) {
        [self.selectedContactNames removeObjectAtIndex:indexPath.row];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1 && indexPath.row < (NSInteger)self.selectedContactNames.count;
}

#pragma mark - 成员选择

- (void)showContactSelector {
    if ([self.dataSource respondsToSelector:@selector(customGroup:presentPickerWithSelected:completion:)]) {
        __weak typeof(self) weakSelf = self;
        [self.dataSource customGroup:self
              presentPickerWithSelected:[self.selectedContactNames copy]
                             completion:^(NSArray<NSString *> *wxids) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!wxids) return;
            [self.selectedContactNames removeAllObjects];
            [self.selectedContactNames addObjectsFromArray:wxids];
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
        return;
    }

    // 宿主没接选择器：内置一个简单多选列表
    NSArray<NSDictionary<NSString *, NSString *> *> *members = nil;
    if ([self.dataSource respondsToSelector:@selector(selectableMembersForCustomGroup:)]) {
        members = [self.dataSource selectableMembersForCustomGroup:self];
    }
    if (!members.count) {
        [self showAlert:@"提示" message:@"宿主没有提供成员选择器，无法添加成员"];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"添加成员"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *item in members) {
        NSString *wxid = item[@"wxid"];
        NSString *name = item[@"name"] ?: wxid;
        if ([self.selectedContactNames containsObject:wxid]) continue;
        [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            __strong typeof(weakSelf) self = weakSelf;
            [self.selectedContactNames addObject:wxid];
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                    CGRectGetMidY(self.view.bounds), 1, 1);
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - 文本

- (void)groupNameFieldDidChange:(UITextField *)tf {
    self.groupNameDraft = tf.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - 保存 / 取消

- (void)cancelButtonTapped {
    if (self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)saveButtonTapped {
    NSString *name = [self.groupNameField.text ?: self.groupNameDraft
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!name.length) {
        [self showAlert:@"错误" message:@"请输入分组名称"];
        return;
    }
    if (!self.selectedContactNames.count) {
        [self showAlert:@"错误" message:@"请添加至少一个分组成员"];
        return;
    }

    WPGroupConfig *cfg = WPGroupConfig.shared;
    NSMutableDictionary *list = [cfg.customGroupList mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *originalName = self.isEditMode ? self.groupName : nil;

    if (originalName.length && ![originalName isEqualToString:name]) {
        [list removeObjectForKey:originalName];
    }
    list[name] = [self.selectedContactNames copy];
    self.groupNameDraft = name;
    cfg.customGroupList = list;

    // 加进分组列表（放在最后，和插件一致）
    if (![cfg.groupFilterList containsObject:name]) {
        NSMutableArray *filter = [cfg.groupFilterList mutableCopy];
        [filter addObject:name];
        cfg.groupFilterList = filter;
    }
    // 改名时同步更新显示名映射，避免旧的映射残留
    if (originalName.length && ![originalName isEqualToString:name]) {
        NSMutableDictionary *mapping = [cfg.groupNameMapping mutableCopy];
        [mapping removeObjectForKey:originalName];
        cfg.groupNameMapping = mapping;
    }

    if (self.saveCompletionBlock) self.saveCompletionBlock(name, [self.selectedContactNames copy]);

    [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupListChanged object:nil];
    [WPGroupEngine.shared reloadSessions];

    [self cancelButtonTapped];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
