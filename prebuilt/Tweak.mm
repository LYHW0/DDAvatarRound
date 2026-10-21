#line 1 "src/Tweak.xm"









#import <UIKit/UIKit.h>
#import "WCRCorner.h"
#include <substrate.h>


@interface NewSettingViewController : UIViewController
@end

#pragma mark - 设置页兜底入口


#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

__asm__(".linker_option \"-framework\", \"CydiaSubstrate\"");

@class NewSettingViewController; 
static void (*_logos_orig$_ungrouped$NewSettingViewController$viewDidLoad)(_LOGOS_SELF_TYPE_NORMAL NewSettingViewController* _LOGOS_SELF_CONST, SEL); static void _logos_method$_ungrouped$NewSettingViewController$viewDidLoad(_LOGOS_SELF_TYPE_NORMAL NewSettingViewController* _LOGOS_SELF_CONST, SEL); static void _logos_method$_ungrouped$NewSettingViewController$wcr_openCornerPanel(_LOGOS_SELF_TYPE_NORMAL NewSettingViewController* _LOGOS_SELF_CONST, SEL); 

#line 20 "src/Tweak.xm"


static void _logos_method$_ungrouped$NewSettingViewController$viewDidLoad(_LOGOS_SELF_TYPE_NORMAL NewSettingViewController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    _logos_orig$_ungrouped$NewSettingViewController$viewDidLoad(self, _cmd);
    if (![WCRPluginRegistrar needsFallbackEntry]) return;
    UIBarButtonItem *item =
        [[UIBarButtonItem alloc] initWithTitle:WCRPluginEntryTitle
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(wcr_openCornerPanel)];
    item.accessibilityIdentifier = @"wcr_corner_entry";
    self.navigationItem.rightBarButtonItem = item;
}


static void _logos_method$_ungrouped$NewSettingViewController$wcr_openCornerPanel(_LOGOS_SELF_TYPE_NORMAL NewSettingViewController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    UIViewController *vc = [WCRPluginRegistrar makeEntryViewController];
    [self.navigationController pushViewController:vc animated:YES];
}



#pragma mark - 启动

static __attribute__((constructor)) void _logosLocalCtor_36835025(int __unused argc, char __unused **argv, char __unused **envp) {
    @autoreleasepool {
        
        [WCRCornerConfig shared];
        
        [WCRPluginRegistrar registerAll];
        
        [WCRCornerHookCenter install];
    }
}
static __attribute__((constructor)) void _logosLocalInit() {
{Class _logos_class$_ungrouped$NewSettingViewController = objc_getClass("NewSettingViewController"); { MSHookMessageEx(_logos_class$_ungrouped$NewSettingViewController, @selector(viewDidLoad), (IMP)&_logos_method$_ungrouped$NewSettingViewController$viewDidLoad, (IMP*)&_logos_orig$_ungrouped$NewSettingViewController$viewDidLoad);}{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$_ungrouped$NewSettingViewController, @selector(wcr_openCornerPanel), (IMP)&_logos_method$_ungrouped$NewSettingViewController$wcr_openCornerPanel, _typeEncoding); }} }
#line 54 "src/Tweak.xm"
