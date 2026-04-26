# ImageGallery TCA 重构记录与避坑清单

## 变更目标
- 用 TCA reducer/store 替换旧 `ObservableObject + ViewModel` 主路径。
- 修复分页/缩放/手势冲突、顶部栏跟随图片、相邻页重叠等问题。
- 清理旧架构遗留文件，保留最小可维护代码面。

## 本次主要改动
- 引入 TCA 并固定版本到 `1.8.2`。
- 新增 `ImageGalleryFeature`，集中管理：分页、缩放、拖拽、双击缩放、边缘翻页接管。
- `ImageGalleryView` 改为基于 `StoreOf<ImageGalleryFeature>` 渲染。
- 顶部栏改为纯值组件，固定在容器顶部，不跟随图片 frame。
- `ScreenOutGeometryModifier` 在 dismiss 时支持：
  - 有 source frame -> 反向几何动画。
  - 无 source frame -> 淡出。
- 删除旧 VM 路径文件（`GallrayViewModel`、`ZoomingView`、`ImageNodeView` 等）。
- 新增/保留测试：
  - `ImageGalleryFeatureTests`（分页阈值、双击缩放、边缘接管翻页）
  - `ScreenOutGeometryMathTests`

## 遇到的问题与解决方案

### 1) TCA 版本平台不匹配导致构建失败
- 现象：`ComposableArchitecture` 要求 iOS 16（在 1.24.1 下）。
- 处理：降级并固定到 `1.8.2`，满足 iOS 15 目标，同时保持 reducer 能力。
- 结论：后续优先做“依赖版本-平台矩阵”检查再开工。

### 2) 修改 Manifest 后，Xcode MCP 仍使用旧依赖
- 现象：`Package.swift` 已改，但 MCP 构建仍按旧版本解析。
- 根因：workspace 的 `Package.resolved` 未同步。
- 处理：同步更新两个锁文件：
  - `Package.resolved`
  - `IntegrationApps/.../xcshareddata/swiftpm/Package.resolved`
- 结论：每次改 SPM 版本都要同时核对 `Package.resolved`（包级 + 工程级）。

### 3) GIF 分支 API 假设错误
- 现象：`GIFImageView` 没有 `resizable()`，编译报错。
- 处理：移除 GIF 分支里的 `resizable/scaledToFit`，只做展示与淡入。
- 结论：URLImage 与 GIFImage 是不同视图类型，不能共享同一链式修饰假设。

### 4) dismiss 总是淡出，无法反向缩回 source
- 现象：`activeID = nil` 后 source frame 被清空，只能淡出。
- 处理：在 `activeID` 变更逻辑中优先尝试 `internalID` 对应 frame；存在则反向几何动画，否则淡出。
- 结论：dismiss 时不能只看“当前 binding 值”，还要保留“最后有效 source 身份”。

### 5) MCP `RunAllTests` 出现 `No result`
- 现象：UITest 列出用例但执行结果全为 `No result`。
- 处理：
  - 用 MCP `BuildProject` 做编译验收。
  - 用 `swift test` 做包内逻辑验证。
- 结论：在当前环境下，MCP 的 UITest 可能无法稳定拉起执行；需把验证拆成“编译验收 + 单测验收 + 手工/CI UI 验收”。

### 6) SwiftSyntax identity 冲突 warning
- 现象：`apple/swift-syntax` 与 `swiftlang/swift-syntax` 身份冲突 warning。
- 状态：warning，不阻塞构建。
- 后续：关注上游依赖统一（尤其 ChainBuilder 与 TCA 依赖链）。

## 后续任务启动前检查清单
1. 先确认目标平台（iOS/macOS）与依赖版本兼容矩阵。
2. 若改了 SPM 依赖，立即同步检查两处 `Package.resolved`。
3. 先跑 MCP 构建，再跑 `swift test`，最后再看 UITest。
4. 对动画回退路径，先定义“有 source / 无 source”两条分支再写代码。
5. 对第三方 View（URLImage/GIFImage）先核对 API 差异再抽象公用逻辑。
