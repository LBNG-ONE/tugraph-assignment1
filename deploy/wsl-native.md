# 部署方式三：WSL1 + 官方 deb 原生安装（本实验采用）

> 适用场景：Windows 机器无法安装 Docker Desktop（无管理员权限），或 WSL2 因 hypervisor 冲突无法启动。
> **核心思路**：TuGraph 官方发布的 `.deb` 自带全部运行库、不声明任何外部依赖，因此只要能提供一个 Linux 兼容层即可原生运行，**完全不需要 Docker，也不需要 hypervisor**。

## 0. 环境

| 项 | 值 |
|---|---|
| 宿主机 | Windows 11 家庭中文版 |
| Linux 层 | WSL1 + Ubuntu 20.04.5 LTS（`ubuntu-base` 最小根文件系统） |
| TuGraph | 4.5.2 社区版，`tugraph-4.5.2-1.x86_64.deb` |
| 发行版磁盘位置 | `D:\...\_wsl\UbuntuTugraph`（不占 C 盘） |

## 1. 启用 WSL 功能（管理员）

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
# 重启电脑生效
```

## 2. 下载 Ubuntu 最小根文件系统

```powershell
curl.exe -L -o ubuntu-base-20.04.5-base-amd64.tar.gz `
  https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.5-base-amd64.tar.gz
```

约 26.5 MB，清华镜像实测 9 MB/s。

## 3. 以 WSL1 导入发行版

```powershell
wsl --import UbuntuTugraph "D:\...\_wsl\UbuntuTugraph" `
  "D:\...\_wsl\ubuntu-base-20.04.5-base-amd64.tar.gz" --version 1

wsl -d UbuntuTugraph -- uname -a
# Linux <host> 4.4.0-26100-Microsoft ... x86_64 GNU/Linux
```

> **为什么用 `--version 1`**
> WSL2 需要一个 Hyper-V hypervisor。若机器上装了 VMware Workstation、EasyAntiCheat 等与 hypervisor 冲突的软件，
> 创建发行版会报 `HCS_E_HYPERV_NOT_INSTALLED`（即使 `VirtualMachinePlatform` 已启用、`hypervisorlaunchtype` 已为 `Auto`）。
> WSL1 是系统调用翻译层，**不需要 hypervisor**，可直接绕开。
> 另外 WSL1 与 Windows 共享 localhost 网络栈，浏览器访问 `http://localhost:7070` 无需端口转发。

## 4. 安装依赖

极简 rootfs 缺 CA 证书，HTTPS 源不可用，因此先用 **HTTP** 源：

```bash
cat > /etc/apt/sources.list <<'EOF'
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted universe multiverse
EOF

apt-get update
apt-get install -y ca-certificates libgomp1 libgfortran5
```

## 5. 安装 TuGraph

```bash
dpkg -i /mnt/d/.../tugraph-4.5.2-1.x86_64.deb
# Setting up tugraph (4.5.2)
```

## 6. 修复动态库

deb 把自有库装在 `/usr/local/lib64/lgraph`，不在默认搜索路径：

```bash
echo "/usr/local/lib64/lgraph" > /etc/ld.so.conf.d/lgraph.conf
ldconfig
ldd /usr/local/bin/lgraph_server | grep "not found"
# libgomp.so.1 => not found
# libgfortran.so.4 => not found
```

`libgomp1` 提供 `libgomp.so.1`；但 `libvsag.so` 由 **GCC 7** 编译，需要带 `GFORTRAN_7` 符号的 `libgfortran.so.4`，
而 Ubuntu 20.04 只有 GCC 10 的 `libgfortran.so.5`（软链过去会报 `version 'GFORTRAN_7' not found`）。
正确做法是装 Ubuntu 18.04 池里的包：

```bash
curl -L -o libgfortran4.deb \
  http://mirrors.tuna.tsinghua.edu.cn/ubuntu/pool/main/g/gcc-7/libgfortran4_7.5.0-3ubuntu1~18.04_amd64.deb
dpkg -i libgfortran4.deb
ldconfig
ldd /usr/local/bin/lgraph_server | grep "not found" || echo ALL_LIBS_OK
```

## 7. 启动服务

首次启动用 `--reset_admin_password true` 把 admin 密码重置为 `73@TuGraph`，
**该参数执行完会让进程主动退出**（日志：`Reset admin password successfully, server will exit now`），属预期行为。

```bash
mkdir -p /var/lib/lgraph/data /var/log/lgraph

# 第一次：重置密码（跑完自动退出）
lgraph_server -d run --reset_admin_password true --log_dir ""
```

```bash
# 第二次：正式常驻运行
nohup lgraph_server -d run \
  --directory /var/lib/lgraph/data \
  --web /usr/local/share/lgraph/browser-resource \
  --port 7070 \
  --log_dir /var/log/lgraph \
  --verbose 1 > /var/log/lgraph/stdout.log 2>&1 &
```

成功日志：

```
*                  TuGraph Graph Database v4.5.2                     *
  HTTP port:   7070    RPC port:   9090    bolt port:   7687
[INFO] Listening for RPC on port 9090
[INFO] Listening for REST on port 7070
[INFO] bolt server run
[INFO] Server started.
```

## 8. 登录

浏览器打开 <http://localhost:7070>：

| 字段 | 值 |
|---|---|
| 数据库地址 | `127.0.0.1:7687` |
| 账号 | `admin` |
| 密码 | `73@TuGraph` |

首次登录会提示"默认密码存在安全风险"，点「跳过」即可进入控制台。

## 9. 踩坑清单

| 现象 | 原因 | 解决 |
|---|---|---|
| `HCS_E_HYPERV_NOT_INSTALLED` | VMware / EasyAntiCheat 等与 hypervisor 冲突 | 改用 WSL1（`--version 1`） |
| `E: The repository ... does not have a Release file` / `No system certificates available` | 极简 rootfs 无 CA 证书 | apt 源改 HTTP，装 `ca-certificates` |
| rootfs 内没有 `curl` / `wget` | 未安装 | 用 `apt-get install wget`，或从 Windows 侧下载后经 `/mnt/d` 传入 |
| `liblgraph.so` / `libvsag.so` not found | 库目录不在搜索路径 | 写 `/etc/ld.so.conf.d/lgraph.conf` 后 `ldconfig` |
| `version 'GFORTRAN_7' not found` | `libgfortran5` 不提供 GCC7 版本符号 | 安装 Ubuntu 18.04 的 `libgfortran4` |
| 启动后立即 `Server shutdown` | `--reset_admin_password true` 的语义是重置后退出 | 去掉该参数再启动 |
| 查询报 `ast_expr_evaluator.cpp:480` | 建标签时字段类型写成裸标识符 | 类型用带引号字符串 `'INT64'` |
| 查询"成功"但结果空白 | 结果区默认在「点边视图」画布 | 切到「表格文本」标签 |
