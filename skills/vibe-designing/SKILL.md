---
name: vibe-designing
description: Use when generating or reviewing product UI with an agent — console, dashboard, list, detail, form pages — or when a generated page misses empty/loading/error/permission states, hardcodes color and size literals instead of tokens, misuses components (Badge vs Tag, Modal vs Drawer), reads like a generic AI template, or when someone asks whether a generated page is good enough to ship. For distinctive brand/landing visual direction, use frontend-design instead.
---

# Vibe Designing

## Overview

模型不是不懂设计，而是**分布收敛**：需求含糊时它向训练数据里最高频、最稳妥的答案靠拢——通用、安全，也因此平庸。

解法不是等更强的模型，也不是写更长的 prompt，而是把设计判断**写成声明**（管方向：什么算对）和**执行契约**（管路径：何时读、怎么用、做完怎么检查），生成后**按证据验收**。

> 教会 AI 做设计的，从来不是更强的模型，而是更好的设计师。

源自阿里云设计中心《Vibe Designing Playbook》。全书精读见 [references/playbook-digest.md](references/playbook-digest.md)，术语判据见 [references/lexicon.md](references/lexicon.md)。

## When to Use

**用于**：产品化 UI——控制台、看板、列表、详情、设置、表单、Agent 管理页。这类页面的成败在于状态是否完整、语义是否可信、系统是否一致。

**不用于**：
- 品牌落地页、营销页、作品集的**视觉方向探索** → 用 `frontend-design`（书里也印证这个分工：落地页 Visual & Brand 权重 25%，控制台只有 8%）
- 一次性 demo、纯静态文档页

两者可叠加：`frontend-design` 定视觉个性，本 skill 保证状态、语义、token 和验收不塌。

## 三个必做动作

以下三条来自基线实测：让两个强模型子代理各写一个真实页面，不给任何设计指导，再逐项量化产物。

| 动作 | 实测失败 | 证据 |
| --- | --- | --- |
| 1. 生成前先立声明 | **2/2** | 加载态 0 处——两个都漏，且是**唯一无人幸免**的一项 |
| 2. 每个视觉值有来源 | 1/2 | 一个硬写 23 种 hex 共 195 处、零 token；另一个自我纠正到 57 处 `var(--*)` |
| 3. 按证据验收 | 1/2 | 一个只跑 esbuild 就断言「接近真实产品」；另一个主动截图点击 |

**这个分布本身就是结论**：好行为在强模型里是**偶发**的，不是稳定的。自我纠正的那个代理花了 196K tokens、59 次工具调用才走到 token 与证据；另一个 70K tokens 就交付了。声明与契约的作用不是教模型没见过的东西，而是让这些判断**可靠且廉价**，不取决于代理恰好愿意游荡多久。

而加载态 2/2 皆失，连那个做了 20 分钟自审、截了图、点了按钮的代理也没补——因为**看一张有数据的成品截图，是看不出加载态缺失的**。这类「不在场的东西」只能靠声明先写出来，事后评审补不回来。

### 1. 生成前：先立声明，尤其 L5 / L6

不要从 prompt 直接跳到代码。先把需求变成 **spec 六层**——L1 定位与意图 / L2 信息架构 / L3 核心链路 / L4 组件功能细节 / **L5 边界条件** / **L6 验收标准**。

L5/L6 是**必填项**，不是可选补充：

- **L5 边界条件**：空态、加载态、错误态、权限降级，逐个写。模型天然优先完成主流程和成功态，因为那最像一张完整截图；真实使用里用户更常遇到的是等待、无数据、无权限、失败后重试。
- **L6 验收标准**：Given/When/Then。它是验收的接口——能判断「达标」，是因为 spec 先定义了什么叫达标。没有 L6，最后只能凭感觉说「差不多」。

视觉方向若未沉淀，**同步定 visual-spec**（气质、密度、中性色温、状态色、token 规则）。否则模型会先用默认视觉补位，再把这些默认选择带进后面的结构和组件。

### 2. 生成中：每个视觉值必须有来源

三条执行约束，逐条落到代码：

```text
1. 所有视觉值走 var(--*) 引用（禁止裸写 hex / px / ms / cubic-bezier）
2. hover / active / disabled / selected 从基础 token 派生，不新造值
3. 找不到 token，不硬写字面量 —— 记录到 gaps.log
```

**gaps.log 是这套机制里最容易被跳过、也最有价值的一环**。它记录的不是失败，而是真实的系统缺口：

```text
2026-05-06 [med] transform scale 因子 (active:scale-0.97) 无 token -- fallback: Tailwind arbitrary [0.97]，违反执行约束 §1 但无替代
```

有合理替代 → 用 fallback 并记录；没有 → **拒绝生成那一部分**，等待补 token。比起悄悄写一个 `#FFE4C4`，明示缺口更有价值——它会进入下一轮设计系统迭代。这叫**合法失败（Legible Failure）**。

**状态色回领域语义，不是配色选择**。基线里两个代理都写了 `failed: "#d03b3b"`、风险色 `#E5484D`——把「编码风险」做成了一次性视觉选择。正确口径：业务等级 → 语义 token（`--warning-high` / `--warning-medium` / `--warning-low` / `--unknown`）。用户在大量告警间扫读时，颜色承担的是**识别风险的责任**，必须可被信任。

同理：不可逆操作须二次确认且文案写清后果（「关闭后，该资产将不再受 XX 防护」优于「确定吗？」）；敏感字段（AccessKey、IP、账号）默认脱敏。

**焦点态不可省**：`outline: 2px solid var(--ring); outline-offset: 2px;`，不可降级为 `outline: none`——模型很容易为了「干净」删掉它。

### 3. 生成后：按证据验收，不按意图

**评审看的是稿件，不是作者脑中的稿件。**

自己刚写完的页面，不能靠「我的设计决策是……」来证明它成立——那是生成器的意图，不是交付物的证据。基线里两个代理都是这样自评的，其中一个只跑了语法编译就断言产品级质量。

验收前必须先获得**证据条件**：页面真的被打开、画面真的被截图、关键控件真的被点击。四层证据：

| 证据层 | 采什么 |
| --- | --- |
| Screenshot | 桌面 1440×1000 截图 + full-page |
| DOM / CSS QA | 横向溢出、文字裁切、低对比度、小点击目标、图片损坏 |
| Click Smoke | 点主要控件后有无 console error、无反馈、断链 |
| Page Profile | 真实路径 vs 占位链接、headline、CTA、可点击目标 |

取证手段：Playwright MCP 或 claude-in-chrome MCP 均可；起本地 dev server 后截图 + 点击冒烟即可，不需要搭完整评估运行时。**并行评审时用独立端口与独立浏览器 profile**，否则会互相抢占导致证据串台。顺带阻断外部字体 CDN——同一原型每次打开字体都不同，截图判断就成了偶然。

**DOM 与截图冲突时，截图优先**——用户看不到 DOM 说自己没问题，用户看到的是画面。AI 很擅长生成「结构完整」的页面，但结构完整经常只是看上去有东西。

判分先定**页面类型**再套六维度（同一套维度，权重随类型变；完整权重表见 digest）：Product Intent / Trust & Domain Fit / Information Architecture / Interaction Readiness / System Craft / Visual & Brand Expression。

**平均分会掩盖致命问题**。分数说质量水平，**阻断项**说能不能放行——`unclear_primary_task`、`broken_key_task_path`、`generic_template_output`（页面可以属于任何产品）、`inconsistent_design_system` 等一旦命中，即使 7.8 分也不放行。

严格度随阶段变（模式只改放行策略，不改评分模型）：过程稿 `vibe_draft` 阈值 7.5 → 原型 `prototype` 8.0 → 上线门禁 `release_gate` 8.0。同一个问题在不同阶段严重度不同：过程稿里「占位链接」是提示，到上线门禁就不能再解释成「后续会接」。

## 回流索引

不满意时**不要在整页反复打补丁**。先判断问题属于哪一类，回到对应声明：

| 看到的问题 | 回到哪里 |
| --- | --- |
| 主流程能跑，但空态、失败、权限态缺失 | `spec.md` L5 |
| 页面不像这个业务；风险/敏感字段处理不当 | `domain.md` |
| 页面有 AI 味、层级平均、动效无目的 | `craft.md` |
| 色值、字号、动效时长写散了 | `design.md` |
| Badge/Tag、Modal/Drawer、Tabs/Tabs-Switch 混用 | `components` |
| 结构像卡片墙，不像看板 | `template` |
| 评估说不清哪里错 | `evaluator` |

优化指令要**压缩成少数几条**，且能直接进入下一轮生成——「继续优化视觉、增强交互」需要人再解释一遍，等于没说。

## 把模糊词换成判据

craft 规则必须满足三点：**现象可观察、执行动作明确、结果可验收**。形容词做不到这三点。

| 模糊说法 | 写成判据 |
| --- | --- |
| 色彩要克制 | 一屏 brand 实色 + gradient 总和 ≤ 3 处，其余走中性灰阶 |
| 加载时展示 loading | `<300ms` 不展示（避免闪烁）、`300ms–2s` 骨架屏、`>2s` Loader + 进度说明、`>10s` 超时 + 重试入口 |
| 动效要自然 | UI 动画 ≤ 300ms，只动画 transform / opacity，且每个动画必须说明目的 |
| 字体要更专业 | 中文 UI 显式走 `var(--font-cn)`，不默认 Inter / Roboto |

取词从 [references/lexicon.md](references/lexicon.md)（12 类 188 词）——每条带判据，如 `Duration: hover ≈150ms 原生，400ms 像在思考`、`Badge 是附着的、信息性的；Tag 是独立、可选、可移除的`。

## Common Mistakes

| 错误 | 后果 / 纠正 |
| --- | --- |
| 从 prompt 直接跳到代码 | 上游偏差沿链路放大；先立 spec，约束尽早进入 |
| 只写主流程和成功态 | 那只是「像一张完整截图」；L5 四态逐个写 |
| 硬写 hex/px/ms，或每个状态新造一个值 | 系统失去单一事实源；走 `var(--*)` + 从基础 token 派生 |
| 找不到 token 就悄悄写字面量 | 缺口被藏进代码；记 gaps.log，或拒绝生成那部分 |
| 状态色/风险色当配色选 | 颜色在编码风险，须回 domain 语义 token，用户要能信任它 |
| 用「我的设计决策是…」证明页面成立 | 那是意图不是证据；先打开、截图、点击 |
| 只跑语法编译/类型检查就说完成 | 编译通过 ≠ 画面成立；DOM 与截图冲突时截图优先 |
| 拿平均分放行 | 阻断项不能被平均分摊薄；7.8 分也可能因主路径断裂而退回 |
| 一版不满意就整页重打补丁 | 用回流索引定位到具体声明再改 |
| 把 template / sample 当抄板 | 模版是骨架起点；同名文件不代表同场景（`sample-*` 不是生产骨架） |
| 无限迭代 | 达阈值且无阻断、到平台期、或分数下降时应停并回退到更好版本 |
