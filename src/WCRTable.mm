//
//  WCRTable.mm
//  表格框架 —— 等价替代原插件依赖的微信私有 WCTableViewManager / WCTableViewSectionManager
//
//  逆向得知原插件的调用签名(全部在 reloadTableData 里出现):
//    [WCTableViewSectionManager sectionManage] -> setHeaderTitle: / setFooterTitle:
//    [section cellWithSel:target:title:rightValue:accessoryType:]
//    [section switchCellWithSel:target:title:switchOn:]
//    [section normalCellForSel:target:title:rightView:]
//    [section centerCellForSel:target:title:]
//    [manager addSection:] / [manager clearAllSection] / [tableview reloadData]
//
//  这里用系统 UITableView 复刻同样的分组卡片视觉,保证不依赖微信私有类也能编译运行。
//

#import "WCRCorner.h"

#pragma mark - Row

@implementation WCRTableRow

+ (instancetype)rowWithKind:(WCRRowKind)kind title:(NSString *)title {
    WCRTableRow *r = [WCRTableRow new];
    r.kind = kind;
    r.title = title;
    return r;
}

+ (instancetype)switchRow:(NSString *)title on:(BOOL)on action:(void (^)(BOOL))action {
    WCRTableRow *r = [self rowWithKind:WCRRowKindSwitch title:title];
    r.on = on;
    r.switchAction = action;
    return r;
}

+ (instancetype)valueRow:(NSString *)title value:(NSString *)value action:(void (^)(void))action {
    WCRTableRow *r = [self rowWithKind:WCRRowKindValue title:title];
    r.valueText = value;
    r.action = action;
    return r;
}

+ (instancetype)accessoryRow:(NSString *)title rightView:(UIView *)view action:(void (^)(void))action {
    WCRTableRow *r = [self rowWithKind:WCRRowKindDisclosure title:title];
    r.rightView = view;
    r.action = action;
    return r;
}

+ (instancetype)buttonRow:(NSString *)title destructive:(BOOL)destructive action:(void (^)(void))action {
    WCRTableRow *r = [self rowWithKind:WCRRowKindButton title:title];
    r.destructive = destructive;
    r.action = action;
    return r;
}

@end

#pragma mark - Section

@implementation WCRTableSection

+ (instancetype)sectionWithHeader:(NSString *)header footer:(NSString *)footer {
    WCRTableSection *s = [WCRTableSection new];
    s.header = header;
    s.footer = footer;
    s.rows = [NSMutableArray array];
    return s;
}

- (void)addRow:(WCRTableRow *)row {
    if (row) [self.rows addObject:row];
}

@end

#pragma mark - Cell

@interface WCRTableCell : UITableViewCell
@property (nonatomic, strong) UILabel *wcrTitleLabel;
@property (nonatomic, strong) UILabel *wcrSubtitleLabel;
@property (nonatomic, strong) UISwitch *wcrSwitch;
@property (nonatomic, strong) UILabel *wcrValueLabel;
@property (nonatomic, strong) UIImageView *wcrArrow;
@property (nonatomic, strong) UIView *wcrRightContainer;
- (void)configureWithRow:(WCRTableRow *)row target:(id)target;
@end

@implementation WCRTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;

        _wcrTitleLabel = [UILabel new];
        _wcrTitleLabel.font = [UIFont systemFontOfSize:17];
        _wcrTitleLabel.textColor = [UIColor labelColor];
        _wcrTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_wcrTitleLabel];

        _wcrSubtitleLabel = [UILabel new];
        _wcrSubtitleLabel.font = [UIFont systemFontOfSize:12];
        _wcrSubtitleLabel.textColor = [UIColor secondaryLabelColor];
        _wcrSubtitleLabel.numberOfLines = 3;
        _wcrSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_wcrSubtitleLabel];

        _wcrSwitch = [UISwitch new];
        _wcrSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_wcrSwitch];

        _wcrValueLabel = [UILabel new];
        _wcrValueLabel.font = [UIFont systemFontOfSize:15];
        _wcrValueLabel.textColor = [UIColor secondaryLabelColor];
        _wcrValueLabel.textAlignment = NSTextAlignmentRight;
        _wcrValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_wcrValueLabel];

        _wcrArrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        _wcrArrow.tintColor = [UIColor tertiaryLabelColor];
        _wcrArrow.contentMode = UIViewContentModeScaleAspectFit;
        _wcrArrow.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_wcrArrow];

        _wcrRightContainer = [UIView new];
        _wcrRightContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_wcrRightContainer];

        // 标题:左边距 16,垂直居中
        [NSLayoutConstraint activateConstraints:@[
            [_wcrTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_wcrTitleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        ]];
        // 副标题在标题下方
        [NSLayoutConstraint activateConstraints:@[
            [_wcrSubtitleLabel.leadingAnchor constraintEqualToAnchor:_wcrTitleLabel.leadingAnchor],
            [_wcrSubtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_wcrSubtitleLabel.topAnchor constraintEqualToAnchor:_wcrTitleLabel.bottomAnchor constant:2],
            [_wcrSubtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        ]];
        // 开关:右侧居中
        [NSLayoutConstraint activateConstraints:@[
            [_wcrSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_wcrSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_wcrTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_wcrSwitch.leadingAnchor constant:-8],
        ]];
        // 箭头
        [NSLayoutConstraint activateConstraints:@[
            [_wcrArrow.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_wcrArrow.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_wcrArrow.widthAnchor constraintEqualToConstant:8],
            [_wcrArrow.heightAnchor constraintEqualToConstant:14],
        ]];
        // 右值
        [NSLayoutConstraint activateConstraints:@[
            [_wcrValueLabel.trailingAnchor constraintEqualToAnchor:_wcrArrow.leadingAnchor constant:-6],
            [_wcrValueLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_wcrTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_wcrValueLabel.leadingAnchor constant:-8],
        ]];
        // 自定义右视图
        [NSLayoutConstraint activateConstraints:@[
            [_wcrRightContainer.trailingAnchor constraintEqualToAnchor:_wcrArrow.leadingAnchor constant:-6],
            [_wcrRightContainer.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_wcrRightContainer.heightAnchor constraintEqualToConstant:24],
            [_wcrRightContainer.widthAnchor constraintEqualToConstant:44],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _wcrSwitch.hidden = YES;
    _wcrValueLabel.hidden = YES;
    _wcrArrow.hidden = YES;
    _wcrRightContainer.hidden = YES;
    _wcrSubtitleLabel.hidden = YES;
    for (UIView *v in _wcrRightContainer.subviews) [v removeFromSuperview];
    [_wcrSwitch removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
}

- (void)configureWithRow:(WCRTableRow *)row target:(id)target {
    self.wcrTitleLabel.text = row.title;
    self.wcrTitleLabel.textColor = row.destructive ? [UIColor systemRedColor] : [UIColor labelColor];
    if (row.subtitle.length) {
        self.wcrSubtitleLabel.hidden = NO;
        self.wcrSubtitleLabel.text = row.subtitle;
    } else {
        self.wcrSubtitleLabel.hidden = YES;
    }

    switch (row.kind) {
        case WCRRowKindSwitch: {
            self.wcrSwitch.hidden = NO;
            self.wcrSwitch.on = row.on;
            [self.wcrSwitch addTarget:target action:@selector(wcrSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            break;
        }
        case WCRRowKindValue: {
            self.wcrSwitch.hidden = YES;
            self.wcrValueLabel.hidden = NO;
            self.wcrArrow.hidden = NO;
            self.wcrValueLabel.text = row.valueText;
            break;
        }
        case WCRRowKindDisclosure: {
            self.wcrSwitch.hidden = YES;
            self.wcrArrow.hidden = NO;
            if (row.rightView) {
                self.wcrRightContainer.hidden = NO;
                row.rightView.translatesAutoresizingMaskIntoConstraints = NO;
                [self.wcrRightContainer addSubview:row.rightView];
                [NSLayoutConstraint activateConstraints:@[
                    [row.rightView.centerXAnchor constraintEqualToAnchor:self.wcrRightContainer.centerXAnchor],
                    [row.rightView.centerYAnchor constraintEqualToAnchor:self.wcrRightContainer.centerYAnchor],
                ]];
            }
            break;
        }
        case WCRRowKindButton: {
            self.wcrSwitch.hidden = YES;
            self.wcrArrow.hidden = YES;
            self.accessoryType = UITableViewCellAccessoryNone;
            self.wcrTitleLabel.textAlignment = NSTextAlignmentCenter;
            [self.wcrTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16].active = YES;
            self.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        }
        default:
            break;
    }
}

@end

#pragma mark - TableViewController

@interface WCRTableViewController ()
@property (nonatomic, strong) UIImpactFeedbackGenerator *haptic;
@end

@implementation WCRTableViewController

- (instancetype)init {
    if ((self = [super init])) {
        _sections = [NSMutableArray array];
        _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    UITableView *tv;
    if (@available(iOS 13.0, *)) {
        tv = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    } else {
        tv = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    }
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.dataSource = self;
    tv.delegate = self;
    tv.backgroundColor = [UIColor clearColor];
    tv.separatorColor = [UIColor separatorColor];
    [tv registerClass:[WCRTableCell class] forCellReuseIdentifier:@"WCRCell"];
    [self.view addSubview:tv];
    self.tableView = tv;
    [NSLayoutConstraint activateConstraints:@[
        [tv.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadTableData];
}

- (void)addSection:(WCRTableSection *)section {
    if (section) [self.sections addObject:section];
}

- (void)reloadTableData {
    [self.tableView reloadData];
}

- (void)runHaptic {
    [self.haptic prepare];
    [self.haptic impactOccurred];
}

#pragma mark 数据源

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.sections[(NSUInteger)section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[(NSUInteger)section].header;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.sections[(NSUInteger)section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCRTableCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WCRCell" forIndexPath:indexPath];
    WCRTableRow *row = self.sections[(NSUInteger)indexPath.section].rows[(NSUInteger)indexPath.row];
    // 用 tag 记住行号,供开关回调定位
    cell.tag = indexPath.section * 1000 + indexPath.row;
    [cell configureWithRow:row target:self];
    return cell;
}

#pragma mark 交互

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WCRTableRow *row = self.sections[(NSUInteger)indexPath.section].rows[(NSUInteger)indexPath.row];
    if (row.kind == WCRRowKindSwitch) return;
    [self runHaptic];
    if (row.action) row.action();
}

- (void)wcrSwitchChanged:(UISwitch *)sender {
    WCRTableCell *cell = nil;
    UIView *v = sender;
    while (v && ![v isKindOfClass:[WCRTableCell class]]) v = v.superview;
    cell = (WCRTableCell *)v;
    if (!cell) return;
    NSInteger section = cell.tag / 1000;
    NSInteger rowIdx = cell.tag % 1000;
    if (section >= (NSInteger)self.sections.count) return;
    WCRTableSection *sec = self.sections[(NSUInteger)section];
    if (rowIdx >= (NSInteger)sec.rows.count) return;
    WCRTableRow *row = sec.rows[(NSUInteger)rowIdx];
    row.on = sender.isOn;
    [self runHaptic];
    if (row.switchAction) row.switchAction(sender.isOn);
}

@end
