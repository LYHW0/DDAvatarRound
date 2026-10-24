// WXFTConfig.m —— 配置读写（键名与原版一致，直接复用原版偏好）
#include "WXFT.h"
#include <string.h>

static id gDefaults = nil;

static id defaults(void){
    if(!gDefaults) gDefaults = S0((id)CLS("NSUserDefaults"), "standardUserDefaults");
    return gDefaults;
}

static id strKey(const char *k){
    return ((id(*)(id,SEL,const char *))objc_msgSend)((id)CLS("NSString"), WS("stringWithUTF8String:"), k);
}

double WXFTPrefDouble(const char *key, double def){
    id d = defaults(); if(!d) return def;
    id n = S1(d, "objectForKey:", strKey(key));
    if(!n) return def;
    return D0(n, "doubleValue");
}

BOOL WXFTPrefBool(const char *key, BOOL def){
    id d = defaults(); if(!d) return def;
    id n = S1(d, "objectForKey:", strKey(key));
    if(!n) return def;
    return B0(n, "boolValue");
}

void WXFTPrefSetDouble(const char *key, double v){
    id d = defaults(); if(!d) return;
    id num = ((id(*)(id,SEL,double))objc_msgSend)((id)CLS("NSNumber"), WS("numberWithDouble:"), v);
    V2(d, "setObject:forKey:", num, strKey(key));
    V0(d, "synchronize");
}

void WXFTPrefSetBool(const char *key, BOOL v){
    id d = defaults(); if(!d) return;
    id num = ((id(*)(id,SEL,BOOL))objc_msgSend)((id)CLS("NSNumber"), WS("numberWithBool:"), v);
    V2(d, "setObject:forKey:", num, strKey(key));
    V0(d, "synchronize");
}

BOOL WXFTIsEnabled(void){
    return WXFTPrefBool("wkkFloatTab", NO);
}

void WXFTPostSettingsChanged(void){
    id nc = S0((id)CLS("NSNotificationCenter"), "defaultCenter");
    if(nc) V2(nc, "postNotificationName:object:",
             strKey("CSFloatingTabBarSettingsChanged"), nil);
}

static double hexByte(const char *s){
    double v = 0; int i;
    for(i=0;i<2 && s[i];i++){
        char c=s[i]; int d;
        if(c>='0'&&c<='9') d=c-'0';
        else if(c>='a'&&c<='f') d=c-'a'+10;
        else if(c>='A'&&c<='F') d=c-'A'+10;
        else d=0;
        v = v*16 + d;
    }
    return v/255.0;
}

// 读颜色：#RRGGBB 字符串优先，否则用 defWhite 灰度
id WXFTPrefColor(const char *key, double defWhite, double alpha){
    id d = defaults();
    if(d){
        id s = S1(d, "objectForKey:", strKey(key));
        if(s && B1(s, "isKindOfClass:", (id)CLS("NSString"))){
            const char *c = ((const char*(*)(id,SEL))objc_msgSend)(s, WS("UTF8String"));
            if(c && c[0]=='#' && strlen(c)>=7){
                return ((id(*)(id,SEL,double,double,double,double))objc_msgSend)(
                    (id)CLS("UIColor"), WS("colorWithRed:green:blue:alpha:"),
                    hexByte(c+1), hexByte(c+3), hexByte(c+5), alpha);
            }
        }
    }
    return ((id(*)(id,SEL,double,double))objc_msgSend)((id)CLS("UIColor"),
             WS("colorWithWhite:alpha:"), defWhite, alpha);
}
