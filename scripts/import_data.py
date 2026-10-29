#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""通过 Bolt 协议把 CSV 数据导入 TuGraph。

TuGraph 的 Bolt 协议兼容 Neo4j Bolt，因此可直接使用 Neo4j 官方 Python 驱动。
用法：
    pip install neo4j
    python import_data.py --uri bolt://127.0.0.1:7687 --user admin --password 73@TuGraph
"""
import argparse
import csv
import os
import sys

from neo4j import GraphDatabase

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(BASE, "data")


def read_csv(name):
    with open(os.path.join(DATA, name), encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def to_int(v):
    return None if v in (None, "") else int(v)


def to_float(v):
    return None if v in (None, "") else float(v)


def drop_all(driver):
    print("[0/4] 清空已有数据 ...")
    with driver.session() as s:
        s.run("MATCH (n) DETACH DELETE n").consume()


def load_persons(driver):
    rows = read_csv("person.csv")
    print(f"[1/4] 导入 person 顶点 {len(rows)} 条 ...")
    cypher = ("CREATE (n:person {id:$id, name:$name, born:$born, country:$country})")
    with driver.session() as s:
        for r in rows:
            s.run(cypher, id=to_int(r["id"]), name=r["name"],
                  born=to_int(r.get("born")), country=r.get("country")).consume()


def load_movies(driver):
    rows = read_csv("movie.csv")
    print(f"[2/4] 导入 movie 顶点 {len(rows)} 条 ...")
    cypher = ("CREATE (n:movie {id:$id, title:$title, release_year:$release_year,"
              " rating:$rating, duration:$duration, country:$country})")
    with driver.session() as s:
        for r in rows:
            s.run(cypher, id=to_int(r["id"]), title=r["title"],
                  release_year=to_int(r.get("release_year")),
                  rating=to_float(r.get("rating")),
                  duration=to_int(r.get("duration")),
                  country=r.get("country")).consume()


def load_edges(driver, fname, rel, src_label, dst_label):
    rows = read_csv(fname)
    print(f"[3/4] 导入 {rel} 边 {len(rows)} 条 ...")
    cypher = (f"MATCH (a:{src_label} {{id:$src}}), (b:{dst_label} {{id:$dst}}) "
              f"CREATE (a)-[:{rel}]->(b)")
    with driver.session() as s:
        for r in rows:
            s.run(cypher, src=to_int(r["src_id"]), dst=to_int(r["dst_id"])).consume()


def summary(driver):
    print("[4/4] 统计校验 ...")
    with driver.session() as s:
        for label in ("person", "movie"):
            n = s.run(f"MATCH (n:{label}) RETURN COUNT(n) AS c").single()["c"]
            print(f"      {label:8s} 顶点数 = {n}")
        for rel in ("direct", "acted_in", "produce"):
            n = s.run(f"MATCH ()-[r:{rel}]->() RETURN COUNT(r) AS c").single()["c"]
            print(f"      {rel:8s} 边数   = {n}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--uri", default="bolt://127.0.0.1:7687")
    ap.add_argument("--user", default="admin")
    ap.add_argument("--password", default="73@TuGraph")
    ap.add_argument("--clean", action="store_true", help="导入前清空数据")
    args = ap.parse_args()

    driver = GraphDatabase.driver(args.uri, auth=(args.user, args.password))
    try:
        driver.verify_connectivity()
        print(f"已连接 {args.uri}")
        if args.clean:
            drop_all(driver)
        load_persons(driver)
        load_movies(driver)
        load_edges(driver, "direct.csv", "direct", "person", "movie")
        load_edges(driver, "acted_in.csv", "acted_in", "person", "movie")
        load_edges(driver, "produce.csv", "produce", "person", "movie")
        summary(driver)
        print("导入完成。")
    except Exception as e:
        print(f"导入失败：{e}", file=sys.stderr)
        sys.exit(1)
    finally:
        driver.close()


if __name__ == "__main__":
    main()
