# 勋章馆 · MedalHall（SwiftUI）

把原来的 Node 项目（`server.js` + `index.html` 单页 Web App）完整重写成原生 SwiftUI App：
界面全部使用 iOS 原生控件（`TabView`、`NavigationStack`、`List`、`Form`、`Picker`、`ShareLink`、`AsyncImage`、`fileImporter` 等），
不再需要本地 Node 代理，签名、SSR 抓取、CGI 请求都在 App 内完成。

- 工具链：**Xcode 27.2 / iOS 27.2 SDK**，部署目标 iOS 27.0
- CI：按 [ios-ci-workflows](https://github.com/wenjinliuu/ios-ci-workflows) 的 Skill 接入（`.ios-ci.yml` + 入口工作流 + AGENTS.md）
- 产物：`Build & Test` 会上传测试报告与 **未签名 IPA**（侧载/重签名用）

## 功能对照（Web → SwiftUI）

| Web | SwiftUI |
| --- | --- |
| 底部胶囊导航（动态/影视/音乐/我的） | `TabView` 四个 tab，前三个为占位页 |
| 「我的」首页：家族环、近 7 天荣誉条形图、成员卡、四项统计、三个特色入口、家族卡片 | `HomeView` |
| 设置：多家族链接、拖拽排序、当前归属成员 | `SettingsView`（`Form` + `EditButton`） |
| 家族详情：三环、近 7 天总荣誉、资料卡、四项统计、不达标成员 | `FamilyDetailView` |
| 成员数 → 家族成员列表 | `MemberListView` |
| HAR 导入荣誉记录 / 荣誉值记录 / 当天记录（左滑删除） | `HARImporter` + `HARPreviewSheet` + `HonorRecordsView` + `HonorDayView`（`List` 的 `swipeActions`） |
| 成员勋章馆（勋章/乐迷 tab、模块、排行榜、勋章详情、皮肤、皮肤详情） | `MemberMedalFlow` + `MedalsListView` / `ModuleListView` / `RankView` / `MedalDetailView` / `SkinDetailSheet` |
| 巅峰制作人 / 乐迷灯牌 / 星光发电站 统计页 | `FeatureStatView` |
| 卡册、小票 | 按需求删除 |

## 系统控件与实现要点

- **环形进度**：`UIViewRepresentable` 桥接系统 `HKActivityRingView`（HealthKitUI），只把 0…1 的进度换算成 `HKActivitySummary` 的「当前值 / 目标值」，环形样式完全由系统绘制。系统三环固定为「活动（红）/ 锻炼（绿）/ 站立（蓝）」，所以首页的三色家族环最多展示 3 个家族，图例配色与三环顺序一一对应。`HKActivityRingView` 自带深色底片，因此三环与图例放在一块深色圆角卡片里（浅色页面上直接摆会露出一块黑色圆盘）。
- **条形统计图**：系统 Swift Charts（`Chart` + `BarMark`），近 7 天荣誉用「灰色轨道 + 渐变填充」两层 `BarMark` 叠出胶囊柱，不再手绘。
- **「我的」页成员资料行**：恢复原版行为——纯展示，没有箭头、没有导航入口；周榜/月榜/勋章皮肤/已获得奖章四个二级入口才跳转。
- **成员勋章馆**：全屏页右上角提供「关闭」，从二级页面返回根页面后可以直接退出，不会卡在成员详情。

## 结构

```
MedalHall/
  App/          入口、根 TabView、路由
  Models/       家族、成员、勋章、排行、皮肤、荣誉、统计页模型
  Services/     QQ 签名算法、SSR 解析、CGI/页面抓取、HAR 解析、荣誉聚合
  Storage/      UserDefaults 持久化（对应原项目的 localStorage）与应用状态
  ViewModels/   成员勋章/家族详情的加载与派生状态
  Views/        全部 SwiftUI 页面与组件
MedalHallTests/ 逻辑测试（签名向量、SSR、成员/排行/皮肤解析、HAR、荣誉聚合）
MedalHallUITests/ 关键流程 + 无障碍审计
```

## 与原实现的有意差异

1. **不再有 Node 中转**：原 `server.js` 的所有路由（`/api/parse`、`/api/members`、`/api/module`、`/api/medal`、`/api/skins`）改为 App 内直接请求 QQ 音乐接口，签名算法逐字节移植（`QQSigner`）。
2. **皮肤扫描**：原 Web 版用「按 seq 逐个抓 `skin_detail.html`」的方式扫描皮肤，最多 2000 次请求；SwiftUI 版改用同一个上游的 `GetSkinShowList` 翻页接口拉全量（服务端本就有的能力），结果一致但请求数少两个量级。
3. **家族分享图**：原版用 Canvas 拼图后下载；SwiftUI 版用原生 `ShareLink` 分享文本摘要（含家族荣誉、排名、成员数）。
4. **近 7 天条形图**：有 HAR 导入的荣誉记录时按真实数据绘制；没有数据时沿用原版的占位高度（原版即为此实现）。
5. **巅峰制作人/乐迷灯牌/星光发电站**：数据接口未接入，保持原版的「暂无数据」空态。

## 构建与产物

仓库：<https://github.com/Breast-dressing/medal-hall>

最近一次 `Build & Test`（[run 44742507192](https://github.com/Breast-dressing/medal-hall/actions/runs/44742507192)）：

- 工具链：Xcode 27.2（27B52）+ iOS 27.2 SDK；产物 `Info.plist` 里 `DTSDKName = iphoneos27.2`、`MinimumOSVersion = 27.0`
- 测试：40 个测试全部通过（逻辑测试 + UI 关键流程 + 无障碍审计），模拟器 iPhone 18 Pro (iOS 27.2)
- 产物：`MedalHall-unsigned.ipa`（Job artifact `MedalHall-unsigned-ipa`）
- Bundle ID：`com.breastdressing.medalhall`，显示名「勋章馆」
- 截图验证：CI 用 `-demo-data` 启动 App 截 `launch.png`；`MedalHallUITests` 里的 `testDemoPagesRenderAndExit` 会依次进入「我的 → 家族详情 → 成员详情」并留三张截图，测试结束后用 `xcresulttool export attachments` 导出到 `build/test/screenshots`
- 工作区里的截图：`screenshots/01-home.png`、`screenshots/02-family-detail.png`、`screenshots/03-member-detail.png`
- 示例数据只在 `-demo-data` 启动参数下注入，正常启动不受影响

### 怎么装

IPA 是**未签名**的，不能直接双击安装，需要先用你自己的 Apple ID / 证书重签名：

- Sideloadly / AltStore / TrollStore 等工具导入 `MedalHall-unsigned.ipa`
- 或用 `codesign` + 自己的描述文件重签后 `xcrun devicectl device install app`

### 怎么用

打开 App → 右上角齿轮 → 粘贴家族链接（`https://i2.y.qq.com/?family_id=...`）添加家族 → 在「当前归属成员」里选成员并保存。
首页与家族详情会直接请求 QQ 音乐勋章馆接口（签名、SSR 解析都在 App 内完成，不再需要 Node 中转）。

## 本地开发

没有 Mac 也能开发：改完 push，CI 用 Xcode 27.2 在 `xcode-27` 镜像上编译、跑测试并产出未签名 IPA。
