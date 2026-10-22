//
//  HBSpeedConfig.m
//

#import "HBSpeedConfig.h"

NSString * const HBSpeedDefaultsKey  = @"editUiWindowsSpeed";
const float HBSpeedDefaultValue      = 1.0f;
const float HBSpeedMinValue          = 0.0f;
const float HBSpeedMaxValue          = 2.0f;

float HBGetUISpeed(void)
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    id v = [ud objectForKey:HBSpeedDefaultsKey];
    if (v == nil) {
        // 原插件 HBConfigUtil 的 getter 在没有配置时返回 1.0
        return HBSpeedDefaultValue;
    }
    float f = [ud floatForKey:HBSpeedDefaultsKey];
    if (f <= 0.0f) {
        // 0 / 负数会让 layer.speed = 0 把界面时间冻住，按默认值处理
        return HBSpeedDefaultValue;
    }
    return f;
}

void HBSetUISpeed(float speed)
{
    [[NSUserDefaults standardUserDefaults] setFloat:speed forKey:HBSpeedDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

BOOL HBSpeedNeedsApply(void)
{
    // 原实现：fcmp d0, #1.0 / cset ne —— 与 1.0 不等才动 layer.speed
    return (HBGetUISpeed() != HBSpeedDefaultValue);
}

NSString *HBSpeedDisplayText(void)
{
    // 原实现：+[NSString stringWithFormat:@"%.1f", [HBConfigUtil editUiWindowsSpeed]]
    return [NSString stringWithFormat:@"%.1f", HBGetUISpeed()];
}
