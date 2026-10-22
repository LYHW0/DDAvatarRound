# LYHW

微信界面美化的重制版 —— **界面圆角 / 资料卡美化 / 消息横幅美化 / 菜单美化 / 头像框圆角** 五个板块。

- 架构：**arm64 单架构**
- 包格式：**rootless**（`/var/jb`，iOS 15+ 越狱通用；Dopamine / palera1n / Xina 等）
- 编译：Theos + GitHub Actions，推上去自动出 deb，不用本地装环境
- 支持微信包名：`com.tencent.xin` / `com.tencent.wx` / `com.tencent.mm.xin` / `com.tencent.qy.xin`（含各 share extension）

---

## 一、这五个板块都做了什么

### 1. 界面圆角（`Sources/WCRCorner.x`）
把列表切成"卡片"：会话列表、通讯录、发现页、收藏页、折叠分组。

挂的类和原版一致：

```
MMTableViewCell(layoutSubviews / setBackgroundColor:)
MainFrameTableView(layoutSubviews)          NewMainFrameCell(layoutSubviews)
MainFrameSectionFoldView(layoutSubviews)    MFBannerBtn / MFWebMMBtn(layoutSubviews)
MMTableSectionHeaderView  MMMainTableView   MMTableView
MMUnderlineTabsView  WCToolGroupsBannerView  MMFavImageComponent  FavImagePreview
NewContactsItemCell  ThemeBoxSegmentedView   WCSegmentedControl
```

设置项：圆角大小（默认 **15**，取自原版二进制默认值）、卡片间距、左右留白、描边宽度、深浅色背景/描边。

### 2. 资料卡美化（`Sources/WCRProfileCard.x`）
联系人资料页 / 名片页：背景图、背景色、卡片圆角（可跟随全局圆角）、昵称与签名配色、微信号默认隐藏。

```
ContactInfoViewController(viewDidLoad / viewWillAppear: / viewDidLayoutSubviews)
WCTimeLineCellView(showContactInfo / showProfileForUser:)
```

### 3. 消息横幅美化（`Sources/WCRMsgBanner.x`）
微信内新消息横幅：高度、宽度、外边距、正文截断字数、背景图/背景色、昵称与正文配色。

```
MMLocalNotificationUtil(showLocalNotificationWithIdentifier:...customHeadImage:)
MainFrameLogicController(playNewMsgNotify:NotifyFlag:)
```

横幅窗口是运行时动态创建的，这里用"结构扫描 + 定时补样式"定位，
不写死私有类名，微信小版本升级不会直接失效。

### 4. 菜单美化（`Sources/WCRMenu.x`）
长按菜单 / 加号菜单：圆角、描边、底色、背景图、文字色、图标色、宽度、去掉分割线。

```
MMMenuContentView(layoutSubviews / addSeparatorLineInY:left:right:)
MMMenuController(setMenuStyle:)
```

### 5. 头像框圆角（`Sources/WCRAvatar.x`）
头像圆角按**百分比**控制（默认 **100%** = 正圆，与原版默认值一致），可加描边、可缩放留白。

```
MMHeadImageView(layoutSubviews / setFrame: / setBounds: / setHeadImageViewCornerRadius:)
MMUILongPressImageView(setImage:)   FakeHeadImageView   WCFinderHeadImageView
```

---

## 二、编译（GitHub Actions，推荐）

1. 新建一个仓库，把本目录所有文件推上去（保持 `Makefile`、`control`、`Tweak.x`、`Sources/`、`prefs/`、`.github/` 的相对位置）。
2. 仓库 → **Actions** → 选 `Build` → **Run workflow**。
3. 跑完在 **Artifacts** 里下载 `LYHW-deb`，里面是 `com.lyhw.lanyinhouwu_1.0.0_iphoneos-arm64.deb`。

工作流做的事：装 Theos → 把 Xcode 的 iPhoneOS SDK 链到 `$THEOS/sdks` → `make package FINALPACKAGE=1` → 上传 deb。

## 三、编译（本地 macOS）

```bash
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
brew install ldid xz make

mkdir -p $THEOS/sdks
ln -sfn "$(xcrun --sdk iphoneos --show-sdk-path)" \
        "$THEOS/sdks/iPhoneOS$(xcrun --sdk iphoneos --show-sdk-version).sdk"

make clean && make package FINALPACKAGE=1
# 产物在 packages/
```

本地 Linux 也可以：把 `theos/sdks` 里的 iPhoneOS SDK 放到 `$THEOS/sdks/` 即可。

## 四、安装

```bash
# rootless（/var/jb）
dpkg -i com.lyhw.lanyinhouwu_1.0.0_iphoneos-arm64.deb
# 或者用 Sileo / Filza 直接点开 deb 安装

killall -9 WeChat   # 重开微信
```

装完在 **设置** 里会多一个 **LYHW** 入口，五个板块的设置都在里面，改完立刻生效（走 Darwin 通知，不用重启微信）。

配置存放位置：`/var/mobile/Library/Preferences/com.lyhw.LYHW.plist`

---

## 五、目录结构

```
LYHW/
├── Makefile                  # 主工程（arm64 / rootless）
├── control                   # deb 元信息
├── LYHW.plist     # 注入过滤（微信各包名）
├── Tweak.x                   # 入口：配置加载 + 跨进程设置同步
├── Sources/
│   ├── WCRCommon.h/.m        # 颜色解析 / 圆角 / 视图工具
│   ├── WCRConfig.h/.m        # 配置中心（key 与原版同名）
│   ├── WCRCorner.x           # 模块一：界面圆角
│   ├── WCRProfileCard.x      # 模块二：资料卡美化
│   ├── WCRMsgBanner.x        # 模块三：消息横幅美化
│   ├── WCRMenu.x             # 模块四：菜单美化
│   └── WCRAvatar.x           # 模块五：头像框圆角
├── prefs/                    # 设置面板（PreferenceBundle）
│   ├── WCRRootListController.m
│   ├── Resources/Info.plist
│   └── layout/Library/PreferenceLoader/Preferences/LYHW.plist
└── .github/workflows/build.yml
```

---

## 六、关于"还原度"的说明

这份源码是**按原版 deb 里的 arm64 二进制反编译结果重建的**：

- hook 的类、方法、顺序：从二进制 `__init_offsets` 里的 212 个初始化函数逐个反汇编还原（`MSHookMessageEx` 的目标类名 + 选择器）；
- 配置键（`homepageCornerEnabled` / `globalCornerRadius` / `avatarCornerRadius` / `msgBanner*` / `menu*` / `profileCard*` 等）：从 `LYHWConfig` 类的 4861 个方法表里导出；
- 默认值：从对应 getter 的汇编里读出的立即数（圆角 15、头像圆角 100% 等）。

**必须说清楚的一点**：原始 `.m` 源码没有随 deb 发布，编译器优化后的产物不可能逐字节还原成原始工程。
所以这份是**功能等价、hook 点一致、配置键一致**重写版，不是原作者的原始工程文件。
五个板块的功能都实现了、能出效果；但原版里另外上百个无关功能（群发、AI、主题、视频号下载等）没有包含进来——你只要这五个。

## 七、改色 / 改默认值

- 改默认值：`Sources/WCRConfig.m` 里每个宏后面第三个参数就是默认值。
- 加设置项：`prefs/WCRRootListController.m` 的 `-specifiers` 里照着 `switchRow/sliderRow/textRow` 加一行即可。
- 想让某个页面也上圆角：在 `WCRCorner.x` 里照着现有写法加个 `%hook 类名 - (void)layoutSubviews { %orig; WCRApplyCorner(...); }`。
