# Windows 客户端更新器

用于 Dec29/RiftDuel Release 的签名更新。客户端设置→更新可检查、下载、重启安装；发布客户端启动后异步检查，网络失败不阻止游戏。源码运行不安装更新。

更新器仅使用Go标准库（Go1.25+），无第三方差分依赖。`go test ./... -count=1`验证签名、路径、差分、HTTP、安装回退、文件占用和恢复。`tools/test_client_updates.gd`验证实际设置界面，`tools/test_settings.gd`验证设置调用链。

`RiftDuelUpdater.exe`与游戏同目录。双击更新器也可恢复未完成事务并启动游戏。游戏通过临时副本启动apply，等待游戏进程退出后安装；备份校验、逐文件事务和新菜单启动确认通过后才删除临时备份。正常启动入口RiftDuel.exe保留。硬中断后若游戏无法直接打开，运行同目录更新器恢复。

## 生成发布

1. 修改`client_version.json`的单调递增版本号（M编号）。先运行相关源码验证。
2. `tools/build_windows.ps1`生成完整包并构建更新器；可通过`RIFTDUEL_GO_BIN`指定已有Go编译器。
3. 使用原发布的真实文件夹作为`--base`。不能从旧Git提交重新导出并假定字节相同。可用逗号分隔多个保留的基线目录。
4. 从新输出目录生成更新附件：

```
RiftDuelUpdater.exe release --install-dir <新完整文件夹> --output <忽略的附件目录> --base <旧发布文件夹> --key <本地私钥> --version <版本号> --tag <Release标签> --notes <更新内容>
```

`release`会生成逐文件完整gzip、较小时才保留的差分、签名`update-manifest.json`以及仅供审查的`release-audit.json`；每份差分都实际重建并校验目标SHA。生成器会规范化新目录的`client_version.json`，因此完整ZIP要在生成附件后重新组装、校验。许可证与来源声明和正常完整包保持一致。

5. 验证同一PCK、独立EXE、旧版本实际安装重启与失败回退；完整包与差分得到的PCK必须字节一致。完成验证才提交。
6. 获准发布后，在同一个Release上传完整ZIP、SHA、`update-manifest.json`及清单引用的所有附件；`release-audit.json`不需要上传。先建draft并上传齐全，最后发布，避免客户端看到缺失附件。预发布也会检测，版本由签名清单的整数决定，不依赖GitHub/latest；没有签名清单的旧Release不会误报为可自动更新。

## 签名与安装边界

- 公钥固定于`public_key.go`，私钥不得提交或打包。首套密钥已生成，不再运行keygen覆盖；本地签名私钥由发布维护者保管。丢失后不能用新钥静默接续现有客户端。
- 清单绑定版本、标签、路径、长度和SHA256；独立更新器验证Ed25519签名。只从固定GitHub仓库下载，无令牌或任意服务器命令。
- 差分使用内容定义分块的copy/literal流并gzip压缩；只有源SHA匹配才选差分，否则下载该文件的完整gzip。最终重建文件、安装文件都验证目标摘要；没有叠加PCK，不改变现有联机PCK指纹规则。
- EXE、PCK、更新器、Spine运行依赖和许可证为允许安装范围；拒绝存档、路径穿越和安装目录外的符号链接。`user://squad.cfg`与preferences不在清单中。
- 更新下载在用户数据目录，安装事务只在当前安装目录`.riftduel-update`。发布文件夹需可写；不请求提权。系统防护、目录权限或文件占用会报错并保留原版本。
- 不把签名私钥、测试清单、假版本、测试签名公钥、开发者路径或下载中的临时产物放入正式包。不要将本地QA签名清单发布为正式新版本。
