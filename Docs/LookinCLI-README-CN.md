# Lookin CLI

Lookin CLI (`lookin-cli`) 是 [Lookin](https://lookin.work) 的命令行接口 —— 一款 iOS 视图层级检查工具。它将 Lookin 的检查能力以可编程的方式暴露出来，适用于脚本自动化、CI 流水线和 AI 驱动的工作流。

## 安装

### 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/nicklama/lookin/Develop/scripts/install.sh | bash
```

自动下载预构建二进制，若无可用版本则从源码编译。

### 从 GitHub Releases 下载

从 [Releases](https://github.com/nicklama/lookin/releases) 页面下载对应架构的二进制：

```bash
# Apple Silicon (M1/M2/M3/M4)
curl -fsSL https://github.com/nicklama/lookin/releases/latest/download/lookin-cli-macos-arm64.tar.gz | tar xz
sudo mv lookin-cli /usr/local/bin/

# Intel
curl -fsSL https://github.com/nicklama/lookin/releases/latest/download/lookin-cli-macos-x86_64.tar.gz | tar xz
sudo mv lookin-cli /usr/local/bin/
```

### 从源码构建

需要 macOS 12.0+ 和 Swift 5.9+。

```bash
git clone https://github.com/nicklama/lookin.git
cd lookin
make install    # 编译 release 版本并安装到 /usr/local/bin
```

或手动操作：

```bash
swift build -c release
cp .build/release/lookin-cli /usr/local/bin/
```

### 卸载

```bash
make uninstall
# 或: rm /usr/local/bin/lookin-cli
```

## 环境要求

- macOS 12.0+
- iOS 应用需集成 [LookinServer](https://github.com/QMUI/LookinServer)（用于实时检查）

## 快速开始

```bash
# 扫描运行中的 LookinServer 应用
lookin-cli scan

# 列出可检查的应用
lookin-cli apps list
lookin-cli apps list --json

# 连接应用并导出层级结构
lookin-cli session connect com.example.app
lookin-cli hierarchy dump
lookin-cli hierarchy dump --json

# 查询节点
lookin-cli query "UIButton"
lookin-cli query ".visible AND UILabel" --json

# 修改视图属性（实时生效）
lookin-cli attr set <oid> alpha 0.5
lookin-cli attr set <oid> text "Hello"
lookin-cli attr set <oid> hidden true

# 运行诊断
lookin-cli diagnose all
```

> `--session` 参数可省略 —— 连接后会自动保存会话，后续命令自动使用。

## 命令

### apps — 应用发现

发现模拟器上运行的可检查 iOS 应用。

```bash
lookin-cli apps list              # 人类可读格式
lookin-cli apps list --json       # JSON 格式
lookin-cli apps list --mock       # 使用模拟数据（测试用）
```

输出示例：

```
[SIM] LookinTestApp — com.lookin.testapp (port:47164)
```

### session — 会话管理

管理检查会话。连接后会话自动持久化到 `~/.lookin-cli/session.json`，后续命令无需重复指定 `--session`。

```bash
lookin-cli session connect com.example.app     # 通过 bundle ID 连接
lookin-cli session connect com.example.app --json
lookin-cli session status                       # 查看当前会话状态
lookin-cli session disconnect --session <id>    # 断开连接
```

### hierarchy — 视图层级

获取并展示完整的视图层级结构。

```bash
lookin-cli hierarchy dump
lookin-cli hierarchy dump --json
lookin-cli hierarchy dump --max-depth 3   # 限制展示深度
```

人类可读输出：

```
App: LookinTestApp (com.lookin.testapp)
Nodes: 24
Screen: 390x844 @3x

UIWindow (oid:1) frame:(0,0,390,844)
  UIView (oid:2) frame:(0,0,390,844)
    UILabel (oid:3) frame:(20,100,200,30)
    UIButton (oid:4) frame:(50,400,100,44)
      UILabel (oid:5) frame:(10,5,80,20)
```

### node — 节点详情

通过 OID（对象标识符）检查单个节点。

```bash
lookin-cli node get 4
lookin-cli node get 4 --json
```

输出：

```
UIButton (oid:4)
  Address:    0x600004
  Frame:      (50, 400, 100, 44)
  Bounds:     (0, 0, 100, 44)
  Hidden:     false
  Alpha:      1.0
  Interactive:true
  A11y ID:    tapButton
  Children:   1
```

### query — 节点查询

使用表达式语言查询节点。

```bash
lookin-cli query "UILabel"
lookin-cli query ".visible AND UIButton" --json
lookin-cli query "UIButton" --count    # 只返回数量
```

#### 查询语法

| 表达式 | 说明 |
|--------|------|
| `UILabel` | 精确匹配类名 |
| `UILabel*` | 类名前缀匹配 |
| `*Label` | 类名后缀匹配 |
| `class:UIButton` | 显式类名匹配 |
| `oid:123` | 按对象 ID 匹配 |
| `tag:42` | 按 tag 匹配 |
| `depth:3` | 按层级深度匹配 |
| `#loginButton` | 按 accessibilityIdentifier 匹配 |
| `@"提交"` | 按 accessibilityLabel 匹配 |
| `.visible` | 仅可见节点 |
| `.hidden` | 仅隐藏节点 |
| `.interactive` | 仅可交互节点 |
| `parent:UIView` | 按父节点类名匹配 |
| `A AND B` | 逻辑与 |
| `A OR B` | 逻辑或 |
| `NOT A` | 逻辑非 |
| `(A OR B) AND C` | 括号分组 |

示例：

```bash
lookin-cli query "UIButton AND .visible"
lookin-cli query "(UIButton OR UILabel) AND .visible"
lookin-cli query "#submitButton"
lookin-cli query "@\"点击我\""
lookin-cli query "parent:UIStackView"
lookin-cli query "NOT UIView"
```

### attr — 属性读写

获取或修改节点属性。**修改会实时反映到模拟器中。**

```bash
# 获取节点所有属性
lookin-cli attr get 4
lookin-cli attr get 4 --json

# 修改属性（实时生效）
lookin-cli attr set 4 alpha 0.5          # 修改透明度
lookin-cli attr set 4 hidden true        # 隐藏视图
lookin-cli attr set 4 text "Hello"       # 修改文本内容
lookin-cli attr set 4 backgroundColor "#FF0000"  # 修改背景颜色
lookin-cli attr set 4 cornerRadius 12    # 修改圆角

# 危险操作需要 --force
lookin-cli attr set 4 removeFromSuperview "" --force
```

### console — 方法调用

在运行中的应用上调用对象方法。

```bash
lookin-cli console eval setNeedsLayout --node-id 4
lookin-cli console eval layoutIfNeeded --node-id 4 --json
```

### select — 选择节点

选择一个节点用于后续检查。

```bash
lookin-cli select 4
```

### export — 导出

将层级数据导出到文件。

```bash
# 导出为 JSON / 文本 / HTML
lookin-cli export hierarchy -o hierarchy.json
lookin-cli export hierarchy -o tree.txt --format text
lookin-cli export hierarchy -o tree.html --format html

# 生成摘要报告
lookin-cli export report -o report.md
```

### diagnose — 诊断

对视图层级运行诊断检查。

```bash
# 单项检查
lookin-cli diagnose overlap                # 检测重叠的可交互视图
lookin-cli diagnose hidden-interactive     # 检测隐藏但可交互的视图
lookin-cli diagnose offscreen              # 检测屏幕外的视图

# 运行全部诊断
lookin-cli diagnose all --json
```

输出示例：

```
Diagnostic: overlap
Checked: 7 nodes
Summary: Found 1 overlapping view pair(s)

  [WARN] UIButton(oid:4) overlaps with UIView(oid:7) — 85% of smaller view

Diagnostic: hiddenInteractive
Checked: 8 nodes
Summary: Found 1 hidden interactive view(s)

  [WARN] UIButton(oid:8) is interactive but not visible: isHidden=true
```

发现问题时退出码非零，适合 CI 集成。

### scan — 端口扫描

扫描所有 Lookin 端口，报告发现的应用。

```bash
lookin-cli scan
lookin-cli scan --json
```

## JSON 输出

所有命令支持 `--json` 参数输出机器可解析的格式。JSON 字段名跨版本稳定。

```bash
lookin-cli apps list --json
```

```json
[
  {
    "appName": "LookinTestApp",
    "bundleIdentifier": "com.lookin.testapp",
    "deviceName": "iPhone 16 Pro (18.0)",
    "deviceType": "simulator",
    "port": 47164,
    "serverVersion": "1.2.8"
  }
]
```

错误同样以 JSON 格式返回：

```json
{
  "error": true,
  "code": 10,
  "message": "No inspectable apps found"
}
```

## 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 成功 |
| 10 | 未找到应用 |
| 11 | 指定应用不存在 |
| 20 | 未连接会话 |
| 21 | 连接失败 |
| 22 | 连接超时 |
| 30 | 节点不存在 |
| 31 | 查询语法错误 |
| 40 | 截图失败 |
| 50 | 属性修改失败 |
| 51 | 方法调用失败 |
| 60 | 导出失败 |
| 70 | 服务端版本不兼容 |
| 71 | 应用进入后台 |
| 72 | 协议错误 |

## 架构

```
lookin-cli (可执行文件)
    |
    +-- LookinCLI        (13 个命令族 + 输出格式化)
    |
    +-- LookinCore        (服务协议、数据模型、查询引擎、诊断)
    |     |
    |     +-- Models      (LKNode, LKHierarchySnapshot, LKAppDescriptor, ...)
    |     +-- Services    (Live 实现 + Mock 实现)
    |     +-- Query       (LKQueryEngine — 查询引擎)
    |     +-- Diagnostics (重叠检测、隐藏交互检测、屏幕外检测)
    |     +-- Protocol    (LKTCPConnection, LKFrameCodec, LKProtocolClient)
    |     +-- Export      (JSON, 文本, HTML, 报告)
    |
    +-- LookinSharedBridge (ObjC NSSecureCoding 类型，用于 Peertalk 协议通信)
```

### 协议

Lookin CLI 通过 Peertalk 协议与 iOS 模拟器应用通信：

- **模拟器端口**: 47164-47169 (localhost)
- **设备端口**: 47175-47179 — 尚未实现（需要 usbmuxd/Peertalk USB Hub）
- **帧格式**: 16 字节头部 (version + type + tag + payloadSize) + 载荷
- **序列化**: NSKeyedArchiver + NSSecureCoding
- **服务端版本**: 兼容 LookinServer 1.2.8（协议版本 7）

## 实时模式

所有命令默认连接真实 iOS 应用。会话状态持久化到 `~/.lookin-cli/session.json`。

**已在真机验证的操作（iPhone 16 Pro 模拟器, LookinServer 1.2.8）：**

| 操作 | 状态 | 示例 |
|------|------|------|
| 应用发现 | 可用 | `apps list` |
| 会话连接 | 可用 | `session connect com.example.app` |
| 会话持久化 | 可用 | `session status`（跨进程） |
| 层级导出 | 可用 | `hierarchy dump`（无限次） |
| 节点查询 | 可用 | `query "UILabel"` |
| 修改透明度 | 可用 | `attr set <oid> alpha 0.5` |
| 隐藏视图 | 可用 | `attr set <oid> hidden true` |
| 修改文本 | 可用 | `attr set <oid> text "Hello"` |
| 诊断检查 | 可用 | `diagnose all` |
| 截图 | 未实现 | 需要 hierarchy details 协议支持 |

**已知限制：** 执行一次属性修改（`attr set`）后，后续修改需要重启被检查的应用。这是 LookinServer 处理修改响应后的内部状态管理导致的。只读操作（hierarchy、query、diagnose）可无限次执行。

### 支持的属性（40+）

**View 属性**: `alpha`, `hidden`, `opaque`, `clipsToBounds`, `userInteractionEnabled`, `backgroundColor`, `tintColor`, `contentMode`, `tag`, `frame`, `bounds`, `center`, `transform`

**UILabel**: `text`, `numberOfLines`, `textAlignment`, `lineBreakMode`, `textColor`

**UIButton**: `enabled`, `selected`, `highlighted`

**UIScrollView**: `contentOffset`, `contentSize`, `contentInset`, `scrollEnabled`, `pagingEnabled`, `bounces`, `zoomScale`, `minimumZoomScale`, `maximumZoomScale`, `bouncesZoom`

**UIStackView**: `spacing`, `axis`, `alignment`, `distribution`

**CALayer**: `opacity`, `cornerRadius`, `borderWidth`, `borderColor`, `shadowOpacity`, `shadowRadius`, `masksToBounds`

**值格式**: `"0.5"`（数字）、`"true"/"false"`（布尔）、`"#FF0000"` 或 `"255,0,0"`（颜色）、`"{{0,0},{100,200}}"`（矩形）

## iOS 应用配置

在 iOS 项目中添加 LookinServer：

```ruby
# Podfile
pod 'LookinServer', :configurations => ['Debug']
```

```bash
pod install
```

无需修改代码 —— LookinServer 在 Debug 构建中自动启动。

## 测试

```bash
swift test     # 运行全部 106 个测试
```

测试分类：
- **模型测试**: Codable 往返、JSON 结构稳定性、可见性逻辑
- **查询引擎测试**: 所有表达式类型、逻辑运算符、边界情况
- **诊断测试**: 重叠检测、隐藏交互检测、屏幕外检测
- **CLI 命令测试**: 端到端服务流程（使用 mock 数据）
- **Fixture 集成测试**: JSON fixture 加载、查询、导出、诊断
- **JSON 输出测试**: 所有响应类型的字段名稳定性

## 许可证

与 [Lookin](https://github.com/nicklama/lookin) 相同 — MIT License。
