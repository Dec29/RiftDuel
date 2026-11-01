# RiftDuel 输入中继

Go 服务只负责房间生命周期和转发输入，由 Godot 互联网房间页接入；不模拟、不发送游戏状态、不裁决。协议见 [联机文档](../Docs/network_protocol.md)，验收命令见 [验证与发布](../Docs/verification.md)。

## 本地运行

```powershell
go -C server test ./... -count=1
go -C server run . -listen 127.0.0.1:8080
```

`GET /healthz` 返回 `ok`；WebSocket 路径 `/ws`。只允许 loopback 监听，公网必须由 TLS 反向代理提供有效证书的 WSS，不能跳过证书校验。禁用 WebSocket 压缩，拒绝浏览器 Origin 和 URL 查询参数；面向原生 Godot 客户端。

互联网消息使用 `v=7`，拒绝 v1 至 v6。创建事件额外字段仅为 `room_id,code,side,rules,revision`，加入请求仅含 `code`，不接受 `invite` 或其他多余字段。配对码为 crypto/rand 生成的六位数字（允许前导零），活动房间之间不重码；仅相同构建能加入尚未开局的空位，未知或满房拒绝。房间和对局标识仍为 128 bit；规则包含score／single、1至30分钟与固定1至9局，只有房主可在系列开始前修改；准备、编队和开始绑定revision，load冻结rules和round；输入九标量保持。局间返回屏障触发下一局，末局返回后保留原房间并解锁。

## 资源与阶段

最多 5 个房间、每房 2 人、20 个连接（包括未握手）。消息最大 32768 字节；输出最多 32 条、128 KiB，写入超时 2 秒。单连接每秒最多 90 条、256 KiB，禁选控制消息最多60条、其他控制消息最多 10 条；超限结束违规连接。输入最多领先另一连接 120 tick、每批最多 64 条。

握手超时 8 秒、已握手未入房 30 秒、等待房间 10 分钟、加载 30 秒、输入停滞和结束核对 8 秒。超时或退出关闭该房间，告知对方异常结束，不判对方获胜。正常核对后保留房间，等待双方return_room；双方返回后重置准备／加载／结束／输入计数，保留配对码和连接，下一局使用新match_id。结算返回及准备等待均最多10分钟，任一方退出或断线才释放房间。

输入延迟固定 6 tick（当前 0.75 倍速下约 267ms 的本地输入缓冲），不代表实际跨网络时延。前 6 tick 输入为空，由客户端填充。

每条指令固定为九标量 `[tick,kind,operator_id,unit_id,x,y,skill_index,facing,item_kind]`；拒绝八字段旧行、缺失或多余字段。DEPLOY／SKILL／RETREAT 的 kind 为 0／1／2，item_kind 必须为 -1。USE_ITEM 的 kind 为 3，operator_id 为空，unit_id 和 skill_index 为 -1，坐标在 21×11 内；item_kind 为 0 起重机、1 高台、2 轰隆隆，起重机 facing 为 0..3，其余为 -1。只校验格式并原样转发，库存、合法落格、费用、效果及单位归属由客户端验证。

现行内容白名单为104名普通干员与23类召唤物，共127个精确ID；DEPLOY允许白名单ID，COPY（kind=4）仅允许104个普通干员ID，明确排除全部23个召唤物。COPY行unit_id为非负整数、x/y=0、skill_index/item_kind=-1、facing=0..3；服务端不检查复制窗口或模拟单位是否存在。关闭禁选时编队只校验ID格式与技能索引0..2并转发；开启时校验普通ID与对应技能数，战斗归属仍由客户端资源校验，不把服务端名单当战斗裁决。

## Ubuntu 部署准备

交叉编译：`GOOS=linux GOARCH=amd64 go build -trimpath -o ../build/riftduel-relay .`（在 server 目录运行）。产物不包含 Go 工具链，服务器不需要安装 Go。

部署前核对地域、带宽额度、试用期、系统架构和域名。部署使用专用非 root 用户、systemd 服务和 loopback 监听；TLS 代理处理公开入口，公网仅开放所需端口。不要开放内部 8080 端口。防火墙变更需明确确认；不要将密码、私钥、证书私钥或邀请凭证粘贴聊天或写入 Git。

IP 证书的 Nginx 配置、续期 service / timer、reload hook 和本机验证入口见 `deploy/README.md`。代理安装时保持停用，正式证书签发前先完成配置验证。

`SIGTERM` 停止接收并关闭连接，对局异常结束；不提供排空到自然结算、重连或房间持久化。备份程序、公开配置与部署文档，临时房间不恢复。每次发布按验证文档执行 Godot WSS、逐 tick 回放与 TLS 检查；两种真实网络和实际容量需独立验收，不能以同机测试替代。

编队squad必须带等长operators和skills，skills各项为0至2的JSON整数；中继校验格式与阶段，禁选开启时另核对普通ID与实际技能数；客户端始终校验资源与最终配置。本地候选协议升级不等于生产服务已部署。

复制使用 kind=4 的九字段输入，目标只允许精确普通可编队 ID、禁止召唤物，facing 为0至3；本方编队、复制窗口及单位状态留给客户端模拟验证，中继仅转发输入。见 Docs/network_protocol.md。


多人默认开启赛前禁选，五阶段和20／100／20／100／30秒由中继墙钟协调；只广播公开BAN与阶段结果，暂存PICK／技能不外发。中继以固定104名普通干员及实际技能数校验禁选控制，名单一致性由tools/test_resource_validation.gd核对。最终12人配置仅用于本场系列，末局返回后清禁选；取消返回原房间。关闭禁选沿用自由编队。消息和同步边界见Docs/network_protocol.md；新版客户端需要v8中继，本地验证不代表生产部署。
