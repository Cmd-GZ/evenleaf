# 远东异端史料与文明起源重构丛书

> 一套虚构的伪学术专著与世界观设定集。书中人物、档案编号、考释推演与史料重构均属虚构创作。

---

## 简介

本仓库用于维护一套托名俄籍汉学家 А. В. 巴兰尼科夫主编的十六开伪学术丛书《远东异端史料与文明起源重构丛书》。全套书以冷战期间莫斯科档案馆、圣彼得堡学界及异常文献机构的编目体例为外壳，通过简牍辑佚、测绘报告、同位素清单与传世文献的交叉对校，重构月之都与早期地面史料之间的虚构史学体系。

全书使用 XeLaTeX 排版（185 × 260 mm，十六开），各卷均含完整封面、扉页、版权页、目录、档案框、脚注、大事年表与索引。

---

## 已成书目

全套丛书规划十二卷（现行书目另附卷次暂定的第 XIII 卷），目前已正式成书并附带成品 PDF 的有三卷：

| 卷次 | 书名 | 著者／辑校 | 译者 | 状态 | 成品 |
|---|---|---|---|---|---|
| **第 I 卷** | 月之都——〈广寒宫残简〉辑佚与考释 | ［俄］巴兰尼科夫 辑校 | 李文亚、张建国 | 已成书，79 页（2024 年 9 月） | [PDF](https://github.com/Cmd-GZ/evenleaf/releases/latest/download/guanghan.pdf) |
| **第 VII 卷** (待重写) | 战争的雷霆——记一种可能的中国历史 | ［俄］巴兰尼科夫 | 李文亚、张建国 | 已成书，68 页（2024 年 3 月第 4 版） | [PDF](https://github.com/Cmd-GZ/evenleaf/releases/latest/download/warthunder.pdf) |
| **第 XIII 卷**（暂定） | 月之都——记一个不想变化的文明 | ［日］太田顺也 | 孙笑川、李文亚 | 已成书，106 页，十二章（2024 年 12 月） | [PDF](https://github.com/Cmd-GZ/evenleaf/releases/latest/download/mooncity.pdf) |

- 第 I 卷专治静海七号出土三十七片小篆残简的文字转写、校记、语译与考释；
- 第 VII 卷以通史体例将冷战档案与中原古史并置互校（其中第 3 版仅提交 `6fd71563` 曾流出，第 4 版于书末附勘误汇总）；
- 第 XIII 卷由太田顺也署名，合参背面轨道影像、湖底岩芯与地面遗物，作全月面与落地余波的十二章概论。

其余卷目（第 II—VI、VIII—XII 卷）的卷次、书名与跨书引文关系登记于 [`meta/丛书书目.md`](meta/丛书书目.md)。

---

## 目录结构

```text
worldview/     跨书世界观设定与大事记（各卷共用的基础事实与硬规则）
meta/          丛书书目、版本史、出版版权字段、人物履历与文体规范
shared/style/  丛书共用 LaTeX 版式与封面基座
books/         各卷独立目录（源码、局部设定与构建脚本；PDF 由 CI 发布到 Release）
docs/          排版陷阱排查与编写手册
scripts/       TeX 环境安装、索引页码校验与成品 PDF 取回脚本
```

---

## 构建

各卷互不耦合，进入对应书籍目录执行 `./build.sh` 即可完成三遍 XeLaTeX 编译并输出分发 PDF：

```bash
cd books/mooncity   # 或 books/guanghan、books/warthunder
./build.sh
```

环境依赖 XeLaTeX、`ctex`、Noto Serif/Sans CJK SC 与 JetBrains Maple Mono 字体；验收标准为未解析引用 = 0、缺字 = 0、Overfull = 0。推送 `.tex`、`shared/` 或 `build.sh` 至主分支后，[`.github/workflows/render.yml`](.github/workflows/render.yml) 会自动重编三卷，并把成品作为资产发布到 [Releases](https://github.com/Cmd-GZ/evenleaf/releases/latest)。仓库里不存 PDF，上面三个链接永远指向最新一次成功构建。

不想自己编译时，可用 [`scripts/fetch-pdfs.sh`](scripts/fetch-pdfs.sh) 把 CI 编好的成品取回本地：脚本先核对 Release 标签里的提交号与本地「最近一次改动构建输入」的提交是否一致，一致才下载到各卷目录下的分发文件名。

```bash
./scripts/fetch-pdfs.sh --check    # 只看状态：版本是否对齐、CI 跑到哪一步
./scripts/fetch-pdfs.sh            # 版本对齐则下载
./scripts/fetch-pdfs.sh --wait 300 # 有构建在排队或运行就先等，最多 300 秒
```

`--force` 跳过版本核对直接下载最新；「构建输入」的判定范围与 `render.yml` 的触发路径一致，改 `PLAN.md`、`SETTING.md` 等文档不计入。

---

## 协作者参考

修改正文、增补设定或调整版式前，请先查阅：

- [`worldview/月之都.md`](worldview/月之都.md)、[`worldview/生态重启.md`](worldview/生态重启.md)、[`worldview/记忆消除场.md`](worldview/记忆消除场.md) —— 已定稿核心世界观与大事记（延伸推敲草稿见 [`worldview/drafts/`](worldview/drafts/)）；
- [`meta/当前状态.md`](meta/当前状态.md)、[`meta/出版信息.md`](meta/出版信息.md)、[`meta/丛书书目.md`](meta/丛书书目.md) —— 各卷现行版本、出版字段、书目关系、三层叙事分工与文体禁令；
- [`AGENTS.md`](AGENTS.md) 与 [`docs/排版与写作手册.md`](docs/排版与写作手册.md) —— 撰写规范与排版细则。

---

## 许可

本仓库（世界观设定、LaTeX 源码、图版、文档，以及 Release 上的成品 PDF）以 [**CC BY-NC-SA 4.0**](LICENSE) 发布：署名、非商业性使用、相同方式共享。

```text
Copyright (c) 2026 Contributors to the evenleaf Repository
```

书中所引古籍原文属公有领域；现代点校本的整理成果受点校者著作权保护，只引用短句。排版所用 Noto 字体依 OFL 分发，可免费使用，但字体文件不入库。
