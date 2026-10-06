# Ubuntu IP 证书部署

配置面向单台新 Ubuntu Server x86_64：Go 服务绑定 `127.0.0.1:8080`，Nginx 终止 TLS、转发 `/ws`，HTTP 仅提供 ACME 验证路径。模板中的 `PUBLIC_IP` 替换为实际公网 IPv4。

## 软件与目录

- Nginx、python3-venv 来自 Ubuntu 官方源；安装前 mask `nginx.service`，避免安装过程自动开放 80 端口。
- Certbot 5.4 以上支持 IP webroot 验证；安装到独立 `/opt/riftduel-certbot` 环境，不替换系统 Python。
- Go 程序：`/opt/riftduel/riftduel-relay`，用户 `riftduel`，无登录 shell；使用上一层的 systemd 示例。
- ACME webroot：`/var/lib/riftduel/acme`；配置先放在独立 staging 目录，确认公网步骤后启用。
- 证书名称固定 `riftduel-ip`，私钥留在 `/etc/letsencrypt`，不上传、不写日志、不提交 Git。

## 公网启用顺序

1. 确认试用期、流量额度，以及允许这台实例接受公网 TCP 80、443。8080 保持本机监听。检查腾讯云防火墙规则，只新增所需端口，不修改 SSH。
2. 按用户授权接受 Let's Encrypt 订阅协议，确认 ACME HTTP-01 路径可从公网访问。HTTP bootstrap 配置不转发游戏。
3. 先用隔离配置目录验证 staging 签发；再签发正式证书，正式客户端不使用 staging 或本地测试证书。

```sh
/opt/riftduel-certbot/bin/certbot certonly \
  --webroot --webroot-path /var/lib/riftduel/acme \
  --ip-address PUBLIC_IP --required-profile shortlived \
  --cert-name riftduel-ip --non-interactive \
  --agree-tos --register-unsafely-without-email
```

不提供邮箱时无法依靠邮件接收账号消息；本地检查证书有效期与续期服务结果。`--agree-tos` 必须先获用户授权，不将准备部署当成已经授权接受协议。

4. 部署 TLS 配置，`nginx -t` 通过后 reload；公网客户端用系统信任库核对 IP SAN、链和有效期，不跳过验证。
5. 安装续期 service、timer 与 root 所有的 reload hook。先执行 `certbot renew --cert-name riftduel-ip --dry-run`，通过后 enable timer。6 天证书每日检查两次。timer 只负责续期，不创建 Codex 监控。
6. 通过真正的 WSS 驱动完成双方流程；Godot 接入另做逐 tick 模拟回放与两种网络验收。

## 验证与运维

准备阶段在 loopback 上运行独立 Nginx，使用仅供测试的 IP SAN 证书及显式信任的测试证书检查 TLS；测试目录不得作为正式证书目录。检查 healthz、WebSocket 101 升级、Origin 拒绝、HTTP 非 ACME 路径 404。临时服务退出后确认释放监听端口。

本机验证入口：把 `verify-local.sh` 与两份 Nginx 模板放到服务器 relay 程序下一级目录，运行 `bash verify-local.sh`。要求父目录存在 `riftduel-relay`，端口 8080、8081、8443 空闲；脚本成功返回 0，失败返回非零，并在 EXIT 时清理临时进程。测试证书、私钥和日志仅保留在该服务器的私有 `verify-*` 目录中。另用 `systemd-analyze verify` 检查 unit、`pip check` 检查 Certbot 环境；没有正式证书时不执行实际续期。

Nginx access log 关闭，应用不记录消息、输入或凭证。错误日志使用 Ubuntu 自带 logrotate；服务使用 journal，排障只导出必要字段。`systemctl status riftduel-relay riftduel-cert-renew.timer` 与 `journalctl -u riftduel-cert-renew.service` 查看运行和续期结果。定期检查证书有效期；未授权创建额外定期告警。

停止公开服务：先禁用公网入口，再停止 Nginx 和 relay。回退前保存旧程序与公开配置，替换后本机 healthz 检查并核对构建指纹；升级和 SIGTERM 会断开对局，不承诺自然排空或重连。证书、私钥和 ACME 账号仅在服务器权限受控目录保留；备份策略另行授权，不复制到聊天或仓库。

参考：[IP 证书与 Certbot](https://letsencrypt.org/2026/03/11/shorter-certs-certbot)、[WebSocket 代理](https://nginx.org/en/docs/http/websocket.html)。
