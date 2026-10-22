//
//  HBSpeedCellFactory.m
//

#import "HBSpeedCellFactory.h"
#import "HBSpeedConfig.h"
#import <objc/message.h>

@implementation HBSpeedCellFactory

+ (NSString *)rightValueText
{
    return HBSpeedDisplayText();   // @"%.1f"
}

+ (UITableViewCell *)cellForItem:(HBSpeedMenuItem *)item
                          target:(id)target
                          action:(SEL)action
{
    NSString *value = [self rightValueText];

    // ── 路 1：宿主自带 WCTableViewCellManager（微信系）──
    Class mgr = NSClassFromString(@"WCTableViewCellManager");
    if (mgr &&
        [mgr respondsToSelector:@selector(normalCellForSel:target:title:rightValue:canRightValueCopy:)]) {
        SEL sel = action ?: NSSelectorFromString(item.tapSelectorName);
        typedef id (*HBNormalCellFn)(id, SEL, SEL, id, NSString *, NSString *, BOOL);
        id cell = ((HBNormalCellFn)objc_msgSend)(mgr,
                                                 @selector(normalCellForSel:target:title:rightValue:canRightValueCopy:),
                                                 sel,
                                                 target,
                                                 item.title,
                                                 value,
                                                 NO);
        if ([cell isKindOfClass:[UITableViewCell class]]) {
            return (UITableViewCell *)cell;
        }
    }

    // ── 路 2：普通 UITableViewCell（Value1：左标题 / 右值）──
    static NSString * const kReuse = @"HBSpeedValueCell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:kReuse];
    cell.textLabel.text          = item.title;
    cell.detailTextLabel.text    = value;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.accessoryType           = UITableViewCellAccessoryNone;
    cell.selectionStyle          = UITableViewCellSelectionStyleDefault;
    return cell;
}

+ (NSString *)footerForItem:(HBSpeedMenuItem *)item
{
    return item.footer;
}

@end
