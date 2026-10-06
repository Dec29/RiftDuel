# RiftDuel（逐界争锋）

Godot 4.7 + GDScript的Windows双人PvP推球原型。部署八名干员，攻击球累积推力，推入对方整条底线获胜。正常5分钟，正中加时1分钟；包含单人AI、LAN房间／配对码、WSS互联网房间、设置与结算。

## 运行

用Godot 4.7.2导入project.godot并运行。Windows发布包解压后同时保留RiftDuel.exe与RiftDuel.pck。联机双方必须使用同一ZIP；默认中继wss://134.175.45.75/ws，创建者分享一次性邀请码。自定义WSS与己方球门左右位置在设置中修改。编队入口未开放。

## 工程

sim/是纯数据状态真源，decision/产生指令，net/只同步输入，view/只读渲染，server/是独立Go中继。resources/中的.tres为运行数据；import/operators.csv为规范化导入源，外部原始资料不随源码快照分发。资源、字段、玩法分别见[数据契约](Docs/data_contract.md)与[设计](Docs/GDD.md)。

| 文档 | 用途 |
|---|---|
| [现行设计](Docs/GDD.md) | 规则、PoC验收边界、未定项 |
| [数据契约](Docs/data_contract.md)、[被动](Docs/passives.md) | 字段／枚举／公式、干员机制 |
| [联机协议](Docs/network_protocol.md) | LAN／WSS输入同步与安全边界 |
| [视觉规范](Docs/visual_spec.md) | 配色、布局、交互 |
| [编码规范](Docs/coding_standards.md) | 实现约束 |
| [验证与发布](Docs/verification.md) | 环境、回归、导出、人工验收 |
| [中继](server/README.md) | Go运行及服务器部署 |

## 验证与构建

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify.ps1
go -C server test ./... -count=1
powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1
```

预期返回0；Windows ZIP在build/生成。自动化不替代两设备／两网络真人验收与平衡试玩。Demo范围另行定义。

## 来源与使用边界

干员数值／机制参考[PRTS](https://prts.wiki/)，地图素材来源与再分发许可须单独核对。此仓库不通过代码许可证授权第三方角色／素材，未设置开源许可证；不要假定可商用或公开再分发。
