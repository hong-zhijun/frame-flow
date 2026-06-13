# FrameFlow

macOS 原生图片查看器，专为摄影师设计。支持 RAW 格式解码、星级标记筛选、图片边框导出等功能。

## 功能特性

### 图片浏览
- 文件夹导入，按目录结构浏览，支持嵌套子文件夹
- 缩略图网格 + 全屏查看，滚轮缩放（以鼠标指针为中心）、拖拽平移、双击还原
- 键盘快捷键：方向键翻页、ESC 返回、数字键 1-5 快速评星
- 右键菜单：在访达中显示、复制图片
- 历史文件夹记录，启动后快速访问

### RAW 格式支持
- 基于 macOS ImageIO 原生解码
- 支持 CR2 / CR3 / NEF / ARW / DNG / RAF / ORF 等主流 RAW 格式
- 先加载嵌入缩略图，按需解码完整 RAW

### 星级标记与筛选
- 1-5 星评级，本地 JSON 持久化
- 按星级 / 文件格式分类筛选，仅显示当前文件夹中存在的筛选项
- 星级归档：筛选后一键归档到指定文件夹，自动处理文件名冲突

### 图片边框导出
- 自动读取 EXIF 元数据（相机型号、镜头、拍摄参数、日期、位置、作者）
- 白底信息栏：相机 Logo + 型号 + 参数，支持自定义编辑
- 内置 11 个品牌 Logo（Apple / Canon / DJI / Fujifilm / Hasselblad / Leica / Nikon / OPPO / Sony / Vivo / Xiaomi）
- 自定义文字颜色、Logo 缩放、边框显示
- 导出为 JPG，自动创建「图片边框」子文件夹

### 支持的图片格式

| 类型 | 格式 |
|------|------|
| 标准 | JPG / JPEG / PNG / HEIC / HEIF / TIFF / BMP / GIF / WebP |
| RAW | CR2 / CR3 / NEF / ARW / DNG / RAF / ORF / RW2 / PEF / SRW / 3FR |

## 技术栈

- **语言**: Swift 6 + SwiftUI
- **平台**: macOS 26+
- **图片解码**: ImageIO / Core Image
- **边框渲染**: CoreGraphics / CoreText
- **EXIF 读取**: CGImageSource (ImageIO)
- **数据存储**: UserDefaults（历史记录）/ JSON 文件（星级评分）
- **项目管理**: XcodeGen

## 构建

### 前置条件

- macOS 26+
- Xcode 27+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### 构建步骤

```bash
# 1. 克隆项目
git clone git@github.com:hong-zhijun/frame-flow.git
cd frame-flow

# 2. 生成 Xcode 项目
xcodegen generate

# 3. 构建
xcodebuild -project FrameFlow.xcodeproj -scheme FrameFlow -configuration Release build

# 或者用 Xcode 打开
open FrameFlow.xcodeproj
```

### 打包

```bash
xcodebuild -project FrameFlow.xcodeproj -scheme FrameFlow -configuration Release build
ditto -c -k --sequesterRsrc --keepParent \
  ~/Library/Developer/Xcode/DerivedData/FrameFlow-*/Build/Products/Release/FrameFlow.app \
  ~/Desktop/FrameFlow.zip
```

## 项目结构

```
FrameFlow/
├── FrameFlowApp.swift          # 应用入口 + AppState
├── Models/
│   ├── FolderNode.swift        # 文件夹树节点
│   ├── FolderHistory.swift     # 历史记录
│   └── ImageItem.swift         # 图片数据模型
├── Services/
│   ├── FolderScanner.swift     # 文件夹扫描
│   ├── ImageLoader.swift       # 缩略图 / 图片加载
│   ├── RAWProcessor.swift      # RAW 解码
│   ├── EXIFReader.swift        # EXIF 元数据读取
│   ├── FrameRenderer.swift     # 边框渲染 + JPG 导出
│   └── StarRatingStore.swift   # 星级评分持久化
├── Views/
│   ├── MainWindow.swift        # 主窗口 + 键盘快捷键
│   ├── Sidebar/                # 侧边栏（文件夹树 + 历史）
│   ├── Grid/                   # 缩略图网格 + 筛选栏
│   ├── Viewer/                 # 全屏查看 + 缩放
│   ├── Export/                 # 图片边框导出
│   └── Components/             # 通用组件（星级、Toast、归档确认）
├── Utils/
│   └── SupportedFormats.swift  # 格式识别
└── Resources/
    └── Logos/                  # 相机品牌 Logo
```

## 界面语言

所有界面文字均为中文。

## 许可证

MIT License
