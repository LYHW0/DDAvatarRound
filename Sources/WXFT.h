// WXFT.h —— WXFloatingTabBar 的 Objective-C/UIKit ABI 声明
#ifndef WXFT_H
#define WXFT_H
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <Foundation/Foundation.h>
#include <stddef.h>

#define WS(s) sel_registerName(s)
#define CLS(n) objc_getClass(n)

#define S0(o,s)            ((id(*)(id,SEL))objc_msgSend)((id)(o),WS(s))
#define S1(o,s,a)          ((id(*)(id,SEL,id))objc_msgSend)((id)(o),WS(s),(id)(a))
#define S2(o,s,a,b)        ((id(*)(id,SEL,id,id))objc_msgSend)((id)(o),WS(s),(id)(a),(id)(b))
#define S3(o,s,a,b,c)      ((id(*)(id,SEL,id,id,id))objc_msgSend)((id)(o),WS(s),(id)(a),(id)(b),(id)(c))
#define V0(o,s)            ((void(*)(id,SEL))objc_msgSend)((id)(o),WS(s))
#define V1(o,s,a)          ((void(*)(id,SEL,id))objc_msgSend)((id)(o),WS(s),(id)(a))
#define V1D(o,s,a)         ((void(*)(id,SEL,double))objc_msgSend)((id)(o),WS(s),(double)(a))
#define V1B(o,s,a)         ((void(*)(id,SEL,BOOL))objc_msgSend)((id)(o),WS(s),(BOOL)(a))
#define V1L(o,s,a)         ((void(*)(id,SEL,long))objc_msgSend)((id)(o),WS(s),(long)(a))
#define V2(o,s,a,b)        ((void(*)(id,SEL,id,id))objc_msgSend)((id)(o),WS(s),(id)(a),(id)(b))
#define RECT0(o,s)         ((CGRect(*)(id,SEL))objc_msgSend)((id)(o),WS(s))
#define RECTV(o,s,a)       ((CGRect(*)(id,SEL,id))objc_msgSend)((id)(o),WS(s),(id)(a))
#define V1R(o,s,r)         ((void(*)(id,SEL,CGRect))objc_msgSend)((id)(o),WS(s),(r))
#define P0(o,s)            ((CGPoint(*)(id,SEL))objc_msgSend)((id)(o),WS(s))
#define V1P(o,s,p)         ((void(*)(id,SEL,CGPoint))objc_msgSend)((id)(o),WS(s),(p))
#define D0(o,s)            ((double(*)(id,SEL))objc_msgSend)((id)(o),WS(s))
#define V1F(o,s,f)         ((void(*)(id,SEL,float))objc_msgSend)((id)(o),WS(s),(float)(f))
#define F0(o,s)            ((float(*)(id,SEL))objc_msgSend)((id)(o),WS(s))
#define L0(o,s)            ((long(*)(id,SEL))objc_msgSend)((id)(o),WS(s))
#define B0(o,s)            ((BOOL(*)(id,SEL))objc_msgSend)((id)(o),WS(s))
#define B1(o,s,a)          ((BOOL(*)(id,SEL,id))objc_msgSend)((id)(o),WS(s),(id)(a))
#define U0(o,s)            ((unsigned long(*)(id,SEL))objc_msgSend)((id)(o),WS(s))
#define OBJ(o,s)           ((id(*)(id,SEL))objc_msgSend)((id)(o),WS(s))

static inline CGFloat WXFTMax(CGFloat a, CGFloat b) { return a > b ? a : b; }
static inline CGFloat WXFTMin(CGFloat a, CGFloat b) { return a < b ? a : b; }

BOOL WXFTPrefBool(const char *key, BOOL def);
double WXFTPrefDouble(const char *key, double def);
void WXFTPrefSetBool(const char *key, BOOL value);
void WXFTPrefSetDouble(const char *key, double value);
id WXFTPrefColor(const char *key, double defWhite, double alpha);
BOOL WXFTIsEnabled(void);
void WXFTPostSettingsChanged(void);
void WXFTInstall(void);
void WXFTApplyFloatingLayout(id bar);
id WXFTQuickSettingsPanel(void);

#endif
