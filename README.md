# RiftDuel（逐界争锋）

Godot 4.7 + GDScript 的 Windows 双人 PvP 推球 Demo。一百零四名普通干员已按原作实装各自全部技能、特性、天赋和战斗骨骼；支持单人镜像 AI、LAN、WSS 房间、战术道具、推拉位移、编队、设置和结算。战斗为 0.75 倍速，正常有效现实时间 5 分钟，正中加时最多 1 分钟。

## 运行与存档

用 Godot 4.7.2 导入 project.godot。发布使用 build/Demo/RiftDuel 完整文件夹或同级 ZIP，保留 EXE、PCK、Bridge DLL、addons 提供器和 licenses；.sha256 核对压缩包。联机双方使用相同包，默认互联网中继 wss://114.132.252.252/ws，六位配对码加入；LAN 在房间选项栏切换。

单人模式先进入对局准备，默认限时积分，也可选择单球决胜与每局时长；单人和多人准备页均可直接调整编队，房内编辑会先取消本方准备，保留连接与配对码，返回后重新准备交换新名单。

多人房间默认开启赛前禁选：双方各禁3人、各选6人、各禁2人、各选6人，再配置技能；双方可选同一干员，禁用全局去重，次轮不能禁已选干员。禁用每轮20秒、选人每轮100秒、技能30秒，双方确认可提前进入下一阶段；一场固定局数共用一次禁选，限时积分进球不重选。可由房主关闭，沿用自由编队。

一支自由编队携带 1–12 名干员，各选一个技能；编辑可空队，进入对局前须至少一人。编队与设置分别保存为 user://squad.cfg、user://preferences.cfg；Windows 默认位于 `%APPDATA%/Godot/app_userdata/RiftDuel/`，不在 build 中。

发布客户端启动时异步检查同一 GitHub 仓库的签名更新；设置→更新可手动检查、下载并重启安装。只下载有变化的文件或适配本地版本的差分，校验后还原完整 PCK，联机仍要求相同构建。检查失败可继续游戏，安装失败恢复旧文件；编队和设置存档保留。同目录 `RiftDuelUpdater.exe` 可恢复中断的安装并启动游戏；发布流程见 [tools/updater/README.md](tools/updater/README.md)。

## 工程结构

| 路径 | 职责与主要入口 |
|---|---|
| project.godot、view/start_menu.tscn | 启动入口；Config／OperatorDB 提供数据，ClientUpdates 管理本地更新 |
| main.gd／main.tscn | 对局装配、固定调度、收取双方指令后调用模拟 |
| lobby.gd／lobby.tscn、view/draft_view.gd | 房间与赛前禁选流程，将会话交给对局 |
| squad.gd、preferences.gd | 编队和设置的本地存档边界 |
| sim/ | MatchState 持有状态并调度；command／attack／status／aura／tactical_rules 执行各阶段，effects 按跨阶段机制组织 |
| decision/ | LocalInput／AIInput 只读模拟、生成 InputCommand |
| net/ | 编解码、ENet／WebSocket 会话、输入 tick 对齐；不传状态 |
| view/ | MatchView 统一输入与 HUD；BoardProjection、DeployInteraction、BattleRenderer、UnitInfo 分别负责投影、部署、场景绘制和信息 |
| data/、resources/ | 资源校验由CSV导入与运行加载共用；OperatorDB登记内容，Config提供平衡参数；attack_action_data保存依赖模拟状态的动作查询 |
| import/ | 规范化 CSV 导入源，游戏不直接读取 |
| assets/、addons/spine_bridge/ | 美术源／运行骨骼、来源清单、原生库与许可文件 |
| server/ | 独立 Go 房间和输入中继，部署模板在 server/deploy |
| tools/ | 可复现测试、导入和构建；正式包排除，QA 导出保留 |
| build/、.godot/、.ai/ | 当前交付包、引擎缓存／验收产物、本地临时协作，均不提交 |

调用链：界面 → LocalInput → 单人或网络收齐指令 → MatchState.step；视图只读模拟。AI 使用相同指令接口，中继只转发。CSV 经 import_operators.gd 生成 .tres；骨架源经视觉导入工具生成 .res，再由视图装载。

## 验证

中继运行说明见 [server/README.md](server/README.md)。以下是基础套件与构建入口：

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify.ps1
go -C server test ./... -count=1
powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1
```

返回码和实际证据决定验收结论；同机自动化不替代跨设备真人对局及平衡试玩。干员资料参考 PRTS，第三方模型与运行库按各自许可使用，公开素材分发另行确认；本项目不代授角色／素材许可。


多人房间中加入者准备后，房主直接点击“开始对局”；房主无需单独准备。客户端在开始时校验并发送房主当前编队，沿用有序控制消息与加载屏障；开局前仍可调整编队，取消BP后回到原房间。
