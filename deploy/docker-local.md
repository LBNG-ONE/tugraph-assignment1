# 部署方式二：本地 Docker 单机部署

> 依据课程 PPT「Docker 命令解析」整理，作为云上方案的对照。
> 前置条件：已安装 Docker / Docker Desktop。

## 1. 拉取镜像

```bash
docker pull tugraph/tugraph-runtime-ubuntu18.04:4.5.0
```

## 2. 启动容器

```bash
docker run -d \
  -v D:\tugraph\data:/mnt \
  -p 7070:7070 \
  -p 7687:7687 \
  -p 9090:9090 \
  --name tugraph_demo \
  tugraph/tugraph-runtime-ubuntu18.04:4.5.0 \
  lgraph_server -d run --enable_plugin true
```

## 3. 命令逐项解析

| 参数 | 含义 |
|---|---|
| `docker run` | 创建并启动一个新容器 |
| `-d` | detached 模式，容器在后台运行，不占用当前终端 |
| `-v D:\tugraph\data:/mnt` | 数据卷挂载。把宿主机目录映射到容器内 `/mnt`。TuGraph 默认把数据库文件、日志、配置放在 `/mnt`，实现**数据持久化**，容器删除后数据不丢失 |
| `-p 7070:7070` | Web 管理界面 + RESTful API。格式为 `宿主机端口:容器端口` |
| `-p 7687:7687` | Bolt 协议端口，供 Java/Python/Go 驱动或 Cypher Shell 连接 |
| `-p 9090:9090` | 监控与 gRPC 服务端口，常用于 Prometheus 指标采集 |
| `tugraph/tugraph-runtime-ubuntu18.04:4.5.0` | 镜像名与版本标签，基于 ubuntu18.04 的 TuGraph 运行时环境，版本 4.5.0 |
| `lgraph_server -d run --enable_plugin true` | 容器启动后执行的命令：`lgraph_server` 是 TuGraph 核心服务程序；`-d run` 以服务模式运行；`--enable_plugin true` 启用 C++/Python 等图计算插件扩展 |

## 4. 端口用途对照

| 端口 | 主要用途 |
|---|---|
| 7070 | Web 管理界面 & RESTful API。浏览器访问 `http://<服务器IP>:7070` 可可视化建库、导入数据、执行 Cypher 查询 |
| 7687 | Bolt 协议端口。供客户端驱动（Java/Python/Go 等）或 Cypher 命令行工具连接，执行图查询与事务操作 |
| 9090 | 监控与 gRPC 服务端口。用于 Prometheus 指标采集、集群内部通信或扩展服务 |

## 5. 登录

浏览器打开 <http://localhost:7070>，用户名 `admin`，密码默认 `73@TuGraph`。

## 6. 常用运维命令

```bash
docker ps                 # 查看运行中的容器
docker images             # 核对本地镜像版本号
docker logs -f tugraph_demo
docker stop tugraph_demo
docker start tugraph_demo
docker restart tugraph_demo
docker exec -it tugraph_demo bash
```

## 7. 踩坑记录与解决方案

| 问题 | 原因 | 解决方案 |
|---|---|---|
| 重启 docker 后断连 | 容器内 TuGraph 服务未随之恢复 | 在宿主机 `sudo docker exec -it tugraph_demo bash` 进入镜像，再执行 `lgraph_server -d restart` |
| 端口 7070/7687/9090 被占用 | 之前 `docker run` 的容器仍占用该端口，或被 neo4j、极域课堂教师端等软件占用 | 优先 `docker restart` 复用容器而不是删掉重开；确属冲突则改映射端口，如 `-p 7171:7070`，浏览器访问 `localhost:7171` |
| `docker run` 时又重新下载镜像 | 镜像版本号或名称写错，本地找不到就自动拉取 | `Ctrl+C` 停止拉取，用 `docker images` 核对本地镜像名与版本号 |
| 镜像拉取太慢 | 默认 Docker Hub 源速度差 | 更换 Docker 镜像源（PPT 第 13 页） |
| 容器内 python3 路径有误 | PATH 未包含 python3 | 用 `which` / `find` 定位并建立软链接、修改 `PATH`；无 `which/find` 时用 `ls -l /usr/bin/python* /usr/local/bin/python* 2>/dev/null` |
| 缺少 cython | 未安装 | `pip3 install cython` |
| 缺少 C++ 编译器或版本不适配 | 镜像内未装或版本过低 | `yum` 安装（必要时换 yum 源） |
| 找不到 `liblgraph.so` / `No module named 'lgraph_python_api'` | 动态库路径不在 Python 搜索路径 | 建立路径软链接，并把路径加入 Python 搜索环境（`LD_LIBRARY_PATH` / `sys.path`） |
