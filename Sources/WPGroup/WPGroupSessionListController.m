//
//  WPGroupSessionListController.m
//

#import "WPGroupSessionListController.h"
#import "WPGroupConfig.h"

@interface WPGroupSessionListController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<WPGroupSession *> *topSessions;
@property (nonatomic, copy) NSArray<WPGroupSession *> *normalSessions;
@end

@implementation WPGroupSessionListController

+ (NSArray<WPGroupSession *> *)demoSessions {
    NSMutableArray *arr = [NSMutableArray array];

    WPGroupSession *s1 = [WPGroupSession sessionWithWxid:@"wxid_zhangsan" name:@"张三"];
    s1.unreadCount = 3;
    s1.labelNames = @[@"同事"];
    [arr addObject:s1];

    WPGroupSession *s2 = [WPGroupSession sessionWithWxid:@"12345678@chatroom" name:@"产品讨论组"];
    s2.isGroup = YES;
    s2.unreadCount = 12;
    s2.isTop = YES;
    s2.labelNames = @[@"同事", @"项目"];
    [arr addObject:s2];

    WPGroupSession *s3 = [WPGroupSession sessionWithWxid:@"wxid_lisi" name:@"李四"];
    s3.isTop = YES;
    [arr addObject:s3];

    WPGroupSession *s4 = [WPGroupSession sessionWithWxid:@"gh_abc123" name:@"微信支付"];
    s4.isBrandService = YES;
    s4.unreadCount = 1;
    [arr addObject:s4];

    WPGroupSession *s5 = [WPGroupSession sessionWithWxid:@"wxid_wangwu" name:@"王五"];
    s5.labelNames = @[@"客户"];
    [arr addObject:s5];

    WPGroupSession *s6 = [WPGroupSession sessionWithWxid:@"87654321@chatroom" name:@"家人群"];
    s6.isGroup = YES;
    s6.labelNames = @[@"家人"];
    [arr addObject:s6];

    WPGroupSession *s7 = [WPGroupSession sessionWithWxid:@"corp_user@openim" name:@"企业通知"];
    s7.isEnterprise = YES;
    [arr addObject:s7];

    return arr;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleGroupChanged:)
                                                 name:WPGroupFilterSettingChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleGroupChanged:)
                                                 name:WPGroupSessionsReloaded object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleGroupChanged:(NSNotification *)note {
    [self reloadFromEngine];
}

- (void)reloadFromEngine {
    WPGroupSessionInfo *info = WPGroupEngine.shared.currentSelectGroup;
    self.topSessions = info.topSessions ?: @[];
    self.normalSessions = info.normalSessions ?: @[];
    [self.tableView reloadData];
}

- (void)reloadWithSessions:(NSArray<WPGroupSession *> *)sessions {
    self.topSessions = @[];
    self.normalSessions = sessions ?: @[];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.topSessions.count ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.topSessions.count && section == 0) return @"置顶会话";
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.topSessions.count && section == 0) return self.topSessions.count;
    return self.normalSessions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"SessionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
    }
    WPGroupSession *s = nil;
    if (self.topSessions.count && indexPath.section == 0) {
        s = self.topSessions[indexPath.row];
    } else {
        s = self.normalSessions[indexPath.row];
    }
    cell.textLabel.text = s.displayName;
    cell.detailTextLabel.text = s.wxid;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.textLabel.textColor = s.isTop ? [UIColor secondaryLabelColor] : [UIColor labelColor];
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (s.unreadCount > 0) {
        UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
        badge.backgroundColor = [UIColor systemRedColor];
        badge.textColor = [UIColor whiteColor];
        badge.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.layer.cornerRadius = 12;
        badge.clipsToBounds = YES;
        badge.text = s.unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)s.unreadCount];
        cell.accessoryView = badge;
    } else {
        cell.accessoryView = nil;
    }
    return cell;
}

@end
