//
//  ZFXFloatTabGestures.h
//  边缘手势返回主页（与原插件同名的三个类，可直接替换/共存）
//

#import <UIKit/UIKit.h>

/// 右边缘拖拽手势（可注入虚假位移/速度，便于驱动系统返回动画）
@interface WXFloatingTabBarRightEdgePanGesture : UIScreenEdgePanGestureRecognizer
@property (nonatomic, assign) CGPoint zfxFakeTranslation;
@property (nonatomic, assign) CGPoint zfxFakeVelocity;
@end

/// 伪造的返回手势：把状态/位移/速度/坐标全部接管，交给系统返回流程使用
@interface WXFloatingTabBarFakeBackEdgePanGesture : UIPanGestureRecognizer
@property (nonatomic, assign) UIGestureRecognizerState fakeState;
@property (nonatomic, assign) CGPoint fakeTranslation;
@property (nonatomic, assign) CGPoint fakeVelocity;
@property (nonatomic, assign) CGPoint fakeLocation;
@end

/// 同时识别代理：避免和微信自身的滑动手势互相打断
@interface WXFloatingTabBarPopDelegate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UINavigationController *nav;
@end

/// 边缘返回调度：按住左边右滑 / 按住右边左滑 → 返回上一页（回主页）
@interface ZFXEdgeBackController : NSObject

+ (instancetype)shared;

/// 是否启用（跟随悬浮底栏总开关）
- (void)updateEnabledState;

@end
