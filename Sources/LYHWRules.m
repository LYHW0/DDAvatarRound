//
//  LYHWRules.m —— 「全局圆角」命中规则表 + 分发引擎
//
//  规则全部来自原插件 hooks.csv + decompiled/*.m 的逐 hook 还原。
//  每一行 = 原插件里一个 `[父视图类名 isEqualToString:@"XXX"]` 之类的判定。
//
#import "LYHWRules.h"
#import "LYHWConfig.h"
#import "LYHWCommon.h"
#import "LYHWRadius.h"
#import <objc/runtime.h>
#import <objc/message.h>

#define SELF   LYHWRuleTargetSelf
#define PARENT LYHWRuleTargetParent
#define IVAR   LYHWRuleTargetIvar
#define SUBS   LYHWRuleTargetSubs

// {key, host, parent, grand, target, arg}
static const LYHWRule kRules[] = {
    // ───────── 聊天：图片 / 视频 / 表情 ─────────
    { "chatImageCorner",     "ImageMessageCellView",   NULL, NULL, IVAR,   "m_imageView"      },
    { "chatImageCorner",     "VideoMessageCellView",   NULL, NULL, IVAR,   "m_imageView"      },
    { "chatImageCorner",     "ImageScrollView",        NULL, NULL, SUBS,   "WCTiledImageView,UIImageView" },
    { "chatImageCorner",     "UIImageView",   "SharePreConfirmHeadView", NULL, SELF, NULL     },
    { "chatImageCorner",     "UIImageView",   "WCFinderShareFeedCellView", NULL, SELF, NULL   },
    { "chatImageCorner",     "UIView",        "WCFinderShareFeedCellView", NULL, SELF, NULL   },
    { "chatImageCorner",     "UIView",        "AppUrlMessageCellView",     NULL, SELF, NULL   },
    { "emojiCorner",         "EmoticonMessageCellView",    NULL, NULL, IVAR, "m_emoticonView" },
    { "emojiCorner",         "AppEmoticonMessageCellView", NULL, NULL, IVAR, "m_emoticonView" },
    // ───────── 聊天：时间条 ─────────
    { "chatTimeRoundCorner", "ChatTimeCellView",       NULL, NULL, SUBS,   "MMUILabel,UIImageView" },
    // ───────── 聊天：各类卡片 ─────────
    { "chatLocationCorner",  "UIView",        "LocationMessageCellView",   NULL, SELF, NULL   },
    { "chatLocationCorner",  "YYAsyncImageView", "LocationMessageCellView", NULL, SELF, NULL  },
    { "chatFileCorner",      "UIView",        "AppFileMessageCellView",    NULL, SELF, NULL   },
    { "chatMusicCorner",     "UIView",        "AppTingMessageCellView",    NULL, SELF, NULL   },
    { "chatCardCorner",      "UIView",        "ShareCardMessageCellView",  NULL, SELF, NULL   },
    { "chatCardCorner",      "YYAsyncImageView", "ShareCardMessageCellView", NULL, SELF, NULL },
    { "chatRedPacketCorner", "UIView",        "WCPayC2CMessageCellView",   NULL, SELF, NULL   },
    { "chatRedPacketCorner", "UIView",        "WCPayTransferMessageCellView", NULL, SELF, NULL },
    { "chatRedPacketCorner", "YYAsyncImageView", "WCPayTransferMessageCellView", NULL, SELF, NULL },
    { "chatFavoriteCorner",  "UIView",        "AppNoteMessageCellView",    NULL, SELF, NULL   },
    { "chatArticleCorner",   "BizAppReaderMessageCellView", NULL, NULL, SUBS, "MMHeadImageView,MMUILongPressImageView,MMCPLabel,UILabel" },
    { "chatHistoryCorner",   "AppRecordMessageCellView",    NULL, NULL, SUBS, "MMHeadImageView,MMUILongPressImageView,MMCPLabel,UILabel" },
    { "chatMiniProgramCorner","WAAppPageCellView",          NULL, NULL, SUBS, "MMHeadImageView,MMUILongPressImageView,MMCPLabel,UILabel" },
    { "chatPinTipsCorner",   "UIView",        "MMMsgCommonTipsView",       NULL, SELF, NULL   },
    // ───────── 聊天：引用 ─────────
    { "msgReferCorner",      "UIView",        "MMInputMsgReferView",       NULL, SELF, NULL   },
    { "msgReferCorner",      "UIImageView",   "MMInputMsgReferView",       NULL, SELF, NULL   },
    { "msgReferCorner",      "UIView",        "SystemMessageCellView",     NULL, SELF, NULL   },
    // ───────── 朋友圈 ─────────
    { "momentCorner",        "WCImageView",                  NULL, NULL, IVAR, "_imageView"      },
    { "momentCorner",        "WCContentItemFinderView",      NULL, NULL, IVAR, "_contentImageView" },
    { "momentCorner",        "WCSNSNodeVideoView",           NULL, NULL, IVAR, "_thumbImageView" },
    { "momentCorner",        "WCSNSNodeVideoView",           NULL, NULL, IVAR, "_playerView"     },
    { "momentCorner",        "WCPuzzleImageView",            NULL, NULL, SELF, NULL },
    { "momentCorner",        "WCListFeedVideoThumbView",     NULL, NULL, SELF, NULL },
    { "momentCorner",        "WCStoryAlbumCollectionViewCell", NULL, NULL, SELF, NULL },
    { "momentCorner",        "SightFileMaskView",            NULL, NULL, SUBS, "MMWebImageView" },
    { "momentCorner",        "WCFinderShareLiveView",        NULL, NULL, SUBS, "MMWebImageView" },
    // ───────── 视频号 ─────────
    { "finderCorner",        "WCFinderFeedStaticCoverView",  NULL, NULL, SUBS, "WCFinderFeedImageCDNView" },
    { "finderCorner",        "WCFinderWXContactEntranceView",NULL, NULL, SUBS, "WCFinderAuthInfoIconView" },
    { "finderCorner",        "WCFinderFeedImageCDNView", "WCFinderLiveHomePageNormalCell", NULL, SELF, NULL },
    // ───────── 收藏 / 表情管理 / 相册 ─────────
    { "favoriteCorner",      "UIView",        "MMFavCellComponent",        NULL, SELF, NULL },
    { "favoriteCorner",      "UIView",        "MMFavImageComponent",       NULL, SELF, NULL },
    { "favoriteCorner",      "MsgImageSquareThumbView", "MMGridImageView", NULL, SELF, NULL },
    { "favoriteCorner",      "EmoticonViewWithPreview",      NULL, NULL, IVAR, "m_emoticonView" },
    { "favoriteCorner",      "EmoticonBoardButton",          NULL, NULL, IVAR, "m_effectView" },
    { "favoriteCorner",      "UIImageView",   "EmoticonCustomManageView",  NULL, SELF, NULL },
    { "photoAlbumCorner",    "MMAssetView",                  NULL, NULL, IVAR, "_m_assetImageView" },
    { "photoAlbumCorner",    "MMAssetView",                  NULL, NULL, IVAR, "_mediaTypeIconView" },
    { "chatSearchThumbCorner","WCC2CMsgImageSquareThumbView",NULL, NULL, SELF, NULL },
    { "fileBrowseCorner",    "MsgFileBrowseItemView",        NULL, NULL, SUBS, "MMUIView" },
    // ───────── 服务页 / 钱包 ─────────
    { "serviceCorner",       "WCPayWalletDecorationView", "UICollectionView", NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "WCPayWalletEntryHeaderView",NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "WCPayWalletBusinessSectionHeader", NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "StorageUsageDetailView",    NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "WCPayRecepictReaderMessageCellView", NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "MultiColumnReaderMessageCellView",   NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "MultiReaderMessageCellView",         NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "MultiImageReaderMessageCellView",    NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "AttributedReaderMessageCellView",    NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "NotifyLiveImageMessageCellView",     NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "ImageReaderMessageCellView",         NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "ReaderMessageCellView",              NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "TextReaderMessageCellView",          NULL, SELF, NULL },
    { "serviceCorner",       "UIView",        "UICollectionView",                   NULL, SELF, NULL },
    { "serviceCorner",       "BrandProfileMsgHeaderCell",   NULL, NULL, SUBS, "MMWebImageView" },
    { "serviceCorner",       "BrandProfileItemReaderCell",  NULL, NULL, SUBS, "MMWebImageView" },
    { "serviceCorner",       "BrandProfileItemVideoCell",   NULL, NULL, SUBS, "MMWebImageView" },
    { "serviceCorner",       "BrandProfileItemImageCell",   NULL, NULL, SUBS, "MMWebImageView" },
    { "serviceCorner",       "BrandProfileItemMultiImageCell", NULL, NULL, SUBS, "MMWebImageView" },
};

const LYHWRule *LYHWRulesTable(NSUInteger *outCount) {
    if (outCount) *outCount = sizeof(kRules) / sizeof(kRules[0]);
    return kRules;
}

// ─────────────────────────────────────────────────────────────
#pragma mark - 引擎

static NSString *LYHWStr(const char *s) { return s ? [NSString stringWithUTF8String:s] : nil; }

/// 类名 → Class，带缓存；不存在返回 Nil（缓存为 NSNull）
static Class LYHWClassNamed(NSString *name) {
    if (!name.length) return Nil;
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });
    @synchronized (cache) {
        id v = cache[name];
        if (v) return [v isKindOfClass:[NSNull class]] ? Nil : (Class)v;
        Class c = NSClassFromString(name);
        cache[name] = c ?: (id)[NSNull null];
        return c;
    }
}

static BOOL LYHWMatchClass(id obj, const char *name) {
    if (!name) return YES;
    Class c = LYHWClassNamed(LYHWStr(name));
    if (!c || !obj) return NO;
    return [obj isKindOfClass:c];
}

/// 读规则的“开关/半径/边框”
typedef struct { BOOL on; double radius; double bw; UIColor *bc; } LYHWStyle;

static LYHWStyle LYHWStyleFor(const char *key) {
    LYHWStyle s = { NO, 0, 0, nil };
    NSString *k = LYHWStr(key);
    LYHWConfig *c = [LYHWConfig shared];
    id on = [c objectForKey:[k stringByAppendingString:@"Enabled"] def:nil];
    if (!on || ![on boolValue]) return s;
    id r = [c objectForKey:[k stringByAppendingString:@"Radius"] def:nil];
    s.on = YES;
    s.radius = r ? [r doubleValue] : 10.0;
    id bw = [c objectForKey:[k stringByAppendingString:@"BorderSize"] def:nil];
    s.bw = bw ? [bw doubleValue] : 0.0;
    if (s.bw > 0) {
        NSString *lt = [c objectForKey:[k stringByAppendingString:@"BorderColorLight"] def:@"#E5E5EA"];
        NSString *dk = [c objectForKey:[k stringByAppendingString:@"BorderColorDark"]  def:@"#3A3A3C"];
        s.bc = LYHWColorForAppearance(lt, dk);
    }
    return s;
}

static void LYHWApplyTo(UIView *v, LYHWStyle s) {
    if (![v isKindOfClass:[UIView class]]) return;
    LYHWApplyRadiusAndBorder(v, (CGFloat)s.radius, (CGFloat)s.bw, s.bc);
}

static UIView *LYHWIvarView(id host, const char *ivarName) {
    if (!ivarName) return nil;
    Ivar iv = class_getInstanceVariable([host class], ivarName);
    if (!iv) return nil;
    id v = object_getIvar(host, iv);
    return [v isKindOfClass:[UIView class]] ? v : nil;
}

NSUInteger LYHWApplyRulesForView(UIView *host) {
    if (!host) return 0;
    NSUInteger n = 0, cnt = sizeof(kRules) / sizeof(kRules[0]);
    UIView *parent = host.superview;
    UIView *grand  = parent.superview;
    for (NSUInteger i = 0; i < cnt; i++) {
        const LYHWRule *r = &kRules[i];
        if (!LYHWMatchClass(host, r->host)) continue;
        if (r->parent && !LYHWMatchClass(parent, r->parent)) continue;
        if (r->grand  && !LYHWMatchClass(grand,  r->grand))  continue;
        LYHWStyle st = LYHWStyleFor(r->key);
        if (!st.on) continue;
        switch (r->target) {
            case LYHWRuleTargetSelf:   LYHWApplyTo(host, st); break;
            case LYHWRuleTargetParent: LYHWApplyTo(parent, st); break;
            case LYHWRuleTargetIvar:   LYHWApplyTo(LYHWIvarView(host, r->arg), st); break;
            case LYHWRuleTargetSubs: {
                NSArray *names = [LYHWStr(r->arg) componentsSeparatedByString:@","];
                for (UIView *sv in host.subviews) {
                    for (NSString *nm in names) {
                        Class c = LYHWClassNamed(nm);
                        if (c && [sv isKindOfClass:c]) { LYHWApplyTo(sv, st); break; }
                    }
                }
                break;
            }
        }
        n++;
    }
    return n;
}
