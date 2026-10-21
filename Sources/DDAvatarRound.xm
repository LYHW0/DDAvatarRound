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

// ========== 列表圆角 Hook ==========
%hook MMTableViewCell

- (void)layoutSubviews {
    %orig;
    if (isListCornerEnabled && customListCornerRadius > 0) {
        self.layer.cornerRadius = customListCornerRadius;
        self.layer.masksToBounds = YES;
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subview;
                imgView.layer.cornerRadius = customListCornerRadius;
                imgView.layer.masksToBounds = YES;
            }
        }
    }
}

%end

// ========== 置顶间距 Hook ==========
%hook MMConversationListViewController

- (void)setPinnedSectionHeight:(CGFloat)height {
    if (pinnedSectionHeight > 0) {
        %orig(pinnedSectionHeight);
    } else {
        %orig(height);
    }
}

- (void)setBelowPinnedSectionHeight:(CGFloat)height {
    if (belowPinnedContentGap > 0) {
        %orig(belowPinnedContentGap);
    } else {
        %orig(height);
    }
}

- (void)setBelowPinnedContentGap:(CGFloat)gap {
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
        
        isRoundAvatarEnabled = [defaults boolForKey:kRoundAvatarKey];
        customCornerRadius = [defaults floatForKey:kAvatarCornerRadiusKey];
        if (customCornerRadius == 0) customCornerRadius = 1.0f;
        
        isListCornerEnabled = [defaults boolForKey:kListCornerEnabledKey];
        if (isListCornerEnabled) {
            customListCornerRadius = [defaults floatForKey:kListCornerRadiusKey];
            if (customListCornerRadius == 0) customListCornerRadius = 8.0f;
        } else {
            customListCornerRadius = 0.0f;
        }
        
        pinnedSectionHeight = [defaults doubleForKey:kPinnedSectionHeightKey];
        belowPinnedContentGap = [defaults doubleForKey:kBelowPinnedGapKey];
        
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD头像圆角" 
                                   version:@"1.0.4" 
                                controller:@"DDAvatarCornerSettingsViewController"];
        }
    }
}
