#import "L62Strings.h"
//
//  LYHWSpeedMenuItem.m
//

#import "LYHWSpeedMenuItem.h"

@implementation LYHWSpeedMenuItem

+ (instancetype)uiSpeedItem
{
    LYHWSpeedMenuItem *it = [LYHWSpeedMenuItem new];

    it.title       = L62Decode(169);
    it.valueFormat = L62Decode(170);
    it.footer      = L62Decode(171);

    it.alertTitle   = L62Decode(172);
    it.alertMessage = L62Decode(173);
    it.confirmButton = L62Decode(174);
    it.cancelButton  = L62Decode(155);
    it.textMaxLength = 256;

    it.restartTitle       = L62Decode(172);
    it.restartMessage     = L62Decode(175);
    it.restartNowButton   = L62Decode(176);
    it.restartLaterButton = L62Decode(177);

    it.tapSelectorName     = L62Decode(178);
    it.confirmSelectorName = L62Decode(179);

    return it;
}

@end
