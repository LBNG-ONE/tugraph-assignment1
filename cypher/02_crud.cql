// ============================================================
// 实验一 · 步骤二：增删改查（CRUD）演示
// 场景：新上映影片入库 → 建立关系 → 查询 → 修改评分 → 删除
// 说明：临时数据使用 1990x / 2990x 段 ID，避免与正式数据集冲突
// ============================================================

// ------------------------------------------------------------
// 一、增（CREATE）
// ------------------------------------------------------------
// 1. 新增两位人物：演员 Ryan Gosling(19901)、导演 Denis Villeneuve(19902)
CREATE (p:person {id:19901, name:'Ryan Gosling', born:1980, country:'加拿大'})
CREATE (d:person {id:19902, name:'Denis Villeneuve', born:1967, country:'加拿大'})

// 2. 新增一部影片：Blade Runner 2049(29901)
CREATE (m:movie {id:29901, title:'Blade Runner 2049', release_year:2017, rating:8.3, duration:164, country:'美国'})

// 3. 建立关系：导演执导 + 演员出演
MATCH (d:person {id:19902}), (m:movie {id:29901})
CREATE (d)-[:direct]->(m)

MATCH (p:person {id:19901}), (m:movie {id:29901})
CREATE (p)-[:acted_in]->(m)

// 4. 校验：新片及其关联人物（两跳路径）
MATCH (p:person)-[r]->(m:movie {id:29901})
RETURN p.name AS 人物, type(r) AS 关系, m.title AS 影片

// ------------------------------------------------------------
// 二、查（MATCH / RETURN）
// ------------------------------------------------------------
// 5. 按主键查新增的演员
MATCH (p:person {id:19901}) RETURN p

// 6. 按属性过滤 + 模糊匹配
MATCH (m:movie) WHERE m.title CONTAINS 'Blade' RETURN m.id, m.title, m.rating

// 7. 聚合校验：当前顶点/边总数（应为 70 顶点 / 85 边）
MATCH (n) RETURN COUNT(n) AS 顶点总数
MATCH ()-[r]->() RETURN COUNT(r) AS 边总数

// ------------------------------------------------------------
// 三、改（SET）
// ------------------------------------------------------------
// 8. 修正影片评分（8.3 → 8.4）
MATCH (m:movie {id:29901}) SET m.rating = 8.4 RETURN m.id, m.title, m.rating

// 9. 新增属性：为影片补充 tagline
MATCH (m:movie {id:29901}) SET m.tagline = 'There is an order to things.' RETURN m

// ------------------------------------------------------------
// 四、删（REMOVE / DELETE）
// ------------------------------------------------------------
// 10. REMOVE 删除属性（保留节点）
MATCH (m:movie {id:29901}) REMOVE m.tagline RETURN m

// 11. 删除关系（必须先删边再删点，否则会被“节点仍有边”拒绝）
MATCH (:person {id:19902})-[r:direct]->(:movie {id:29901}) DELETE r
MATCH (:person {id:19901})-[r:acted_in]->(:movie {id:29901}) DELETE r

// 12. 删除节点（先删残余边，避免悬空边）
MATCH (m:movie {id:29901})-[r]-() DELETE r, m
MATCH (m:movie {id:29901}) DELETE m

MATCH (p:person {id:19901})-[r]-() DELETE r, p
MATCH (p:person {id:19901}) DELETE p

MATCH (p:person {id:19902})-[r]-() DELETE r, p
MATCH (p:person {id:19902}) DELETE p

// ------------------------------------------------------------
// 五、复核：数据已恢复为导入时的初始状态（67 顶点 / 83 边）
// ------------------------------------------------------------
MATCH (n) RETURN COUNT(n) AS 顶点总数
MATCH ()-[r]->() RETURN COUNT(r) AS 边总数
