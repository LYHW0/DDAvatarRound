# WCCornerReverse

WCRefine 2.1-9「界面圆角」板块的完整逆向复刻。
只做这一个板块：设置界面 + 全部功能项 + 圆角渲染引擎。

- 包名：`com.wcr.corner.reverse`
- 架构：`iphoneos-arm64`（rootless，装到 `/var/jb`）
- 最低系统：iOS 14.0
- 注入目标：`com.tencent.xin`、`com.tencent.wx`、`com.tencent.mm.xin`、`com.tencent.qy.xin`

## 目录

```
include/WCRCorner.h        头文件（配置表 X-Macro + 表格框架 + 引擎 + 注册器声明）
src/WCRConfig.mm           配置层（存取 / clamp / 落盘 / 重置）
src/WCRTable.mm            设置页表格框架（复刻微信 WCTableViewManager 视觉）
src/WCRCornerVC.mm         主板块「界面圆角」（22 个分组）
src/WCRGlobalVC.mm         子页「主页全局圆角」
src/WCREngine.mm           圆角渲染引擎 + hook 安装
src/WCRPlugin.mm           注册入口（WCPluginsMgr 为主通道）
src/Tweak.xm               注入入口（logos）
WCCornerReverse.plist      注入配置（4 个微信包名）
build-deb.sh               本地一键出 deb
.github/workflows/build.yml 推上去自动出 deb
```

## 入口

主入口走 `WCPluginsMgr`（插件收纳的统一注册中心）。注册按三级降级，
任何一级不存在都不会崩：

1. `WCPluginsMgr` —— 运行时按类名取，单例方法 / 类方法都试；
   插件模型用 `WCPluginModel`，字段全部 `respondsToSelector:` 探测后再写。
2. `WCRefinePluginHubManager -registerPluginForCustomEntry:` ——
   条目格式 `界面圆角@WCRCornerViewController`。
3. 设置页右上角兜底按钮 —— 只有前两级都没成功时才出现。

注册完成后广播 `WCPluginsMgrDidChangeNotification`，收纳列表即时刷新。

## 构建

### 方式一：GitHub Actions（推荐）

推到仓库后 `.github/workflows/build.yml` 会自动在 macOS runner 上装 Theos、
编译、打 rootless deb，产物在 Actions 的 artifacts 里。

### 方式二：本地

准备：Theos、iOS SDK、`ldid`、一个能交叉编译到 `aarch64-apple-ios` 的 clang。
也可以直接用 zig 自带的 clang/lld（`build-deb.sh` 默认走这条）。

```bash
export THEOS=/path/to/theos
export SDK=$THEOS/sdks/iPhoneOS16.5.sdk
export LDID=/path/to/ldid
./build-deb.sh
# 产物: packages/com.wcr.corner.reverse_1.0.0_iphoneos-arm64.deb
```

用 Theos 走标准流程也可以：

```bash
make package FINALPACKAGE=1
```

## 安装

```bash
# 越狱设备上（rootless 环境）
dpkg -i com.wcr.corner.reverse_1.0.0_iphoneos-arm64.deb
# 或者用 Sileo / Zebra 直接装 deb
```

装完重启微信，从插件收纳里进「界面圆角」。

## 与上游的对照

界面结构按原版 `reloadTableData` 的 cell 构造顺序逐条还原：

- 主板块 22 个分组：全局cell圆角 / 搜索框 / 输入框 / 输入法 / 顶栏 / 底栏 /
  表情包 / 聊天图片 / 气泡 / 聊天时间 / 消息引用 / 语音转文字 / 拍一拍 /
  系统通知 / 朋友圈 / 视频号 / 服务页 / 加号菜单 / 发送发布按钮 / 系统弹窗 /
  左滑菜单 / 已独立的圆角
- 子页「主页全局圆角」18 行：主页圆角 → 微信页面 → 我的页面 → 好友资料 →
  发现页面 → 禁用页面 → TP 模式 → 圆角大小 → 边距大小 → 间距大小 →
  置顶上间距 → 置顶下间距 → 间距一统 → 背景颜色 → 描边大小 → 描边颜色 →
  描边样式 → 置顶透明

配置键名沿用原插件命名（`searchCornerRadius`、`chatBubbleCornerBorderSize` …），
方便与原版配置互相迁移。
