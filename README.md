# DDAvatarRound - 微信头像圆角插件

一个简洁的微信头像圆角美化 Theos Tweak，支持自定义圆角程度。

## 功能特性

- ✅ 自动将微信头像变为圆角样式
- ✅ 支持自定义圆角程度（0.1 ~ 1.0）
- ✅ 0.1 = 轻微圆角，1.0 = 完全圆形
- ✅ 通过微信内置设置界面控制
- ✅ 纯 ObjC 实现，无需额外依赖
- ✅ 支持 iOS 14.0+

## 安装

### 方式一：直接安装（需要越狱设备）
1. 从 Release 页面下载 `.deb` 文件
2. 通过 Sileo / Zebra / Cydia 安装

### 方式二：自己编译
```bash
git clone https://github.com/YOUR_USERNAME/DDAvatarRound.git
cd DDAvatarRound
make package
```

## 使用方法

1. 打开微信 → 我 → 设置
2. 找到「DD头像圆角」进入设置
3. 开启「启用圆角头像」
4. 点击「↳设置圆角程度」调整圆角值
5. 重启微信生效

## 配置说明

| 圆角值 | 效果 |
|-------|------|
| 0.1 | 轻微圆角，几乎看不出变化 |
| 0.5 | 中等圆角，明显圆润 |
| 0.8 | 较强圆角 |
| 1.0 | 完全圆形头像 |

## 项目结构

```
DDAvatarRound/
├── Sources/
│   ├── DDAvatarRound.h      # 头文件，类声明
│   ├── DDAvatarRound.xm     # 核心 Hook 实现
│   └── DDSettingsVC.xm      # 设置界面
├── Resources/
│   └── DDAvatarRound.plist  # PluginLoader 配置
├── Makefile                 # Theos 构建配置
├── control                  # 包描述文件
└── .github/workflows/
    └── build.yml            # GitHub Actions 打包流程
```

## 编译要求

- Theos 编译环境
- iOS 14.0+ SDK
- 越狱设备（iPhone/iPad）

## 常见问题

**Q: 设置后没有立即生效？**
A: 需要重启微信才能生效，设置界面有提示。

**Q: 圆角不明显？**
A: 尝试调高圆角值（0.5 ~ 0.8），1.0 是完全圆形。

**Q: 支持微信哪个版本？**
A: 测试兼容微信 8.x 版本。

## License

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
