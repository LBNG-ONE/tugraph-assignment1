// ============================================================
// 实验一 · 步骤二：图模型建立（Schema）
// 图模型：电影领域属性图
//   顶点标签：person（人物）、movie（影片）
//   边标签  ：direct（执导）、acted_in（出演）、produce（制片）
// 语法依据：TuGraph Cypher 过程 db.createVertexLabel / db.createEdgeLabel
//   https://tugraph-db.readthedocs.io/zh-cn/v3.5.0/5.developer-manual/6.interface/1.cypher.html
// 说明：也可在 Web 界面「图构建」中可视化建表，效果等价，见报告 2.1 节。
// ============================================================

// ---------- 1. 顶点标签：person ----------
// 字段：id(主键) / name / born / country
CALL db.createVertexLabel('person', 'id',
  'id',      int64,  false,
  'name',    string, false,
  'born',    int32,  true,
  'country', string, true)

// ---------- 2. 顶点标签：movie ----------
// 字段：id(主键) / title / release_year / rating / duration / country
CALL db.createVertexLabel('movie', 'id',
  'id',           int64,  false,
  'title',        string, false,
  'release_year', int32,  true,
  'rating',       double, true,
  'duration',     int32,  true,
  'country',      string, true)

// ---------- 3. 边标签 ----------
// edge_constraints 限定边的起点/终点标签，防止非法连边
CALL db.createEdgeLabel('direct',    '[["person","movie"]]')
CALL db.createEdgeLabel('acted_in',  '[["person","movie"]]')
CALL db.createEdgeLabel('produce',   '[["person","movie"]]')

// ---------- 4. 索引 ----------
// 主键索引由 createVertexLabel 自动创建；此处补充非主键查询索引
CALL db.addIndex('movie', 'title', false)
CALL db.addIndex('person', 'name', false)

// ---------- 5. 校验：查看已创建的 Schema ----------
CALL db.vertexLabels()
CALL db.edgeLabels()
CALL db.getLabelSchema('vertex', 'person')
CALL db.getLabelSchema('vertex', 'movie')
CALL db.getLabelSchema('edge', 'acted_in')
