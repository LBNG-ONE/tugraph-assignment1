# 实验一 · 图数据库 TuGraph 实践

> 专业综合实践 · 作业 1
> 图数据库 **TuGraph**：部署启动 → 图建模 → 数据导入 → 增删改查 → 自定义聚合查询

---

## 一、实验任务与完成情况

| # | 任务 | 分值 | 完成情况 | 报告位置 |
|---|---|---|---|---|
| 1 | 成功启动 TuGraph 平台，文字描述安装/部署步骤，展示系统登录截图 | 4 | ✅ | [2.1 部署与启动](docs/实验一报告.md#21-部署与启动) |
| 2 | 模型建立、数据导入、增删改查，截图展示运行结果 | 4 | ✅ | [2.2 图建模与数据导入](docs/实验一报告.md#22-图建模与数据导入)、[2.3 增删改查](docs/实验一报告.md#23-增删改查) |
| 3 | 自己设计一个聚合查询的例子，截图展示运行结果 | 4 | ✅ | [2.4 自定义聚合查询](docs/实验一报告.md#24-自定义聚合查询设计) |
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
│   ├── person.csv                32 位人物顶点
│   ├── movie.csv                 23 部影片顶点
│   ├── direct.csv                执导关系边
│   ├── acted_in.csv              出演关系边
│   └── produce.csv               制片关系边
├── cypher/                       全部 Cypher 脚本
│   ├── 01_schema.cql             建标签 / 建索引
│   ├── 02_crud.cql               增删改查完整演示
│   └── 03_aggregate.cql          自定义聚合查询（核心）
├── scripts/                      Bolt 协议自动化脚本
│   ├── import_data.py            用 Neo4j 驱动批量导入 CSV
│   ├── run_queries.py            批量执行聚合查询并打印表格
│   └── requirements.txt
├── deploy/                       部署方案文档
│   ├── aliyun-computenest.md     方式一：阿里云计算巢免费试用（本实验采用）
│   └── docker-local.md           方式二：本地 Docker 单机部署
└── screenshots/                  实验运行截图
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
    32 个顶点                 23 个顶点
                3 类边 / 65 条
```

---

## 四、数据集说明

自建电影领域数据集，覆盖 1972–2023 年的 23 部影片与 32 位人物（导演 9 位、演员 20 位、制片 4 位，部分身兼多职）。

| 文件 | 行数 | 内容 |
|---|---|---|
| `data/person.csv` | 32 | 人物 |
| `data/movie.csv` | 23 | 影片 |
| `data/direct.csv` | 23 | 执导关系 |
| `data/acted_in.csv` | 36 | 出演关系 |
| `data/produce.csv` | 6 | 制片关系 |

导入后预期规模：**55 个顶点 / 65 条边**。

---

## 五、快速复现

### 1. 启动 TuGraph

见 [`deploy/aliyun-computenest.md`](deploy/aliyun-computenest.md)（云上）或 [`deploy/docker-local.md`](deploy/docker-local.md)（本地 Docker）。

### 2. 建模型

在 Web 界面「图构建」中可视化建表，或直接执行：

```bash
# 在 Web 界面「Cypher 查询」框内逐条执行
cypher/01_schema.cql
```

### 3. 导入数据

**方式 A（Web 界面）**：图项目 → 数据导入 → 分别选择 `person.csv` / `movie.csv` / `direct.csv` / `acted_in.csv` / `produce.csv`，映射标签与列名。

**方式 B（Bolt 脚本）**：

```bash
pip install neo4j
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

完整 5 组聚合查询与结果分析见[报告 2.4 节](docs/实验一报告.md#24-自定义聚合查询设计)。

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
| TuGraph 版本 | 4.5.x（镜像 `tugraph/tugraph-runtime-ubuntu18.04:4.5.0`） |
| 部署方式 | 阿里云计算巢 · TuGraph 试用服务 |
| Web 端口 | 7070 |
| Bolt 端口 | 7687 |
| 客户端 | Chrome / Edge |
| Bolt 驱动 | neo4j Python Driver 5.x |
