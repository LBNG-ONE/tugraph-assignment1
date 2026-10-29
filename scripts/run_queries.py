#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""通过 Bolt 执行报告中的关键查询，把结果打印成表格（用于与 Web 界面结果互相印证）。

用法：
    python run_queries.py --uri bolt://<ip>:7687 --user admin --password <pwd>
"""
import argparse

from neo4j import GraphDatabase

QUERIES = [
    ("总览：顶点/边计数",
     "MATCH (n) RETURN COUNT(n) AS 节点总数"),
    ("总览：各标签顶点数",
     "MATCH (n) RETURN labels(n)[0] AS 标签, COUNT(n) AS 数量"),
    ("Q1 导演口碑榜（作品数 >= 2）",
     """MATCH (d:person)-[:direct]->(m:movie)
        WITH d, COUNT(m) AS movieCount, AVG(m.rating) AS avgRating
        WHERE movieCount >= 2
        RETURN d.name AS 导演, movieCount AS 作品数, avgRating AS 平均评分
        ORDER BY avgRating DESC, movieCount DESC LIMIT 10"""),
    ("Q1-a 对照：不过滤作品数",
     """MATCH (d:person)-[:direct]->(m:movie)
        RETURN d.name AS 导演, COUNT(m) AS 作品数, AVG(m.rating) AS 平均评分
        ORDER BY 平均评分 DESC LIMIT 10"""),
    ("Q1-b 劳动模范榜（按作品数）",
     """MATCH (d:person)-[:direct]->(m:movie)
        RETURN d.name AS 导演, COUNT(m) AS 作品数, AVG(m.rating) AS 平均评分
        ORDER BY 作品数 DESC LIMIT 5"""),
    ("Q2 导演演员池规模（两跳 + DISTINCT）",
     """MATCH (d:person)-[:direct]->(m:movie)<-[:acted_in]-(a:person)
        WITH d, m, COUNT(DISTINCT a) AS castSize
        RETURN d.name AS 导演, COUNT(m) AS 影片数, SUM(castSize) AS 演员池规模
        ORDER BY 演员池规模 DESC, 影片数 DESC LIMIT 5"""),
    ("Q3 按出品国聚合",
     """MATCH (m:movie)
        RETURN m.country AS 出品国, COUNT(m) AS 影片数, AVG(m.rating) AS 平均评分,
               MAX(m.rating) AS 最高评分, MIN(m.rating) AS 最低评分
        ORDER BY 影片数 DESC, 平均评分 DESC"""),
    ("Q4 演员口碑榜（出演 >= 2 部）",
     """MATCH (p:person)-[:acted_in]->(m:movie)
        WITH p, COUNT(m) AS movieCount, AVG(m.rating) AS avgRating
        WHERE movieCount >= 2
        RETURN p.name AS 演员, movieCount AS 出演片数, avgRating AS 平均评分
        ORDER BY avgRating DESC LIMIT 5"""),
    ("Q5 全库聚合",
     """MATCH (m:movie)
        RETURN COUNT(m) AS 影片总数, AVG(m.rating) AS 全库平均评分,
               MAX(m.duration) AS 最长片长, MIN(m.duration) AS 最短片长"""),
]


def render(rows):
    if not rows:
        return "      （无结果）"
    keys = list(rows[0].keys())
    data = [[str(r.get(k)) for k in keys] for r in rows]
    widths = [max(len(str(k)), *(len(v) for v in col)) for k, col in zip(keys, zip(*data))]
    line = "      " + "  ".join(str(k).ljust(w) for k, w in zip(keys, widths))
    sep = "      " + "  ".join("-" * w for w in widths)
    out = [line, sep]
    for row in data:
        out.append("      " + "  ".join(v.ljust(w) for v, w in zip(row, widths)))
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--uri", default="bolt://127.0.0.1:7687")
    ap.add_argument("--user", default="admin")
    ap.add_argument("--password", default="73@TuGraph")
    args = ap.parse_args()

    driver = GraphDatabase.driver(args.uri, auth=(args.user, args.password))
    try:
        driver.verify_connectivity()
        with driver.session() as s:
            for i, (title, q) in enumerate(QUERIES, 1):
                print(f"\n=== [{i}] {title} ===")
                try:
                    rows = [dict(r) for r in s.run(q)]
                    print(render(rows))
                except Exception as e:
                    print(f"      执行失败：{e}")
    finally:
        driver.close()


if __name__ == "__main__":
    main()
