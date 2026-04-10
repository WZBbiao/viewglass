# Viewglass CLI — Bug & Improvement Tracker

## Bugs

- [x] **#1 OID +1 偏移** (`LKBridgeConverter`)
  `hierarchy` 展示的是 `layerOid`（如 106），但 `tap`/`input`/`attr set` 操作时用的是 `viewOid`（如 107），造成输出不一致。
  根因：`convertDisplayItem` 中 `oid = layerOid ?? viewOid` 而 `actionOid = viewOid ?? layerOid`。
  修复：统一 `node.oid` 为 `viewOid ?? layerOid`（与 `primaryOid` 一致）。

- [x] **#2 control tap 无法切换 UISwitch** (`ControlCommand`, `LiveMutationService`)
  `control tap` 只发送 `UIControlEventTouchUpInside`，但 UISwitch 的切换需在 touch tracking 期间完成，单纯发送此事件不改变 `isOn`。
  修复：检测到 UISwitch 时，读取当前 `isOn`，通过 `setAttribute` 取反，再发送 `UIControlEventValueChanged`。

- [x] **#3 locate 无法按文本内容搜索** (`LKLocator`)
  `viewglass locate "Open Long Feed"` 返回 0 结果（字符串被当作类名查询处理）。
  修复：在 `LKLocator.parse` 中，含空格的字符串 fallback 为 `accessibilityLabel` 类型，而非 `query`。

- [ ] **#4 attr get 缺失 UISwitch.isOn 和 UISegmentedControl.selectedSegmentIndex** (`LiveNodeQueryService`)
  服务端未为这两个控件注册属性组，`attr get` 看不到当前值。
  修复：CLI 端在返回属性列表时，对 UISwitch/UISegmentedControl 通过 `invokeMethod` 读取后注入到 `[viewglass_runtime]` 组。

- [x] **#5 attr set 修改控件属性后不触发 UIControlEventValueChanged** (`LiveMutationService`)
  `attr set isOn false` / `attr set selectedSegmentIndex 0` 直接修改属性，不走 UIKit 事件流，应用层 `valueChanged` 回调不触发。
  修复：对 `isOn`、`selectedSegmentIndex`、`selected` 等控件状态属性，修改后额外发送 `UIControlEventValueChanged`。

## Improvements

- [ ] **#6 OID 参数格式不统一** (`ControlCommand`, `NodeCommand`, `ConsoleCommand`)
  `tap`/`attr set`/`scroll` 接受 `oid:N` 格式，而 `control tap`/`node get`/`console eval` 只接受纯数字。
  修复：统一支持两种格式（`oid:N` 和纯数字 `N`）。

- [ ] **#7 scroll 缺少 --animated 选项** (`ScrollCommand`)
  `scroll --to` 直接跳转 contentOffset，无平滑动画。
  修复：增加 `--animated` flag，启用时通过 `setContentOffset:animated:` 实现过渡。

- [ ] **#8 screenshot node 截取 secure text field 时无警告** (`ScreenshotCommand`)
  对 UITextField (secureTextEntry) 截图结果为空白，没有任何提示。
  修复：截图前检测目标是 UITextField，截图后输出 warning 说明安全字段内容不可见。
