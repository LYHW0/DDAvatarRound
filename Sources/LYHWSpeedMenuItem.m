#import "L63Strings.h"
//
//  LYHWSpeedMenuItem.m
//

#import "LYHWSpeedMenuItem.h"

@implementation LYHWSpeedMenuItem

+ (instancetype)uiSpeedItem
{
    LYHWSpeedMenuItem *it = [LYHWSpeedMenuItem new];

    it.title       = L63Decode(169);
    it.valueFormat = L63Decode(170);
    it.footer      = L63Decode(171);

    it.alertTitle   = L63Decode(172);
    it.alertMessage = L63Decode(173);
    it.confirmButton = L63Decode(174);
    it.cancelButton  = L63Decode(155);
    it.textMaxLength = 256;

    it.restartTitle       = L63Decode(172);
    it.restartMessage     = L63Decode(175);
    it.restartNowButton   = L63Decode(176);
    it.restartLaterButton = L63Decode(177);

    it.tapSelectorName     = L63Decode(178);
    it.confirmSelectorName = L63Decode(179);

    return it;
}

@end
