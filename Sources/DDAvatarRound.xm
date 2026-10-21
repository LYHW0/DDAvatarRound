#import "DDAvatarRound.h"

// ========== Hook 实现 ==========
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
            // 计算圆角半径
            CGFloat radius = customCornerRadius >= 0.99f ?
                            MIN(width, height) / 2.0f :
                            MIN(width, height) / 2.0f * customCornerRadius;
            self.layer.cornerRadius = radius;
            self.layer.masksToBounds = YES;
            
            // 同时处理内部 headImageView
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
            // 计算圆角半径
            CGFloat radius = customCornerRadius >= 0.99f ?
                            MIN(width, height) / 2.0f :
                            MIN(width, height) / 2.0f * customCornerRadius;
            self.layer.cornerRadius = radius;
            self.layer.masksToBounds = YES;
            
            // 通过 runtime 查找内部 ImageView 并处理圆角
            unsigned int count = 0;
            Ivar *ivars = class_copyIvarList([self class], &count);
            for (unsigned int i = 0; i < count; i++) {
                Ivar ivar = ivars[i];
                const char *name = ivar_getName(ivar);
                NSString *ivarName = [NSString stringWithUTF8String:name];
                // 匹配 m_ 开头的 ImageView 属性
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

// ========== 列表圆角 Hook ==========
%hook MMTableViewCell

- (void)layoutSubviews {
    %orig;
    if (isListCornerEnabled) {
        CGFloat radius = customListCornerRadius;
        BOOL clipToBounds = (radius > 0);
        
        // 给外层 contentView 设置圆角
        self.layer.cornerRadius = radius;
        self.layer.masksToBounds = clipToBounds;
        
        // 处理内层背景 view（如果有）
        if (self.bgView) {
            self.bgView.cornerRadius = radius;
            self.bgView.masksToBounds = clipToBounds;
        }
        
        // 递归处理子视图
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subview;
                if (imgView.layer.cornerRadius != radius) {
                    imgView.layer.cornerRadius = radius;
                    imgView.layer.masksToBounds = clipToBounds;
                }
            }
        }
    }
}

%end

// ========== 置顶间距 Hook ==========
%hook MMConversationListViewController

- (void)setPinnedSectionHeight:(CGFloat)height {
    // 如果用户设置了自定义高度，使用用户的值
    if (pinnedSectionHeight > 0) {
        %orig(pinnedSectionHeight);
    } else {
        %orig(height);
    }
}

- (void)setBelowPinnedSectionHeight:(CGFloat)height {
    // 如果用户设置了自定义高度，使用用户的值
    if (belowPinnedContentGap > 0) {
        %orig(belowPinnedContentGap);
    } else {
        %orig(height);
    }
}

- (void)setBelowPinnedContentGap:(CGFloat)gap {
    // 如果用户设置了自定义间距，使用用户的值
    if (belowPinnedContentGap > 0) {
        %orig(belowPinnedContentGap);
    } else {
        %orig(gap);
    }
}

%end

// ========== 插件初始化 ==========
%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
        
        // 头像圆角设置
        isRoundAvatarEnabled = [defaults boolForKey:kRoundAvatarKey];
        customCornerRadius = [defaults floatForKey:kAvatarCornerRadiusKey];
        if (customCornerRadius == 0) customCornerRadius = 1.0f;
        
        // 列表圆角设置
        isListCornerEnabled = [defaults boolForKey:kListCornerRadiusKey];
        customListCornerRadius = [defaults floatForKey:kListCornerRadiusKey];
        if (customListCornerRadius == 0) customListCornerRadius = 8.0f;
        
        // 间距设置
        pinnedSectionHeight = [defaults doubleForKey:kPinnedSectionHeightKey];
        belowPinnedContentGap = [defaults doubleForKey:kBelowPinnedGapKey];
        
        // 注册到微信插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD头像圆角" 
                                   version:@"1.0.1" 
                                controller:@"DDAvatarCornerSettingsViewController"];
        }
    }
}
