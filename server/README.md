# RiftDuel 输入中继

Go 服务只负责房间生命周期和转发输入，由 Godot 互联网房间页接入；不模拟、不发送游戏状态、不裁决。协议见 [联机文档](../Docs/network_protocol.md)，验收命令见 [验证与发布](../Docs/verification.md)。

## 本地运行

```powershell
go -C server test ./... -count=1
go -C server run . -listen 127.0.0.1:8080
```

`GET /healthz` 返回 `ok`；WebSocket 路径 `/ws`。只允许 loopback 监听，公网必须由 TLS 反向代理提供有效证书的 WSS，不能跳过证书校验。禁用 WebSocket 压缩，拒绝浏览器 Origin 和 URL 查询参数；面向原生 Godot 客户端。

## 资源与阶段

最多 5 个房间、每房 2 人、20 个连接（包括未握手）。消息最大 32768 字节；输出最多 32 条、128 KiB，写入超时 2 秒。单连接每秒最多 90 条、256 KiB，控制消息最多 10 条；超限结束违规连接。输入最多领先另一连接 120 tick、每批最多 64 条。

握手超时 8 秒、已握手未入房 30 秒、等待房间 10 分钟、加载 30 秒、输入停滞和结束核对 8 秒。超时或退出关闭该房间，告知对方异常结束，不判对方获胜。正常核对后立即释放房间，再玩重新创建。

输入延迟固定 6 tick（30 tick/s 下为 200ms 的本地输入缓冲）。这是初始测试值，不表示实际跨网络时延达标。前 6 tick 输入为空，由客户端填充。

## Ubuntu 部署准备

交叉编译：`GOOS=linux GOARCH=amd64 go build -trimpath -o ../build/riftduel-relay .`（在 server 目录运行）。产物不包含 Go 工具链，服务器不需要安装 Go。

部署前核对地域、带宽额度、试用期、系统架构和域名。部署使用专用非 root 用户、systemd 服务和 loopback 监听；TLS 代理处理公开入口，公网仅开放所需端口。不要开放内部 8080 端口。防火墙变更需明确确认；不要将密码、私钥、证书私钥或邀请凭证粘贴聊天或写入 Git。

IP 证书的 Nginx 配置、续期 service / timer、reload hook 和本机验证入口见 `deploy/README.md`。代理安装时保持停用，正式证书签发前先完成配置验证。

`SIGTERM` 停止接收并关闭连接，对局异常结束；不提供排空到自然结算、重连或房间持久化。备份程序、公开配置与部署文档，临时房间不恢复。每次发布按验证文档执行 Godot WSS、逐 tick 回放与 TLS 检查；两种真实网络和实际容量需独立验收，不能以同机测试替代。
