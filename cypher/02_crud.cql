// ============================================================
// 实验一 · 步骤二：增删改查（CRUD）演示
// 场景：新上映影片入库 → 建立关系 → 查询 → 修改评分 → 删除
// ============================================================

// ------------------------------------------------------------
// 一、增（CREATE）
// ------------------------------------------------------------
// 1. 新增两位人物：演员 Ryan Gosling(10033)、导演 Denis Villeneuve(10034)
CREATE (p:person {id:10033, name:'Ryan Gosling', born:1980, country:'加拿大'})
CREATE (d:person {id:10034, name:'Denis Villeneuve', born:1967, country:'加拿大'})

// 2. 新增一部影片：Blade Runner 2049(20024)
CREATE (m:movie {id:20024, title:'Blade Runner 2049', release_year:2017, rating:8.3, duration:164, country:'美国'})

// 3. 建立关系：导演执导 + 演员出演
MATCH (d:person {id:10034}), (m:movie {id:20024})
CREATE (d)-[:direct]->(m)

MATCH (p:person {id:10033}), (m:movie {id:20024})
CREATE (p)-[:acted_in]->(m)

// ------------------------------------------------------------
// 二、查（MATCH / RETURN）
// ------------------------------------------------------------
// 4. 按主键查新增的演员
MATCH (p:person {id:10033}) RETURN p

// 5. 查新片及其关联人物（两跳路径）
MATCH (p:person)-[r]->(m:movie {id:20024})
RETURN p.name AS 人物, type(r) AS 关系, m.title AS 影片

// 6. 按属性 + 模糊匹配查询
MATCH (m:movie) WHERE m.title CONTAINS 'Blade' RETURN m.id, m.title, m.rating

// ------------------------------------------------------------
// 三、改（SET）
// ------------------------------------------------------------
// 7. 修正影片评分（8.3 → 8.4）
MATCH (m:movie {id:20024}) SET m.rating = 8.4 RETURN m.id, m.title, m.rating

// 8. 新增属性：为影片补充 tagline
MATCH (m:movie {id:20024}) SET m.tagline = 'There is an order to things.' RETURN m

// ------------------------------------------------------------
// 四、删（REMOVE / DELETE）
// ------------------------------------------------------------
// 9. REMOVE 删除属性（保留节点）
MATCH (m:movie {id:20024}) REMOVE m.tagline RETURN m

// 10. DELETE 删除关系（必须先删边再删点，否则报“节点仍有边”）
MATCH (:person {id:10034})-[r:direct]->(:movie {id:20024}) DELETE r
MATCH (:person {id:10033})-[r:acted_in]->(:movie {id:20024}) DELETE r

// 11. DELETE 删除节点（连同残余边一起删，避免悬空边）
MATCH (m:movie {id:20024})-[r]-() DELETE r, m
MATCH (m:movie {id:20024}) DELETE m

MATCH (p:person {id:10033})-[r]-() DELETE r, p
MATCH (p:person {id:10033}) DELETE p

MATCH (p:person {id:10034})-[r]-() DELETE r, p
MATCH (p:person {id:10034}) DELETE p

// ------------------------------------------------------------
// 五、复核：数据已恢复为导入时的初始状态
// ------------------------------------------------------------
MATCH (n) RETURN COUNT(n) AS 节点总数
MATCH ()-[r]->() RETURN COUNT(r) AS 边总数
