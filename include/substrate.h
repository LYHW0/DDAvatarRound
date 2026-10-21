//
//  substrate.h —— 最小可用声明(编译用)
//  设备上真正的实现由越狱环境的 MobileSubstrate / libhooker 在运行时提供,
//  这里只需要让编译器知道符号签名,链接时用 -undefined dynamic_lookup。
//

#ifndef WCR_MIN_SUBSTRATE_H
#define WCR_MIN_SUBSTRATE_H

#import <objc/runtime.h>
#import <objc/message.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*MSHookFunction_t)(void);

void MSHookFunction(void *symbol, void *replace, void **result);
void MSHookMessageEx(Class _class, SEL message, IMP hook, IMP *old);

#ifdef __cplusplus
}
#endif

#endif
