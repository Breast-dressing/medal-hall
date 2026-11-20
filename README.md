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

## 本地开发

没有 Mac 也能开发：改完 push，CI 用 Xcode 27.2 在 `xcode-27` 镜像上编译、跑测试并产出未签名 IPA。
