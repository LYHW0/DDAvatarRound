//
//  LYHWSpeedConfig.m
//

#import "LYHWSpeedConfig.h"

NSString * const LYHWSpeedDefaultsKey  = @"editUiWindowsSpeed";
const float LYHWSpeedDefaultValue      = 1.0f;
const float LYHWSpeedMinValue          = 0.0f;
const float LYHWSpeedMaxValue          = 2.0f;

float LYHWGetUISpeed(void)
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    id v = [ud objectForKey:LYHWSpeedDefaultsKey];
    if (v == nil) {
        // 原插件 LYHWConfigUtil 的 getter 在没有配置时返回 1.0
        return LYHWSpeedDefaultValue;
    }
    float f = [ud floatForKey:LYHWSpeedDefaultsKey];
    if (f <= 0.0f) {
        // 0 / 负数会让 layer.speed = 0 把界面时间冻住，按默认值处理
        return LYHWSpeedDefaultValue;
    }
    return f;
}

void LYHWSetUISpeed(float speed)
{
    [[NSUserDefaults standardUserDefaults] setFloat:speed forKey:LYHWSpeedDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

BOOL LYHWSpeedNeedsApply(void)
{
    // 原实现：fcmp d0, #1.0 / cset ne —— 与 1.0 不等才动 layer.speed
    return (LYHWGetUISpeed() != LYHWSpeedDefaultValue);
}

NSString *LYHWSpeedDisplayText(void)
{
    // 原实现：+[NSString stringWithFormat:@"%.1f", [LYHWConfigUtil editUiWindowsSpeed]]
    return [NSString stringWithFormat:@"%.1f", LYHWGetUISpeed()];
}
