// WeChat 8.0.80 also ships WCTabBarView : UIView. It cannot acquire
// native liquid glass by changing its appearance; embed a REAL UITabBar.
static BOOL LQActualInstance(id object, Class target) {
    for (Class c=object_getClass(object); c; c=class_getSuperclass(c)) if(c==target) return YES;
    return NO;
}
static id LQGet(id object, NSString *name) {
    SEL sel=NSSelectorFromString(name);
    Method m=class_getInstanceMethod(object_getClass(object),sel);
    if(!m || method_getNumberOfArguments(m)!=2) return nil;
    char *r=method_copyReturnType(m); BOOL ok=r && r[0]=='@'; free(r);
    return ok ? ((id(*)(id,SEL))objc_msgSend)(object,sel) : nil;
}
static char kLQBridge;
static NSHashTable *sLQWCHosts;
@interface LQWCBridge : NSObject <UITabBarDelegate>
@property(nonatomic,weak) UIView *host;
@property(nonatomic,strong) UITabBar *nativeBar;
@property(nonatomic,strong) NSMapTable<UIView *,NSNumber *> *savedAlpha;
@property(nonatomic,strong) NSArray *models;
@property(nonatomic) BOOL queued;
@property(nonatomic) BOOL inPass;
@property(nonatomic) CFTimeInterval lastPass;
- (void)update;
@end
@implementation LQWCBridge
- (id)owner {
    Class target=NSClassFromString(@"WCTabBarController");
    for(UIResponder *r=self.host.nextResponder;r;r=r.nextResponder)
        if(LQActualInstance(r,target)) return r;
    return nil;
}
- (void)restore {
    for(UIView *v in self.savedAlpha.keyEnumerator.allObjects) {
        NSNumber *a=[self.savedAlpha objectForKey:v];
        if(v.alpha==0) v.alpha=a.doubleValue;
    }
    [self.savedAlpha removeAllObjects];
}
- (void)update {
    UIView *host=self.host;
    if(!host.window || host.hidden || !LQLGEnabled()) { self.nativeBar.hidden=YES; [self restore]; return; }
    id owner=[self owner];
    NSArray *views=LQGet(host,@"itemViews"), *models=LQGet(host,@"tabItems");
    if(![views isKindOfClass:NSArray.class] || views.count!=4 ||
       ![models isKindOfClass:NSArray.class] || models.count!=4 || !owner) {
        self.nativeBar.hidden=YES; [self restore]; return;
    }
    if(!self.nativeBar) {
        self.nativeBar=[[UITabBar alloc] initWithFrame:host.bounds];
        self.nativeBar.delegate=self;
        self.nativeBar.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.savedAlpha=[NSMapTable weakToStrongObjectsMapTable];
        [host addSubview:self.nativeBar];
    }
    self.nativeBar.hidden=NO;
    if(!CGRectEqualToRect(self.nativeBar.frame,host.bounds)) self.nativeBar.frame=host.bounds;
    NSMutableArray *items=[NSMutableArray array];
    for(NSUInteger i=0;i<4;i++) {
        id model=models[i];
        NSString *title=LQGet(model,@"title");
        UIImage *image=LQGet(model,@"image"), *selected=LQGet(model,@"selectedImage");
        if(![title isKindOfClass:NSString.class] || ![image isKindOfClass:UIImage.class]) {
            self.nativeBar.hidden=YES; [self restore]; return;
        }
        UITabBarItem *item=[[UITabBarItem alloc] initWithTitle:title image:image selectedImage:[selected isKindOfClass:UIImage.class]?selected:nil];
        item.tag=i;
        id badge=LQGet(model,@"badgeValue");
        if([badge isKindOfClass:NSString.class]) item.badgeValue=badge;
        SEL dot=NSSelectorFromString(@"showsRedDot"), enabled=NSSelectorFromString(@"isEnabled");
        Method dm=class_getInstanceMethod(object_getClass(model),dot);
        if(!item.badgeValue.length && dm) {
            char *r=method_copyReturnType(dm); BOOL ok=r && (r[0]=='B'||r[0]=='c'); free(r);
            if(ok && ((BOOL(*)(id,SEL))objc_msgSend)(model,dot)) item.badgeValue=@" ";
        }
        Method em=class_getInstanceMethod(object_getClass(model),enabled);
        if(em) {
            char *r=method_copyReturnType(em); BOOL ok=r && (r[0]=='B'||r[0]=='c'); free(r);
            if(ok) item.enabled=((BOOL(*)(id,SEL))objc_msgSend)(model,enabled);
        }
        // Preserve supplied accessibility metadata, never guess ivars.
        id label=LQGet(model,@"accessibilityLabel");
        if([label isKindOfClass:NSString.class]) item.accessibilityLabel=label;
        BOOL dotBadge=[item.badgeValue isEqualToString:@" "];
        if((dotBadge && sHideRedDot) || (!dotBadge && sHideBadge)) item.badgeValue=nil;
        [items addObject:item];
    }
    // Stable identities: setItems resets UIKit's liquid selection provider.
    // Only install once; badge/image refreshes mutate existing items in place.
    BOOL initial=self.nativeBar.items.count!=4;
    if(initial) [self.nativeBar setItems:items animated:NO];
    else for(NSUInteger i=0;i<4;i++) {
        UITabBarItem *a=self.nativeBar.items[i], *b=items[i];
        if(![a.title isEqual:b.title]) a.title=b.title;
        if(a.enabled!=b.enabled) a.enabled=b.enabled;
        if(a.image!=b.image && ![a.image isEqual:b.image]) a.image=b.image;
        if(a.selectedImage!=b.selectedImage && ![a.selectedImage isEqual:b.selectedImage]) a.selectedImage=b.selectedImage;
        if(a.badgeValue!=b.badgeValue && ![a.badgeValue isEqual:b.badgeValue]) a.badgeValue=b.badgeValue;
        if(a.accessibilityLabel!=b.accessibilityLabel && ![a.accessibilityLabel isEqual:b.accessibilityLabel]) a.accessibilityLabel=b.accessibilityLabel;
    }
    self.models=models;
    SEL selected=NSSelectorFromString(@"selectedIndex");
    // Controller is authoritative; host.selectedIndex can lag during rapid taps.
    Method sm=class_getInstanceMethod(object_getClass(owner),selected);
    NSUInteger index=NSNotFound;
    if(sm) {
        char *r=method_copyReturnType(sm); BOOL valid=r && (r[0]=='Q'||r[0]=='q'); free(r);
        if(valid) index=((NSUInteger(*)(id,SEL))objc_msgSend)(owner,selected);
    }
    if(index<4 && self.nativeBar.selectedItem!=self.nativeBar.items[index])
        self.nativeBar.selectedItem=self.nativeBar.items[index];
    // Let UIKit own selection animations; never force synchronous layout on a tap.
    if(initial) [self.nativeBar layoutIfNeeded];
    // Only remove the legacy visuals AFTER UIKit has actually produced glass.
    BOOL native=NO;
    for(UIView *v in self.nativeBar.subviews)
        if([NSStringFromClass(object_getClass(v)) containsString:@"UITabBarPlatterView"] && !CGRectIsEmpty(v.bounds)) native=YES;
    if(!native) { self.nativeBar.hidden=YES; [self restore]; return; }
    NSMutableArray *hide=[views mutableCopy];
    id bg=LQGet(host,@"backgroundContentView"), sep=LQGet(host,@"separatorView");
    if(LQActualInstance(bg,UIView.class)) [hide addObject:bg];
    if(LQActualInstance(sep,UIView.class)) [hide addObject:sep];
    for(UIView *v in hide) {
        if(!LQActualInstance(v,UIView.class) || v.superview!=host || v==self.nativeBar) continue;
        if(![self.savedAlpha objectForKey:v]) [self.savedAlpha setObject:@(v.alpha) forKey:v];
        v.alpha=0;
    }
    [host bringSubviewToFront:self.nativeBar];
}
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    id owner=[self owner]; SEL select=NSSelectorFromString(@"handleUserSelectionAtIndex:");
    Method m=class_getInstanceMethod(object_getClass(owner),select);
    if(!m || method_getNumberOfArguments(m)!=3) return;
    char *arg=method_copyArgumentType(m,2), *ret=method_copyReturnType(m);
    BOOL valid=arg && (arg[0]=='q'||arg[0]=='Q') && ret && ret[0]=='v'; free(arg); free(ret);
    if(valid && item.tag>=0 && item.tag<4) ((void(*)(id,SEL,NSUInteger))objc_msgSend)(owner,select,(NSUInteger)item.tag);
    // Re-sync even if WeChat rejects a selection.
    dispatch_async(dispatch_get_main_queue(),^{[self update];});
}
@end
static void (*sLQWCLayout)(id,SEL);
static void (*sLQWCMove)(id,SEL);
static void LQWCQueue(UIView *host) {
    LQWCBridge *bridge=objc_getAssociatedObject(host,&kLQBridge);
    if(!bridge) { bridge=[LQWCBridge new]; bridge.host=host; objc_setAssociatedObject(host,&kLQBridge,bridge,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    if(!sLQWCHosts) sLQWCHosts=[NSHashTable weakObjectsHashTable];
    [sLQWCHosts addObject:host];
    if(bridge.queued || bridge.inPass) return;
    bridge.queued=YES;
    CFTimeInterval wait=MAX(0,0.05-(CACurrentMediaTime()-bridge.lastPass));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        bridge.queued=NO; bridge.inPass=YES; bridge.lastPass=CACurrentMediaTime();
        @try { [bridge update]; } @catch(NSException *e) { [bridge restore]; bridge.nativeBar.hidden=YES; }
        @finally { bridge.inPass=NO; }
    });
}
static void LQWCLayout(id self,SEL cmd) { if(sLQWCLayout) sLQWCLayout(self,cmd); LQWCQueue(self); }
static void LQWCMove(id self,SEL cmd) { if(sLQWCMove) sLQWCMove(self,cmd); LQWCQueue(self); }
static void LQInstallWCBridge(void) {
    Class cls=NSClassFromString(@"WCTabBarView");
    if(!cls) return;
    LQLGHookInstanceMethod(cls,@selector(layoutSubviews),(IMP)LQWCLayout,(IMP *)&sLQWCLayout);
    LQLGHookInstanceMethod(cls,@selector(didMoveToWindow),(IMP)LQWCMove,(IMP *)&sLQWCMove);
}

static void LQRefreshWC(void) { for(UIView *host in sLQWCHosts) LQWCQueue(host); }
