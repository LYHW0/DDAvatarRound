//
//  WPGroupSessionListController.h
//  内置会话列表（可直接跑，验证分组效果）
//
//  接微信时不必用它 —— 宿主可以把自己的会话列表塞进 pager.contentView。
//  这个类的作用：不依赖任何微信类也能把整套分组功能跑起来，方便自测 / 当参考实现。
//

#import <UIKit/UIKit.h>
#import "WPGroupEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPGroupSessionListController : UIViewController

/// 演示数据（不接微信时用它看效果）
+ (NSArray<WPGroupSession *> *)demoSessions;

- (void)reloadWithSessions:(NSArray<WPGroupSession *> *)sessions;

@end

NS_ASSUME_NONNULL_END
