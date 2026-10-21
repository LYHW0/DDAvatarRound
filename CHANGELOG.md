# 更新报告 —— 2026-10-21

## v1.0.1：改成 GitHub 可直接打包 + arm64 单架构

这次不动功能代码，只改构建这件事。

### 1. 架构收成 arm64 单架构

- `Makefile`：`ARCHS = arm64 arm64e` → `ARCHS = arm64`
- `TARGET` 从 `latest` 固定为 `iphone:clang:16.5:14.0`，SDK 版本不再随环境漂
- 产出的 dylib 已核对：`Mach-O 64-bit arm64 dynamically linked shared library`，
  `LC_ID_DYLIB` = `/var/jb/Library/MobileSubstrate/DynamicLibraries/WCCornerReverse.dylib`
- arm64e 设备（A12 及以上）加载 arm64 slice 正常，不需要双架构

### 2. GitHub Actions 换成现在能跑通的写法

旧的 workflow 有两个死点：

| 问题 | 后果 | 改法 |
|---|---|---|
| `runs-on: macos-13` | GitHub 上 macos-13 runner 已彻底下线，job 直接排队失败 | 换 `macos-14` |
| 靠 `sdks/archive/refs/heads/master.zip` 拉 SDK | 几百 MB 整包下载，动不动超时 | 改 `git clone --filter=blob:none --sparse`，只取 `iPhoneOS16.5.sdk` |

另外补的：

- Theos 目录加了 `actions/cache`，第二次构建不用重新 clone
- 构建命令显式带 `ARCHS=arm64`，不依赖默认值
- artifacts 里同时上传 **deb 和 dylib**，并且用 `lipo -info` 打印架构做自检
- 打 `v*` tag 时自动挂到 Release（`softprops/action-gh-release`）

### 3. 本地构建脚本重写

- `build-dylib.sh`：只出 dylib，自动找 SDK（`$THEOS/sdks` 或 `./sdks`），
  自动选编译器（macOS 用 clang，Linux 用 zig），自动 `ldid -S` 签名
- `build-deb.sh`：改为复用 `build-dylib.sh` 的产物，只做打包，不再重复实现一遍编译逻辑
- 没装 Theos 也能编：`prebuilt/Tweak.mm` 是 logos 的预处理结果，自动兜底

### 4. 实测

- 7 个编译单元（6 个源文件 + logos 生成的入口）全部 0 error
- 链接 → arm64 Mach-O dylib，`LC_CODE_SIGNATURE` 已写入
- `dpkg-deb` 出包，解包复核：dylib 405,584 字节 + plist 都在位
- 从干净目录跑 `./build-deb.sh` 完整复现，结果一致

---

## v1.0.0：注册入口与界面校准

本轮在原逆向成果上补齐两件事：**注册入口走 WCPluginsMgr**、**注入包名补齐 4 个**；
同时按原版二进制反汇编重新核了一遍界面，把偏差改回去了。

---

## 一、注册入口：WCPluginsMgr

新增 `src/WCRPlugin.mm`，`WCRPluginRegistrar` 负责把「界面圆角」注册进插件收纳。

按三级降级，任何一级不存在都不会崩：

| 级别 | 目标 | 做法 |
|---|---|---|
| 1 | `WCPluginsMgr`（主通道） | 运行时按类名取；单例方法（`sharedInstance` / `sharedManager` / `shared` / `defaultManager` / `manager` …）与类方法都试；插件模型用 `WCPluginModel`，字段逐个 `respondsToSelector:` 探测后再 KVC 写入 |
| 2 | `WCRefinePluginHubManager` | `-registerPluginForCustomEntry:`，条目 `界面圆角@WCRCornerViewController` |
| 3 | 设置页兜底入口 | 仅当前两级都失败时才在右上角出现，保证一定能进面板 |

注册成功后广播 `WCPluginsMgrDidChangeNotification`，插件收纳列表即时刷新。

> 说明：`WCPluginsMgr` / `WCPluginModel` 在原二进制里都是**运行时按名字取**的（没有编译期类引用），
> 所以这里同样用运行时探测，不写死选择器——原版换了字段名也不会注册失败。

## 二、注入包名

`WCCornerReverse.plist` 从 1 个扩到 4 个：

```
com.tencent.xin   com.tencent.wx   com.tencent.mm.xin   com.tencent.qy.xin
```

## 三、界面按反汇编重新校准

对着原版 `reloadTableData` 的 cell 构造顺序逐条比对（主板块 204 个方法 / 22 个分组，
全局圆角子页 33 个方法 / 18 行），改了 4 处偏差：

1. **「清除遮罩」不是独立开关行**。原版是普通 cell，点击弹二级菜单：
   「用于清除ThemeBox搜索遮罩层 / 仅在使用盒子主题时再开启」→ 开关 + 「替换内容」
   （替换内容弹「设置搜索框占位显示文本」）。之前把它拆成了两行独立开关，已改回。
2. **「间距一统」补齐**。`mainFrameSpacingUnifyEnabled`，标题就是「间距一统」（不是「间距统一」）。
   开启前弹确认：「此功能可能导致首页卡片故障 / 若用首页卡片不建议开启 / 是否确认开启？」；
   开/关后各弹一次重启提示（「已开启间距一统」/「已恢复默认间距模式」）。
3. **「禁用页面」右侧文案**是「未设置 / 已设置」，不是数字。
4. **「描边样式」是分段控件**（实线 / 虚线 / 点线），不是点开选弹窗。
   还删掉了原版没有的尾部「重启微信生效」按钮。

分组顺序、每组行顺序、footer 文案、范围提示（0-30 / 0-50 / 0.0-5.0 / 0-100）
全部按原版字面量顺序核对过。

## 四、修掉的编译错误（真实错误，不是改着玩）

| # | 位置 | 问题 | 改法 |
|---|---|---|---|
| 1 | WCRCornerVC / WCRGlobalVC | `@xF2F2F2` 非法字面量（3 处） | `@0xF2F2F2` |
| 2 | WCRConfig | **宏参数名与选择器标签撞名**：`def:` / `lo:` / `hi:` 被宏参数替换，展开成 `boolForKey:@"x" __objc_no:(__objc_no)` | 宏参数改名 `dv/lv/hv`，标签保持原样 |
| 3 | WCRConfig | `@([WCRCornerConfig hexFromColor:c])` 把 NSString 装箱，还不报错就存成 0 | 新增 `hexValueFromColor:` 返回 `NSUInteger`，颜色按数值存 |
| 4 | 全部 VC | `typeof(self)` 在 ObjC++ 下解析失败 | `__typeof__(self)` |
| 5 | WCRTable | `WCRRowAction` 声明成带参 block，实际全按无参调用 | typedef 改为 `void (^)(void)` |
| 6 | WCRCorner.h | `globalCornerCustomExcludedCount` 只在 X-Macro 里，没有方法声明 | 补 `- (NSInteger)globalCornerCustomExcludedCount;` |
| 7 | WCRConfig | `resetAllColors` 用点语法写只有 setter 方法的颜色属性 | 改显式 setter 调用 |
| 8 | Tweak.xm | `NewSettingViewController` 只有前向声明，`navigationItem` / `navigationController` 找不到 | 补 `@interface NewSettingViewController : UIViewController` |

## 五、验证

- 6 个源文件 + logos 生成的入口，`aarch64-apple-ios14.0` 交叉编译 **0 error**
- 链接产出 `Mach-O 64-bit arm64 dynamically linked shared library`
- 未定义符号正常（`_MSHookMessageEx` / `_objc_msgSend` 等 119 个，运行时由越狱环境解析）
- `ldid -S` 签名成功（`LC_CODE_SIGNATURE` 3648 字节）
- `dpkg-deb` 出包，解包复核：dylib + plist 都在 `/var/jb/Library/MobileSubstrate/DynamicLibraries/`
- 从干净目录重新解包 → 重新构建，结果一致

## 六、注意事项

1. **只出 arm64（单架构）**。`Makefile` 里 `ARCHS = arm64`，CI 里同样显式传了 `ARCHS=arm64`。
   arm64e 设备（A12 及以上）直接加载 arm64 slice，不需要额外架构。
   哪天要加回 arm64e，只改 Makefile 一行 `ARCHS = arm64 arm64e`，CI 和脚本都不用动。
2. **注册是否命中要看目标机**：`WCPluginsMgr` 的选择器名随微信版本变，
   这里做了多候选探测；万一某个版本一个都没命中，设置页右上角会有兜底入口，
   功能不受影响，只是位置不在收纳里。定位方法：进面板正常就说明走到了第 3 级。
3. **圆角渲染引擎是重写的**：原插件把渲染散在整包几十个 hook 里，没有独立类可对齐，
   这层是按配置项语义重写的（`WCRCornerPainter`，纯 C++ 算参数，ObjC++ 只做 hook 桥接）。
   界面 100% 对齐，渲染效果需要真机逐项比对。
