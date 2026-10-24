//
//  LYHWPortRules.x —— 把 LYHWRules 规则表挂到 layoutSubviews 上
//
//  原插件在 UIView / UIImageView / YYAsyncImageView 以及十几个具体类上各挂一个
//  layoutSubviews。这里同样 hook 这三个基类，但先做一次“类名预筛”，
//  不在规则表宿主/父视图名单里的视图直接跳过，避免每个 UIView 都全表扫描。
//
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "LYHWRules.h"
#import "LYHWConfig.h"

// 预筛：宿主类名 ∪ 父视图类名 的集合（懒构建）
static NSSet<NSString *> *LYHWRuleNames(void) {
    static NSSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSUInteger n = 0;
        const LYHWRule *t = LYHWRulesTable(&n);
        NSMutableSet *s = [NSMutableSet set];
        for (NSUInteger i = 0; i < n; i++) {
            if (t[i].host)   [s addObject:@(t[i].host)];
            if (t[i].parent) [s addObject:@(t[i].parent)];
            if (t[i].grand)  [s addObject:@(t[i].grand)];
        }
        set = s;
    });
    return set;
}

/// 视图是否“可能命中规则”：自身类名 / 父 / 祖父 类名在名单里
static BOOL LYHWMayMatch(UIView *v) {
    NSSet *names = LYHWRuleNames();
    if ([names containsObject:NSStringFromClass([v class])]) return YES;
    UIView *p = v.superview;
    if (p && [names containsObject:NSStringFromClass([p class])]) return YES;
    UIView *g = p.superview;
    if (g && [names containsObject:NSStringFromClass([g class])]) return YES;
    return NO;
}

static void LYHWRun(UIView *v) {
    if (!v.window && !v.superview) return;          // 还没挂到视图树，等下一次
    if (!LYHWMayMatch(v)) return;
    LYHWApplyRulesForView(v);
}

%hook UIView
- (void)layoutSubviews {
    %orig;
    LYHWRun(self);
}
%end

// UIImageView / YYAsyncImageView 自己重写了 layoutSubviews 的情况
%hook UIImageView
- (void)layoutSubviews {
    %orig;
    LYHWRun(self);
}
%end

%hook YYAsyncImageView
- (void)layoutSubviews {
    %orig;
    LYHWRun(self);
}
%end

// 表情 cell 用的是 layoutContentView，而不是 layoutSubviews
%hook EmoticonMessageCellView
- (void)layoutContentView {
    %orig;
    LYHWApplyRulesForView((UIView *)self);
}
%end

%hook AppEmoticonMessageCellView
- (void)layoutContentView {
    %orig;
    LYHWApplyRulesForView((UIView *)self);
}
%end

// 表情管理 / 收藏等“初始化时设置”的类
%hook EmoticonBoardButton
- (void)initView {
    %orig;
    LYHWApplyRulesForView((UIView *)self);
}
%end
