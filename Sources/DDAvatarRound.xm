#import "DDAvatarRound.h"

// ========== 头像圆角 Hook ==========
%hook MMHeadImageView

- (id)initWithUsrName:(id)arg1 headImgUrl:(id)arg2 bAutoUpdate:(BOOL)arg3 bRoundCorner:(BOOL)arg4 {
    return %orig(arg1, arg2, arg3, isRoundAvatarEnabled || arg4);
}

- (void)layoutSubviews {
    %orig;
    if (isRoundAvatarEnabled) {
        CGFloat width = self.frame.size.width;
        CGFloat height = self.frame.size.height;
        if (width > 0 && height > 0) {
            CGFloat radius = customCornerRadius >= 0.99f ?
                            MIN(width, height) / 2.0f :
                            MIN(width, height) / 2.0f * customCornerRadius;
            self.layer.cornerRadius = radius;
            self.layer.masksToBounds = YES;
            
            if (self.headImageView) {
                CGFloat imageWidth = self.headImageView.frame.size.width;
                CGFloat imageHeight = self.headImageView.frame.size.height;
                if (imageWidth > 0 && imageHeight > 0) {
                    CGFloat imageRadius = customCornerRadius >= 0.99f ?
                                        MIN(imageWidth, imageHeight) / 2.0f :
                                        MIN(imageWidth, imageHeight) / 2.0f * customCornerRadius;
                    self.headImageView.layer.cornerRadius = imageRadius;
                    self.headImageView.layer.masksToBounds = YES;
                }
            }
        }
    }
}

%end

%hook FakeHeadImageView

- (id)initWithRoundCorner:(BOOL)arg1 {
    return %orig(isRoundAvatarEnabled || arg1);
}

- (void)layoutSubviews {
    %orig;
    if (isRoundAvatarEnabled) {
        CGFloat width = self.frame.size.width;
        CGFloat height = self.frame.size.height;
        if (width > 0 && height > 0) {
            CGFloat radius = customCornerRadius >= 0.99f ?
                            MIN(width, height) / 2.0f :
                            MIN(width, height) / 2.0f * customCornerRadius;
            self.layer.cornerRadius = radius;
            self.layer.masksToBounds = YES;
            
            unsigned int count = 0;
            Ivar *ivars = class_copyIvarList([self class], &count);
            for (unsigned int i = 0; i < count; i++) {
                Ivar ivar = ivars[i];
                const char *name = ivar_getName(ivar);
                NSString *ivarName = [NSString stringWithUTF8String:name];
                if ([ivarName hasPrefix:@"m_"] && [ivarName containsString:@"ImageView"]) {
                    id imageView = object_getIvar(self, ivar);
                    if ([imageView isKindOfClass:[UIImageView class]]) {
                        UIImageView *imgView = (UIImageView *)imageView;
                        CGFloat imageWidth = imgView.frame.size.width;
                        CGFloat imageHeight = imgView.frame.size.height;
                        if (imageWidth > 0 && imageHeight > 0) {
                            CGFloat imageRadius = customCornerRadius >= 0.99f ?
                                                MIN(imageWidth, imageHeight) / 2.0f :
                                                MIN(imageWidth, imageHeight) / 2.0f * customCornerRadius;
                            imgView.layer.cornerRadius = imageRadius;
                            imgView.layer.masksToBounds = YES;
                        }
                    }
                }
            }
            free(ivars);
        }
    }
}

%end

// ========== 列表分组圆角 Hook ==========
%hook WCTableViewSectionManager

- (void)addCell:(id)cell {
    %orig;
    if (!isListCornerEnabled || customListCornerRadius <= 0) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([cell respondsToSelector:@selector(superview)]) {
            UIView *cellView = (UIView *)cell;
            UIView *parent = cellView.superview;
            
            while (parent && ![parent isKindOfClass:[UITableViewCell class]]) {
                parent = parent.superview;
            }
            
            if (parent) {
                parent.layer.cornerRadius = customListCornerRadius;
                parent.layer.masksToBounds = YES;
                
                if (globalSectionMargin > 0) {
                    CGRect frame = parent.frame;
                    frame.origin.x = globalSectionMargin;
                    frame.size.width = [UIScreen mainScreen].bounds.size.width - globalSectionMargin * 2;
                    parent.frame = frame;
                }
            }
        }
    });
}

%end

// ========== UITableView 分组样式全局 Hook ==========
%hook UITableView

- (id)initWithFrame:(CGRect)frame style:(NSInteger)style {
    if (isListCornerEnabled && globalSectionMargin > 0 && style == 1) {
        UITableView *tv = %orig(frame, style);
        tv.separatorStyle = UITableViewCellSeparatorStyleNone;
        tv.backgroundColor = [UIColor colorWithRed:0.949 green:0.949 blue:0.949 alpha:1.0];
        if (@available(iOS 15.0, *)) {
            tv.sectionHeaderTopPadding = globalSectionSpacing / 2.0;
        }
        return tv;
    }
    return %orig;
}

%end

// ========== UITableViewCell 统一圆角 Hook ==========
%hook UITableViewCell

- (void)layoutSubviews {
    %orig;
    if (!isListCornerEnabled || customListCornerRadius <= 0) return;
    
    UITableView *tableView = (UITableView *)self.superview;
    while (tableView && ![tableView isKindOfClass:[UITableView class]]) {
        tableView = (UITableView *)tableView.superview;
    }
    
    if (!tableView || tableView.style != UITableViewStyleGrouped) return;
    
    NSIndexPath *indexPath = [tableView indexPathForCell:self];
    if (!indexPath) return;
    
    NSInteger rowCount = [tableView numberOfRowsInSection:indexPath.section];
    if (rowCount <= 0) return;
    
    self.layer.cornerRadius = customListCornerRadius;
    self.layer.masksToBounds = YES;
    
    UIRectCorner corners = 0;
    if (indexPath.row == 0) {
        corners |= UIRectCornerTopLeft | UIRectCornerTopRight;
    }
    if (indexPath.row == rowCount - 1) {
        corners |= UIRectCornerBottomLeft | UIRectCornerBottomRight;
    }
    
    if (corners != 0) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                   byRoundingCorners:corners
                                                         cornerRadii:CGSizeMake(customListCornerRadius, customListCornerRadius)];
        CAShapeLayer *mask = [CAShapeLayer layer];
        mask.path = path.CGPath;
        self.layer.mask = mask;
    } else {
        self.layer.mask = nil;
    }
    
    if (globalSectionMargin > 0) {
        CGRect frame = self.frame;
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        frame.origin.x = globalSectionMargin;
        frame.size.width = screenWidth - globalSectionMargin * 2;
        self.frame = frame;
    }
    
    for (UIView *sub in self.subviews) {
        if ([NSStringFromClass([sub class]) containsString:@"SeparatorView"]) {
            if (indexPath.row == rowCount - 1) {
                sub.hidden = YES;
            }
            if (globalSectionMargin > 0) {
                CGRect sepFrame = sub.frame;
                sepFrame.origin.x = globalSectionMargin;
                sepFrame.size.width -= globalSectionMargin;
                sub.frame = sepFrame;
            }
        }
    }
}

%end

// ========== 插件初始化 ==========
%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
        
        isRoundAvatarEnabled = [defaults boolForKey:kRoundAvatarKey];
        customCornerRadius = [defaults floatForKey:kAvatarCornerRadiusKey];
        if (customCornerRadius == 0) customCornerRadius = 1.0f;
        
        isListCornerEnabled = [defaults boolForKey:kListCornerEnabledKey];
        if (isListCornerEnabled) {
            customListCornerRadius = [defaults floatForKey:kListCornerRadiusKey];
            if (customListCornerRadius == 0) customListCornerRadius = 16.0f;
            
            globalSectionMargin = [defaults floatForKey:kSectionMarginKey];
            if (globalSectionMargin == 0) globalSectionMargin = 15.0f;
            
            globalSectionSpacing = [defaults floatForKey:kSectionSpacingKey];
            if (globalSectionSpacing == 0) globalSectionSpacing = 12.0f;
        } else {
            customListCornerRadius = 0.0f;
            globalSectionMargin = 0.0f;
            globalSectionSpacing = 0.0f;
        }
    }
}
