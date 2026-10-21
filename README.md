# WCCornerReverse

WCRefine 2.1-9「界面圆角」板块的完整逆向复刻。
只做这一个板块：设置界面 + 全部功能项 + 圆角渲染引擎。

- 包名：`com.wcr.corner.reverse`
- 版本：`1.0.1`
- 架构：**arm64 单架构**（`iphoneos-arm64`，rootless，装到 `/var/jb`）
- 最低系统：iOS 14.0
- 注入目标：`com.tencent.xin`、`com.tencent.wx`、`com.tencent.mm.xin`、`com.tencent.qy.xin`

## 目录

```
include/WCRCorner.h          头文件（配置表 X-Macro + 表格框架 + 引擎 + 注册器声明）
src/WCRConfig.mm             配置层（存取 / clamp / 落盘 / 重置）
src/WCRTable.mm              设置页表格框架（复刻微信 WCTableViewManager 视觉）
src/WCRCornerVC.mm           主板块「界面圆角」（22 个分组）
src/WCRGlobalVC.mm           子页「主页全局圆角」
src/WCREngine.mm             圆角渲染引擎 + hook 安装
src/WCRPlugin.mm             注册入口（WCPluginsMgr 为主通道）
src/Tweak.xm                 注入入口（logos）
WCCornerReverse.plist        注入配置（4 个微信包名）
control                      deb 元信息
Makefile                     Theos 工程（ARCHS = arm64）
build-dylib.sh               本地一键出 dylib
build-deb.sh                 本地一键出 deb
prebuilt/Tweak.mm            logos 预处理结果（没装 Theos 时兜底）
.github/workflows/build.yml  推到 GitHub 自动出 deb + dylib
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

### 方式一：GitHub Actions（推荐，不用本地装工具链）

```bash
git init && git add -A && git commit -m "init"
git remote add origin https://github.com/<你的账号>/<仓库名>.git
git push -u origin main
```

推上去之后 Actions 自动开始跑（也可以到 Actions 页面点 `Run workflow` 手动触发）。

流程：macOS runner → 装 Theos + iPhoneOS16.5 SDK → `make package ARCHS=arm64` →
产出 rootless deb + dylib → 上传 artifacts。

跑完在 **Actions → 对应那次 run → Artifacts** 里下载 `WCCornerReverse-arm64`，
里面两个文件：

```
com.wcr.corner.reverse_1.0.1_iphoneos-arm64.deb
WCCornerReverse.dylib
```

打 tag 会自动发 Release：

```bash
git tag v1.0.1 && git push origin v1.0.1
```

> 只出 arm64 单架构：`Makefile` 里 `ARCHS = arm64`，CI 里也显式传了 `ARCHS=arm64`。
> arm64e 设备（A12 及以上）加载 arm64 slice 正常，不需要额外架构。

### 方式二：本地构建

只需要一份 iOS SDK。编译器二选一：

- macOS：Xcode 命令行工具自带 clang
- Linux：zig 0.13+（自带 clang + lld）

SDK 放这两个位置任意一个：

```
$THEOS/sdks/iPhoneOS16.5.sdk
./sdks/iPhoneOS16.5.sdk
```

只出 dylib：

```bash
./build-dylib.sh
# 产物: dist/WCCornerReverse.dylib（已 ldid 签名）
```

出 deb：

```bash
./build-deb.sh
# 产物: packages/com.wcr.corner.reverse_1.0.1_iphoneos-arm64.deb
```

用 Theos 标准流程（macOS，装好 Theos 和 ldid）：

```bash
make package FINALPACKAGE=1 ARCHS=arm64 THEOS_PACKAGE_SCHEME=rootless
```

## 安装

```bash
# 越狱设备上（rootless 环境）
dpkg -i com.wcr.corner.reverse_1.0.1_iphoneos-arm64.deb
# 或者用 Sileo / Zebra 直接装 deb
```

只拿到 dylib 的话，手动放：

```
/var/jb/Library/MobileSubstrate/DynamicLibraries/WCCornerReverse.dylib
/var/jb/Library/MobileSubstrate/DynamicLibraries/WCCornerReverse.plist
```

然后 `killall -9 WeChat`（或重启桌面）重进微信，从插件收纳里进「界面圆角」。

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
