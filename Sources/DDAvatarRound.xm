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

// ========== 插件初始化 ==========
%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kUserDefaultsSuiteName];
        isRoundAvatarEnabled = [defaults boolForKey:kRoundAvatarKey];
        customCornerRadius = [defaults floatForKey:kAvatarCornerRadiusKey];
        if (customCornerRadius == 0) customCornerRadius = 1.0f;
        
        // 注册到微信插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD头像圆角" 
                                   version:@"1.0.0" 
                                controller:@"DDAvatarCornerSettingsViewController"];
        }
    }
}
