#!/usr/bin/env python3
"""按 PDF 现状校正《月之都》书末索引的页码（就近重定位，不重选页）。

用法：
    python3 scripts/build-index.py            # 只报告，不改文件
    python3 scripts/build-index.py --write    # 回填 books/mooncity/backmatter.tex

原理：索引是编者挑过的，不能按「出现即收录」重算——那样「章程总目」会从 8 页涨到 20 页，
索引反而失控。所以保留原有选页，只做校正：对索引给出的每一个页码，在 ±WINDOW 页范围里
找真正出现该词的那一页，取最近的一个；范围内找不到就丢弃并报告。之后合并连续页为区间。

正文页码与 PDF 页的偏移由「印刷页 1」自动探测，避免写死；索引自身页面从扫描范围剔除，
否则会出现「索引指向索引」。
"""
import argparse
import io
import re
import subprocess
import sys

PDF = "books/mooncity/月之都——记一个不想变化的文明.pdf"
TEX = "books/mooncity/backmatter.tex"


def sh(*args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def page_count(pdf):
    return int(re.search(r"Pages:\s+(\d+)", sh("pdfinfo", pdf)).group(1))


def page_text(pdf, n):
    return sh("pdftotext", "-f", str(n), "-l", str(n), pdf, "-")


def detect_offset(pdf, pages):
    """找印刷页 1 对应的 PDF 页：该页末行为「1」。"""
    for p in range(1, min(pages, 40) + 1):
        lines = [l.strip() for l in page_text(pdf, p).strip().split("\n") if l.strip()]
        if lines and lines[-1] == "1":
            return p - 1
    raise SystemExit("无法判定印刷页码偏移（未找到末行为「1」的页）")


def fmt(pages):
    """[1,2,3,5] → '1—3、5'"""
    if not pages:
        return ""
    out, i = [], 0
    while i < len(pages):
        j = i
        while j + 1 < len(pages) and pages[j + 1] == pages[j] + 1:
            j += 1
        out.append(str(pages[i]) if j == i else f"{pages[i]}—{pages[j]}")
        i = j + 1
    return "、".join(out)


WINDOW = 10  # 允许的页码漂移范围


def relocate(old_pages, found_pages):
    """把旧的页码逐个挪到附近的真实出现页。

    按「距离最近者优先」贪心分配，避免先处理的旧页码把后面更贴近的那一页占掉，
    造成本可对上的条目被误丢。
    """
    pairs = []
    for p in old_pages:
        for q in found_pages:
            pairs.append((abs(q - p), p, q))
    pairs.sort()
    used_q, assigned, lost = set(), {}, []
    for _, p, q in pairs:
        if p in assigned or q in used_q:
            continue
        assigned[p] = q
        used_q.add(q)
    for p in old_pages:
        if p not in assigned:
            lost.append(p)
    return sorted(assigned.values()), lost


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="回填 backmatter.tex")
    args = ap.parse_args()

    tex = io.open(TEX, encoding="utf-8").read()
    entries = re.findall(r"\\idx\{([^}]*)\}\{([^}]*)\}", tex)
    if not entries:
        raise SystemExit("没有找到任何 \\idx 条目")

    total = page_count(PDF)
    off = detect_offset(PDF, total)
    texts = {p: page_text(PDF, p) for p in range(off + 1, total + 1)}

    # 索引自身所占的印刷页（跳过），以「索 引」标题页起算
    idx_start = min((p - off for p, t in texts.items()
                     if re.search(r"索\s*引", t) and "dotfill" not in t), default=10 ** 6)

    changes, missing, dropped = [], [], []
    for name, old in entries:
        found = sorted({p - off for p, t in texts.items()
                        if p - off < idx_start and name in t})
        if not found:
            missing.append(name)
            continue
        olds = []
        for part in old.split("、"):
            part = part.strip()
            if "—" in part:
                a, b = part.split("—")
                olds.extend(range(int(a), int(b) + 1))
            elif part.isdigit():
                olds.append(int(part))
        olds = sorted(set(olds))
        kept, lost = relocate(olds, found)
        if lost:
            dropped.append((name, lost))
        new = fmt(kept)
        if new != old:
            changes.append((name, old, new))

    for name, old, new in changes:
        print(f"{name}: {old} → {new}")
    print(f"\n共 {len(entries)} 条，需要改 {len(changes)} 条。")
    if missing:
        print("正文中未出现、未改动的条目：", "、".join(missing))
    if dropped:
        print("旧页码在 ±%d 页内找不到对应内容、已丢弃：" % WINDOW)
        for name, lost in dropped:
            print("   ", name, lost)

    if args.write and changes:
        for name, old, new in changes:
            tex = tex.replace(f"\\idx{{{name}}}{{{old}}}", f"\\idx{{{name}}}{{{new}}}")
        io.open(TEX, "w", encoding="utf-8").write(tex)
        print("已回填", TEX)


if __name__ == "__main__":
    main()
