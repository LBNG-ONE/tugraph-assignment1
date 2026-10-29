# 实验一 · 图数据库 TuGraph 实践

> 专业综合实践 · 作业 1
> 图数据库 **TuGraph**：部署启动 → 图建模 → 数据导入 → 增删改查 → 自定义聚合查询

---

## 一、实验任务与完成情况

| # | 任务 | 分值 | 完成情况 | 报告位置 |
|---|---|---|---|---|
| 1 | 成功启动 TuGraph 平台，文字描述安装/部署步骤，展示系统登录截图 | 4 | ✅ | [4.1 部署与启动](docs/实验一报告.md#41-任务一tugraph-平台的部署与启动4-分) |
| 2 | 模型建立、数据导入、增删改查，截图展示运行结果 | 4 | ✅ | [4.2 图建模、数据导入与增删改查](docs/实验一报告.md#42-任务二图建模数据导入与增删改查4-分) |
| 3 | 自己设计一个聚合查询的例子，截图展示运行结果 | 4 | ✅ | [4.3 自定义聚合查询设计](docs/实验一报告.md#43-任务三自定义聚合查询设计4-分) |
| 4 | 通过 GitHub / CSDN 提交报告，把链接放到学习通回答中 | 3 | ✅ | 本仓库 |

📄 **完整实验报告：[`docs/实验一报告.md`](docs/实验一报告.md)**

---

## 二、仓库结构

```
tugraph-assignment1/
├── README.md                     本文件：任务清单与快速导航
├── docs/
│   └── 实验一报告.md              完整实验报告（含全部截图）
├── data/                         原始数据集（UTF-8 CSV）
│   ├── person.csv                37 位人物顶点
│   ├── movie.csv                 30 部影片顶点
│   ├── direct.csv                执导关系边（30 条）
│   ├── acted_in.csv              出演关系边（47 条）
│   └── produce.csv               制片关系边（6 条）
├── cypher/                       全部 Cypher 脚本
│   ├── 01_schema.cql             建标签 / 建索引
│   ├── 02_crud.cql               增删改查完整演示
│   └── 03_aggregate.cql          自定义聚合查询（核心）
├── scripts/                      批量导入与查询脚本
│   ├── import_via_rest.ps1       通过 REST 接口批量导入 CSV（本实验采用）
│   ├── import_data.py            通过 Bolt 协议导入（备选方案）
│   ├── run_queries.py            批量执行聚合查询并打印表格
│   └── requirements.txt
├── deploy/                       部署方案文档
│   ├── wsl-native.md             方式一：WSL1 + 官方 deb 原生安装（本实验采用）
│   ├── aliyun-computenest.md     方式二：阿里云计算巢免费试用（备用）
│   └── docker-local.md           方式三：本地 Docker 单机部署
└── screenshots/                  24 张实验运行截图
```

---

## 三、图模型设计

采用**属性图模型**（Property Graph），由顶点、边、属性三要素组成。聚焦电影领域，共 2 个顶点标签、3 个边标签。

### 顶点标签

| 标签 | 含义 | 字段 | 类型 | 说明 |
|---|---|---|---|---|
| `person` | 人物（导演/演员/制片） | `id` | INT64 | 主键 |
| | | `name` | STRING | 姓名，建索引 |
| | | `born` | INT32 | 出生年份 |
| | | `country` | STRING | 国籍 |
| `movie` | 影片 | `id` | INT64 | 主键 |
| | | `title` | STRING | 片名，建索引 |
| | | `release_year` | INT32 | 上映年份 |
| | | `rating` | DOUBLE | 评分（0~10） |
| | | `duration` | INT32 | 片长（分钟） |
| | | `country` | STRING | 出品国 |

### 边标签

| 标签 | 方向 | 含义 | edge_constraints |
|---|---|---|---|
| `direct` | person → movie | 执导 | `[["person","movie"]]` |
| `acted_in` | person → movie | 出演 | `[["person","movie"]]` |
| `produce` | person → movie | 制片 | `[["person","movie"]]` |

```
   ┌──────────┐   direct     ┌─────────┐
   │  person  │─────────────▶│  movie  │
   │          │  acted_in    │         │
   │          │─────────────▶│         │
   │          │  produce     │         │
   │          │─────────────▶│         │
   └──────────┘              └─────────┘
    37 个顶点                 30 个顶点
                3 类边 / 83 条
```

---

## 四、数据集说明

自建电影领域数据集，覆盖 1957–2023 年的 30 部影片与 37 位人物（导演 10 位、演员 23 位、制片 4 位，部分身兼多职）。

| 文件 | 行数 | 内容 |
|---|---|---|
| `data/person.csv` | 37 | 人物 |
| `data/movie.csv` | 30 | 影片 |
| `data/direct.csv` | 30 | 执导关系 |
| `data/acted_in.csv` | 47 | 出演关系 |
| `data/produce.csv` | 6 | 制片关系 |

导入后预期规模：**67 个顶点 / 83 条边**。

---

## 五、快速复现

### 1. 启动 TuGraph

见 [`deploy/wsl-native.md`](deploy/wsl-native.md)（WSL1 + 官方 deb，**本实验采用**）、[`deploy/aliyun-computenest.md`](deploy/aliyun-computenest.md)（云上备用）或 [`deploy/docker-local.md`](deploy/docker-local.md)（本地 Docker）。

### 2. 建模型

在 Web 界面「图构建」中可视化建表，或在「图查询」里直接执行：

```bash
cypher/01_schema.cql     # 类型要写成带引号的字符串，如 'INT64'
```

### 3. 导入数据

**方式 A（REST 接口，本实验采用）**：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/import_via_rest.ps1 `
  -Base http://localhost:7070 -Graph lab1_movie -DataDir .\data
```

**方式 B（Web 界面）**：图项目 → 数据导入 → 分别选择 5 个 CSV，映射标签与列名。

**方式 C（Bolt 脚本）**：

```bash
pip install "neo4j>=5,<6"
python scripts/import_data.py --uri bolt://<host>:7687 --user admin --password <pwd> --clean
```

### 4. 增删改查

```bash
cypher/02_crud.cql
```

### 5. 聚合查询

```bash
cypher/03_aggregate.cql
# 或
python scripts/run_queries.py --uri bolt://<host>:7687 --user admin --password <pwd>
```

---

## 六、核心聚合查询

**业务问题**：哪位导演的作品**平均口碑最高**？为避免"一片成名"造成的噪声，要求导演作品数 ≥ 2。

```cypher
MATCH (d:person)-[:direct]->(m:movie)
WITH d, COUNT(m) AS movieCount, AVG(m.rating) AS avgRating
WHERE movieCount >= 2
RETURN d.name AS 导演, movieCount AS 作品数, avgRating AS 平均评分
ORDER BY avgRating DESC, movieCount DESC
LIMIT 10
```

设计要点：

1. Cypher **没有 `GROUP BY`**，分组由聚合函数隐式触发——`WITH` 中 `d` 是非聚合表达式，自动成为分组键；
2. `WITH` 实现**多阶段查询**：先按导演聚合，再在外层用 `WHERE` 对聚合结果做过滤，等价于 SQL 的 `HAVING COUNT(*) >= 2`；
3. `COUNT(DISTINCT a)` 去重，避免同一演员因合作多部影片被重复计数（见 Q2）。

完整 5 组聚合查询与结果分析见[报告 4.3 节](docs/实验一报告.md#43-任务三自定义聚合查询设计4-分)。

---

## 七、参考资料

- TuGraph 官网：<https://tugraph.tech/?lang=zh-CN>
- TuGraph 开源仓库：<https://github.com/TuGraph-family/tugraph-db>
- Cypher 接口文档：<https://tugraph-db.readthedocs.io/zh-cn/v3.5.0/5.developer-manual/6.interface/1.cypher.html>
- Bolt 客户端文档：<https://github.com/TuGraph-family/tugraph-db/blob/master/docs/zh-CN/source/7.client-tools/5.bolt-client.md>
- 图数据库基础：<https://blog.csdn.net/cacique111/article/details/126842771>

---

## 八、环境信息

| 项 | 值 |
|---|---|
| 宿主机 | Windows 11 家庭中文版（i7-13700H / 16 GB / NVMe） |
| Linux 层 | WSL1 + Ubuntu 20.04.5 LTS（发行版磁盘在 D 盘） |
| TuGraph 版本 | 4.5.2 社区版，官方 `.deb` 原生安装（575.7 MB，自带运行库） |
| 部署方式 | WSL1 + 官方 deb（**不依赖 Docker**） |
| 子图 | `lab1_movie` |
| Web 端口 | 7070 |
| Bolt 端口 | 7687 |
| RPC 端口 | 9090 |
| 登录 | `admin` / `73@TuGraph`（Bolt 地址 `127.0.0.1:7687`） |
| 浏览器 | Chrome 156 |
| Bolt 驱动 | neo4j Python Driver 5.28.8 |
