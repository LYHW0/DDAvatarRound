//
//  DYLSettingsController.m
//  字体 + 主题设置界面（原 MYFontViewController / MYThemesViewController 的通用版）
//

#import "DYLAppearance.h"
#import "DYLFontManager.h"
#import "DYLThemeManager.h"

#if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#define DYL_HAS_UTTYPE 1
#else
#define DYL_HAS_UTTYPE 0
#endif

#pragma mark - 字体列表

@interface DYLFontListController : UITableViewController
@end

@implementation DYLFontListController {
    NSArray<NSString *> *_imported;
    NSArray<NSString *> *_families;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择字体";
    [self reloadData];
}

- (void)reloadData {
    _imported = [[DYLFontManager shared] registeredFontNames];
    _families = [[DYLFontManager shared] systemFontFamilies];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"已导入字体" : @"系统字体";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? _imported.count + 1 : _families.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"fontcell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];

    NSString *name = nil;
    if (indexPath.section == 0) {
        name = indexPath.row == 0 ? @"（默认系统字体，不改）" : _imported[indexPath.row - 1];
    } else {
        name = _families[indexPath.row];
    }

    cell.textLabel.text = name;
    cell.textLabel.font = [UIFont systemFontOfSize:17];

    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    BOOL selected = [cfg.fontPostScriptName isEqualToString:name] ||
                    (indexPath.section == 0 && indexPath.row == 0 && cfg.fontPostScriptName.length == 0);
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];

    if (indexPath.section == 0 && indexPath.row == 0) {
        cfg.fontPostScriptName = nil;
        cfg.fontDisplayName = nil;
        cfg.fontEnabled = NO;
        [cfg synchronize];
    } else {
        NSString *name = indexPath.section == 0 ? _imported[indexPath.row - 1] : _families[indexPath.row];
        cfg.fontPostScriptName = name;
        cfg.fontDisplayName = name;
        cfg.fontEnabled = YES;
        [cfg synchronize];
    }
    DYLAppearanceReload();
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYLAppearanceDidChangeNotification" object:nil];
    [self.tableView reloadData];

    // 返回上一页时刷新
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 && indexPath.row > 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    NSString *name = _imported[indexPath.row - 1];
    [[DYLFontManager shared] removeFontNamed:name error:NULL];
    DYLAppearanceReload();
    [self reloadData];
}

@end

#pragma mark - 主题列表

@interface DYLThemeListController : UITableViewController
@end

@implementation DYLThemeListController {
    NSArray<DYLTheme *> *_themes;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择主题";
    _themes = [[DYLThemeManager shared] themes];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                     target:self
                                                     action:@selector(importTheme)];
}

- (void)reloadData {
    _themes = [[DYLThemeManager shared] themes];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _themes.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"themecell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];

    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (indexPath.row == 0) {
        cell.textLabel.text = @"不使用主题（原生外观）";
        cell.detailTextLabel.text = nil;
        cell.accessoryType = cfg.themeEnabled ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
    } else {
        DYLTheme *t = _themes[indexPath.row - 1];
        cell.textLabel.text = t.name;
        cell.detailTextLabel.text = t.identifier;
        BOOL on = cfg.themeEnabled && [cfg.themeName isEqualToString:t.identifier];
        cell.accessoryType = on ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 0) {
        [[DYLThemeManager shared] activateTheme:nil];
    } else {
        [[DYLThemeManager shared] activateTheme:_themes[indexPath.row - 1]];
    }
    [self.tableView reloadData];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYLAppearanceDidChangeNotification" object:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row > 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    DYLTheme *t = _themes[indexPath.row - 1];
    [[DYLThemeManager shared] removeThemeWithIdentifier:t.identifier error:NULL];
    [self reloadData];
}

- (void)importTheme {
    NSArray *types = nil;
#if DYL_HAS_UTTYPE
    if (@available(iOS 14.0, *)) {
        types = @[ UTTypeFolder, UTTypeZIP, UTTypeItem ];
        UIDocumentPickerViewController *picker =
            [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
        picker.delegate = (id<UIDocumentPickerDelegate>)self;
        picker.allowsMultipleSelection = NO;
        [self presentViewController:picker animated:YES completion:nil];
        return;
    }
#endif
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ @"public.folder", @"public.zip-archive" ]
                                                               inMode:UIDocumentPickerModeImport];
    picker.delegate = (id<UIDocumentPickerDelegate>)self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    NSError *error = nil;
    BOOL ok = [[DYLThemeManager shared] importThemeAtURL:url error:&error];
    [self reloadData];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:ok ? @"导入成功" : @"导入失败"
                                                                  message:ok ? @"主题已切换" : error.localizedDescription
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYLAppearanceDidChangeNotification" object:nil];
}

@end

#pragma mark - 主设置页

@interface DYLSettingsController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) UISlider *scaleSlider;
- (UITableViewCell *)cellWithTitle:(NSString *)title detail:(NSString *)detail;
- (UITableViewCell *)switchCell:(NSString *)title on:(BOOL)on action:(SEL)action;
- (void)toggleFont:(UISwitch *)sw;
- (void)toggleBold:(UISwitch *)sw;
- (void)toggleTheme:(UISwitch *)sw;
- (void)scaleChanged:(UISlider *)sl;
- (void)scaleEnded:(UISlider *)sl;
- (void)pickFont;
- (void)pickTheme;
- (void)presentPickerWithContentTypes:(NSArray *)types;
- (void)dismissSelf;
@end

@implementation DYLSettingsController

+ (void)presentFrom:(UIViewController *)controller {
    DYLSettingsController *vc = [[DYLSettingsController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [controller presentViewController:nav animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"字体与主题";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                     target:self
                                                     action:@selector(dismissSelf)];
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView
                                             selector:@selector(reloadData)
                                                 name:@"DYLAppearanceDidChangeNotification"
                                               object:nil];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark 数据源

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"字体";
    if (section == 1) return @"主题";
    return @"导入 / 其它";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
#if DYL_ENABLE_FONT
    if (section == 0) return 4; // 开关 / 选字体 / 字号 / 粗体
#else
    if (section == 0) return 0;
#endif
#if DYL_ENABLE_THEME
    if (section == 1) return 2; // 开关 / 选主题
#else
    if (section == 1) return 0;
#endif
    return 3; // 导入字体 / 导入主题 / 重置
}

- (UITableViewCell *)cellWithTitle:(NSString *)title detail:(NSString *)detail {
    static NSString *cid = @"dcell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = detail;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (UITableViewCell *)switchCell:(NSString *)title on:(BOOL)on action:(SEL)action {
    UITableViewCell *cell = [self cellWithTitle:title detail:nil];
    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = on;
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];

    if (indexPath.section == 0) {
        if (indexPath.row == 0)
            return [self switchCell:@"自定义字体" on:cfg.fontEnabled action:@selector(toggleFont:)];
        if (indexPath.row == 1) {
            UITableViewCell *c = [self cellWithTitle:@"选择字体"
                                              detail:cfg.fontPostScriptName.length ? cfg.fontDisplayName ?: cfg.fontPostScriptName : @"系统默认"];
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        if (indexPath.row == 2) {
            UITableViewCell *c = [self cellWithTitle:@"字号缩放" detail:[NSString stringWithFormat:@"%.2fx", cfg.fontScale]];
            UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 150, 32)];
            sl.minimumValue = 0.8;
            sl.maximumValue = 1.6;
            sl.value = cfg.fontScale;
            [sl addTarget:self action:@selector(scaleChanged:) forControlEvents:UIControlEventValueChanged];
            [sl addTarget:self action:@selector(scaleEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
            self.scaleSlider = sl;
            c.accessoryView = sl;
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            return c;
        }
        return [self switchCell:@"粗体也使用该字体" on:cfg.mapBoldFont action:@selector(toggleBold:)];
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 0)
            return [self switchCell:@"启用主题" on:cfg.themeEnabled action:@selector(toggleTheme:)];
        DYLTheme *t = [DYLThemeManager shared].currentTheme;
        UITableViewCell *c = [self cellWithTitle:@"选择主题" detail:t ? t.name : @"原生外观"];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }

    if (indexPath.row == 0) {
        UITableViewCell *c = [self cellWithTitle:@"导入字体文件" detail:@"ttf / otf / ttc"];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    if (indexPath.row == 1) {
        UITableViewCell *c = [self cellWithTitle:@"导入主题包" detail:@"主题目录 / zip"];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    UITableViewCell *c = [self cellWithTitle:@"恢复默认" detail:nil];
    c.textLabel.textColor = [UIColor systemRedColor];
    return c;
}

#pragma mark 交互

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];

    if (indexPath.section == 0) {
        if (indexPath.row == 1) {
            [self.navigationController pushViewController:[[DYLFontListController alloc] initWithStyle:UITableViewStyleGrouped]
                                                 animated:YES];
        }
        return;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 1) {
            [self.navigationController pushViewController:[[DYLThemeListController alloc] initWithStyle:UITableViewStyleGrouped]
                                                 animated:YES];
        }
        return;
    }

    if (indexPath.row == 0) { [self pickFont]; return; }
    if (indexPath.row == 1) { [self pickTheme]; return; }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"恢复默认"
                                                                  message:@"字体和主题都会回到系统默认"
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认恢复" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[DYLAppearanceConfig shared] resetAll];
        [[DYLThemeManager shared] activateTheme:nil];
        DYLAppearanceReload();
        [self.tableView reloadData];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYLAppearanceDidChangeNotification" object:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.view;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toggleFont:(UISwitch *)sw {
    [DYLAppearanceConfig shared].fontEnabled = sw.isOn;
    [[DYLAppearanceConfig shared] synchronize];
    if (sw.isOn && [DYLAppearanceConfig shared].fontPostScriptName.length == 0) {
        [self.navigationController pushViewController:[[DYLFontListController alloc] initWithStyle:UITableViewStyleGrouped]
                                             animated:YES];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYLAppearanceDidChangeNotification" object:nil];
}

- (void)toggleBold:(UISwitch *)sw {
    [DYLAppearanceConfig shared].mapBoldFont = sw.isOn;
    [[DYLAppearanceConfig shared] synchronize];
}

- (void)scaleChanged:(UISlider *)sl {
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    cfg.fontScale = roundf(sl.value * 100) / 100.0f;
}

- (void)scaleEnded:(UISlider *)sl {
    [[DYLAppearanceConfig shared] synchronize];
    [self.tableView reloadData];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYLAppearanceDidChangeNotification" object:nil];
}

- (void)toggleTheme:(UISwitch *)sw {
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    cfg.themeEnabled = sw.isOn;
    [cfg synchronize];
    if (!sw.isOn) {
        [[DYLThemeManager shared] activateTheme:nil];
    } else if (![DYLThemeManager shared].currentTheme) {
        [self.navigationController pushViewController:[[DYLThemeListController alloc] initWithStyle:UITableViewStyleGrouped]
                                             animated:YES];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYLAppearanceDidChangeNotification" object:nil];
}

#pragma mark 选择文件

- (void)presentPickerWithContentTypes:(NSArray *)types {
#if DYL_HAS_UTTYPE
    if (@available(iOS 14.0, *)) {
        UIDocumentPickerViewController *picker =
            [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
        picker.delegate = self;
        picker.allowsMultipleSelection = NO;
        [self presentViewController:picker animated:YES completion:nil];
        return;
    }
#endif
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ @"public.item" ]
                                                               inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)pickFont {
#if DYL_HAS_UTTYPE
    if (@available(iOS 14.0, *)) {
        [self presentPickerWithContentTypes:@[ UTTypeFont, UTTypeItem ]];
        return;
    }
#endif
    [self presentPickerWithContentTypes:nil];
}

- (void)pickTheme {
#if DYL_HAS_UTTYPE
    if (@available(iOS 14.0, *)) {
        [self presentPickerWithContentTypes:@[ UTTypeFolder, UTTypeZIP, UTTypeItem ]];
        return;
    }
#endif
    [self presentPickerWithContentTypes:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    NSError *error = nil;
    BOOL ok = NO;

    NSString *ext = url.pathExtension.lowercaseString;
    NSSet *fontExt = [NSSet setWithObjects:@"ttf", @"otf", @"ttc", @"otc", @"woff", @"woff2", nil];

    if ([fontExt containsObject:ext]) {
        ok = [[DYLFontManager shared] importFontAtURL:url error:&error];
    } else {
        ok = [[DYLThemeManager shared] importThemeAtURL:url error:&error];
    }

    [self.tableView reloadData];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:ok ? @"导入成功" : @"导入失败"
                                                                  message:ok ? nil : error.localizedDescription
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYLAppearanceDidChangeNotification" object:nil];
}

@end
