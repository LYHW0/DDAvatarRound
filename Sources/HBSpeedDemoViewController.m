//
//  HBSpeedDemoViewController.m
//

#import "HBSpeedDemoViewController.h"
#import "HBSpeedConfig.h"
#import "HBSpeedHook.h"
#import "HBSpeedAlert.h"
#import "HBSpeedMenuItem.h"
#import "HBSpeedCellFactory.h"

@interface HBSpeedDemoViewController ()
@property (nonatomic, strong) HBSpeedMenuItem *item;
@property (nonatomic, strong) UIView *animView;
@end

@implementation HBSpeedDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"特色类功能";
    self.item  = [HBSpeedMenuItem uiSpeedItem];
}

#pragma mark - 表结构（与原插件同一块：一个分区 + 一行）

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return section == 0 ? @"自定义" : @"效果验证";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0) return [HBSpeedCellFactory footerForItem:self.item];
    return @"点一下跑一个 1 秒动画，速度值不同，走完的快慢就不同（验证用，不属于原插件）。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return [HBSpeedCellFactory cellForItem:self.item target:self action:@selector(hb_speedCellTapped)];
    }
    static NSString * const kId = @"anim";
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:kId];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kId];
    c.textLabel.text       = @"跑个动画";
    c.detailTextLabel.text = HBSpeedDisplayText();
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        [self hb_speedCellTapped];
    } else {
        [self runDemoAnimation];
    }
}

#pragma mark - 点击行（对应原 -setEditUiWindowsSpeeds @0x9C2558）

- (void)hb_speedCellTapped
{
    __weak typeof(self) weakSelf = self;
    [HBSpeedAlert showEditorFrom:self item:self.item onChanged:^(float newValue) {
        // 原实现：写完配置 → reloadTableData
        [weakSelf.tableView reloadData];
    }];
}

#pragma mark - 验证动画

- (void)runDemoAnimation
{
    if (!self.animView) {
        self.animView = [[UIView alloc] initWithFrame:CGRectMake(20, 300, 60, 60)];
        self.animView.backgroundColor = [UIColor systemBlueColor];
        self.animView.layer.cornerRadius = 12.0;
        [self.view addSubview:self.animView];
    }

    // 让本窗口吃到当前速度（等价于原插件重启后 setWindowLevel: 打进去的效果）
    float s = HBGetUISpeed();
    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        [w.layer setSpeed:(s == HBSpeedDefaultValue ? 1.0f : s)];
    }

    self.animView.frame = CGRectMake(20, 300, 60, 60);
    CGFloat maxX = CGRectGetWidth(self.view.bounds) - 80;

    [UIView animateWithDuration:1.0
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.animView.frame = CGRectMake(maxX, 300, 60, 60);
    }
                     completion:nil];
}

@end
