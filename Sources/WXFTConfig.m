// WXFTConfig.m —— 悬浮底栏配置统一读写 LYHWConfig suite
#include "WXFT.h"
#import "LYHWConfig.h"
#include <string.h>

static id strKey(const char *k){
    return [[NSString alloc] initWithUTF8String:k ?: ""];
}
static LYHWConfig *wxConfig(void){ return [LYHWConfig shared]; }

double WXFTPrefDouble(const char *key, double def){
    id v = [wxConfig() objectForKey:strKey(key) def:nil];
    return v ? [v doubleValue] : def;
}
BOOL WXFTPrefBool(const char *key, BOOL def){
    id v = [wxConfig() objectForKey:strKey(key) def:nil];
    return v ? [v boolValue] : def;
}
void WXFTPrefSetDouble(const char *key, double v){
    [wxConfig() setObject:@(v) forKey:strKey(key)];
}
void WXFTPrefSetBool(const char *key, BOOL v){
    [wxConfig() setObject:@(v) forKey:strKey(key)];
}
BOOL WXFTIsEnabled(void){ return [wxConfig() floatingTabBarEnabled]; }
void WXFTPostSettingsChanged(void){
    [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification object:nil];
}
static double hexByte(const char *s){
    double v = 0; int i;
    for(i=0;i<2 && s[i];i++){
        char c=s[i]; int d;
        if(c>='0'&&c<='9') d=c-'0'; else if(c>='a'&&c<='f') d=c-'a'+10;
        else if(c>='A'&&c<='F') d=c-'A'+10; else d=0;
        v = v*16 + d;
    }
    return v/255.0;
}
id WXFTPrefColor(const char *key, double defWhite, double alpha){
    id value = [wxConfig() objectForKey:strKey(key) def:nil];
    if ([value isKindOfClass:[NSString class]]) {
        const char *c = [(NSString *)value UTF8String];
        if (c && c[0]=='#' && strlen(c)>=7)
            return [UIColor colorWithRed:hexByte(c+1) green:hexByte(c+3) blue:hexByte(c+5) alpha:alpha];
    }
    return [UIColor colorWithWhite:defWhite alpha:alpha];
}
