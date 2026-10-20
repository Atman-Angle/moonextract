# MoonExtract 项目申报书

**基本信息**

- 项目名称：MoonExtract：MoonBit 的逐字证据抽取与来源定位库
- 参赛者：[待填写]
- 联系方式：[待填写]
- GitHub 仓库链接：https://github.com/Atman-Angle/moonextract
- 项目方向：结构化信息抽取基础库 / 可追溯 AI 工具链基础设施
- 项目性质：原创项目，非移植；参考 Google LangExtract 的证据绑定思路

**项目简介与生态定位**

MoonExtract 接收源文档和上游模型或规则给出的候选值，返回候选文本在原文中的全部逐字区间，并标记为 `unique`、`ambiguous` 或 `missing`。它只证明文本出现在该位置，不判断语义真假。接口不绑定模型、行业或文档格式，可用于 RAG、合同审核、日志诊断和 IDE 文档工具。

MoonBit 应用目前要各自处理模型改写、重复命中、UTF-8、UTF-16 与码点偏移混用、分块坐标回填和证据篡改。嵌入 Python 或 JavaScript 的 LangExtract 会引入运行时、FFI 和数据转换，不适合 WASM 与原生目标。MoonExtract 提供无网络、无模型依赖的纯 MoonBit 证据层。mooncakes 检索 `moonextract`、`langextract` 均无同名模块；现有引用检查、构建证据包、数据变更凭证等库职责不同，未发现以“候选值到原文逐字区间”为核心 API 的同类模块。模型和解析器可以替换，但值对应哪段原文需要由稳定、可测试的基础层回答。

**预期使用场景**

1. **LLM/RAG 抽取审计**：模型返回 `party = "示例公司"`。一次命中返回区间并标记 `unique`，界面高亮对应句子；两次命中返回两个区间并标记 `ambiguous`，展示全部候选；零次命中标记 `missing`。
2. **合同与票据字段核验**：解析器先得到合同编号、甲方、金额等候选值，MoonExtract 将它们绑定到原文。复核人员可点击字段查看逐字证据；`validate_extraction` 会拒绝状态、数量、区间或文本不一致的记录。
3. **长文档分块抽取**：文档被切成固定码点数的块，模型在块内抽取 `"甲方"`。`TextChunk::to_global` 把局部区间映射回全文坐标；即使前文含 emoji，返回的仍是统一码点坐标，可直接用于切片和高亮。

**核心功能与交付边界**

- `Document`、`Span`、`Evidence`、`Extraction`、`MatchStatus` 模型，字段私有，只能通过校验过的构造函数和访问器操作。
- 使用 KMP 返回全部逐字命中，包括重叠命中，`find_all` 为 `O(n + m)`；重复命中不自动选择其中一个。
- 使用 Unicode 码点索引和半开区间 `[start, end)`，拒绝非法 UTF-16；原始值、规范化值和证据文本分离，并提供分块映射与稳定 JSON。
- `validate_extraction` 重新计算完整命中集合，检查状态、数量、文档 ID、区间、文本和顺序。
- 一期交付可发布的库、CLI、API 文档、CI 和边界测试。明确不做模型调用、Prompt、OCR、PDF 解析、语义判定、模糊匹配、向量检索和 Web UI。

**实现路径与验收**

常见路径有 FFI 调用 Python/JS、正则或平台字符串查找、MoonBit 原生匹配。第一条牺牲可移植性并增加数据转换；第二条容易混淆 UTF-16 与码点偏移，也难统一处理重叠命中。MoonExtract 选择原生码点数组加 KMP，用受控的 API 不变量换取跨目标一致行为。

实现重点是让证据可复核：状态和证据来自同一次完整扫描；校验不只检查已有 span，而要重新计算全部命中；歧义交给上层；分块局部坐标必须映射成全文坐标。仓库已有超过 10 个可独立验证的功能提交，覆盖模型、码点切片、KMP、歧义、分块、JSON、校验、CLI 和端到端测试。验收以 `moon check --target all --no-mbti`、`moon test`、公开接口生成和 README 示例可复现为准。

**移植或参考说明**

- 参考项目：Google LangExtract，https://github.com/google/langextract，Apache-2.0
- 本项目：Apache-2.0，独立 MoonBit 实现，非移植，未复制其代码
- 参考范围：仅“抽取值应绑定源文本证据”的设计思路；LLM 调用、Prompt、并行抽取和可视化不在交付范围内
