# Anibird Agent 指南

## 项目概况

- 这是一个 Flutter 客户端个人项目，围绕 Bangumi 浏览、动画消费和 LLM/Agent 交互能力持续演进。
- 项目当前以跨端一致性和长期可维护性为优先，目标不是“只要跑通”的演示代码，而是在个人维护能力范围内尽量做出成熟、稳定、可长期使用的客户端功能。
- 该项目同时兼顾自用价值和技术展示价值，因此实现时要重视整体架构、代码可维护性、行为一致性和后续扩展空间，不要因为“先能跑”就牺牲长期质量。

## 关键代码入口

- 应用启动与依赖装配：[lib/app/bootstrap.dart](/Users/gche/repos/anibird/lib/app/bootstrap.dart)
- 应用级依赖容器：[lib/app/app_scope.dart](/Users/gche/repos/anibird/lib/app/app_scope.dart)
- 客户端 Agent loop：[lib/backend/services/agent.dart](/Users/gche/repos/anibird/lib/backend/services/agent.dart)
- Bangumi 工具定义：[lib/backend/services/bangumi_tools.dart](/Users/gche/repos/anibird/lib/backend/services/bangumi_tools.dart)
- LLM provider：[lib/backend/api/llm/openai_compatible_llm_provider.dart](/Users/gche/repos/anibird/lib/backend/api/llm/openai_compatible_llm_provider.dart)
- 聊天状态管理：[lib/ui/state/chat_store.dart](/Users/gche/repos/anibird/lib/ui/state/chat_store.dart)
- 发现页/聊天页/设置页/详情页位于 `lib/ui/pages/`

## 当前架构约定

- 继续沿用当前的 `ui/` + `backend/` 目录结构，除非有明确收益再调整。
- Agent 当前是客户端侧、message-driven 的 function-calling loop。
- `timeline` 是聊天渲染主通道，不要重新引入旧的 ReAct 侧通道设计。
- `present_recommendations` 是可选工具，不要把它重新做成强制步骤。
- 实现新功能时，优先评估能否复用现有整体架构、已有抽象和已有状态流，不要默认用局部堆叠代码解决问题。
- 要特别避免特判式实现；如果当前需求在现有结构下只能先通过特判落地，必须明确向开发者指出这是特判方案，以及它的局限和后续可收敛方向。
- `ChatMessage.contents` 是 UI / 持久化侧的消息真值，默认不要为了上下文压缩去改写或删除它。
- 当前 `ChatMessage.content` 只是从 `contents` 动态派生出来的 getter，不是独立维护的 LLM history 字段；不要误把它当成完整的上下文系统。
- 如果后续要做 summary / 上下文压缩，应在独立的 `ChatContext` / LLM history 构造层实现，而不是直接改 `ChatMessage` 本体。
- UI 历史与 LLM 上下文是两个层次：前者服务展示与恢复，后者服务模型输入；后续新增 summary message 或压缩逻辑时，优先保持这两个层次分离。
- 当前状态管理使用 `ValueNotifier`、`Stream` 和 `AppScope`，不要仅为了“更标准”而迁移到 Provider。
- 共享依赖优先直接通过 `BuildContext` 上的 `AppScope` extension 读取，不要继续写 `didChangeDependencies + AppScope.of(context) + 本地字段缓存` 的样板代码。
- 设置页这类分类页面，父页面只负责布局、导航和分类切换；具体分类内容应直接对接对应 store / 数据类，不要在父页面维护子页面字段级状态。
- 当前仓库不保留 `test/` 自动化测试代码。

## 工作边界

- 优先做小步、可落地、便于长期维护的改动，不要上来做与当前收益不匹配的大重构。
- 如果修改聊天或 Agent 行为，保持当前线性消息流设计不变。
- 当前配置仍是本地文件持久化，不是安全存储；涉及密钥、认证、写权限时要明确这是当前阶段的本地实现边界，但不要因此默认降低代码质量或放弃清晰架构。

## 修改后校验

- 有意义的代码改动后，运行 `flutter analyze`。
- 如果涉及 UI、聊天流程或交互行为，补一轮 macOS 手工验证。
- 如果这次没有完成校验，需要在最终说明里明确写出。

## 当前推荐优先级

- 会话持久化与本地存储
- 网络层升级
- Bangumi API 能力分层
- 认证边界规划

## Bangumi OAuth 后续优化目标

- 当前已具备 OAuth 登录、token 持久化和局部 refresh 能力，但还没有完整的全局 session 管理。
- 后续应优先补齐统一的 Bangumi session/auth manager，而不是把 token 生命周期处理继续分散在各个页面 store 中。
- 目标行为：
  - 应用启动或恢复时，如果本地 access token 已过期或即将过期，先尝试 refresh，再恢复用户态。
  - private API 请求前，若 token 临近过期，先做预刷新。
  - private API 返回 `401`，且错误码为 `TOKEN_INVALID` 或 `NEED_LOGIN` 时，自动 refresh 一次并重试原请求一次。
  - 若 refresh 失败，或重试后仍为认证失败，统一清空 Bangumi 登录态并提示重新登录。
- 需要覆盖的关键场景：
  - 用户长时间未打开应用，重新进入时 access token 已过期。
  - 正常使用过程中 token 失效。
  - refresh token 本身也已失效，客户端需要降级到未登录态。

## 会话持久化设计目标

- 后续多会话与聊天历史持久化，当前优先以简单文件 / JSON 方案先跑通，不急于一开始就绑定 SQL schema。
- 当前判断依据：
  - 会话功能范围仍在收敛中。
  - 聊天消息 `contents` 结构仍可能继续演进。
  - 当前不计划实现 memory system，因此暂时没有很强的复杂查询需求。
- 第一阶段目标：
  - 支持多会话列表
  - 支持会话名称保存
  - 支持聊天消息恢复
  - 支持推荐结果引用恢复
- 第一阶段消息模型仍采用统一消息抽象：每条消息只有一个 `contents` 列表字段，不再额外区分 `content` 和 `timeline` 两套持久化字段。
- `contents` 当前至少需要支持：
  - `text`
  - `tool_call`
- 推荐结果第一阶段继续保持现有设计：只持久化推荐时的 subject id 列表，不冗余存完整 `Subject` 数据；会话恢复后如需展示卡片，可按 id 异步补全。
- 第一阶段持久化时机约定：
  - 用户消息在发送后立即持久化。
  - assistant 消息仅在完整回答结束后持久化。
  - 用户主动中断生成时，不持久化该轮未完成的 assistant 正文。
- 当前配置文件、图片缓存和简单缓存文件不必为了统一而立即迁入数据库；按数据类型分层存储即可。
- 如果后续会话结构逐渐稳定、数据量增长，且继续从开发体验出发需要更自然的对象持久化，可再评估迁移到 `Isar`。
- 如果未来需求重新出现更强的结构化查询、排序、筛选或复杂关系，再重新评估关系型数据库方案。

## ChatContext / 上下文压缩约定

- `ChatContext` 是给 LLM 使用的会话上下文容器，`ChatMessage` 是给 UI / 持久化使用的消息模型，两者职责不要混淆。
- 当前轮的 tool result 会在 Agent loop 内部通过 `tool` message 回灌给 LLM；历史轮默认不会完整回灌 tool result，只会通过历史构造逻辑带入压缩后的文本信息。
- 如果后续要接入 summary 系统，优先做“增量维护的 ChatContext + 最近 m 条原始消息”的方案，不要通过重写旧的 `ChatMessage.contents` 来实现压缩。
- 如果需要把 summary 也放进消息体系，默认把它视为 LLM context 专用消息，而不是普通 UI 展示消息；不要在聊天正文里直接暴露未经设计的 summary 内容。

## 页面级 Store 初始化迁移说明

- 当前共享 store 的读取方式已经收敛到 `BuildContext` extension，不再推荐：
  - `didChangeDependencies()`
  - `AppScope.of(context)`
  - 本地 `_hasBoundStore` / `_hasStartedLoading` 标志
- 后续默认做法：
  - 共享 store：直接通过 `context.xxxStore` 读取
  - 只读一次但不订阅的依赖：通过 `context.readAppDependencies.xxx` 读取
  - 页面独立实例型 store：允许保留页面字段，但优先在 `initState()` 中通过 factory 创建，并明确负责其生命周期和 `dispose()`
- 后续迁移方向：
  - 页面独立实例型 store 后续仍可继续评估外部装配或构造注入，但当前不是优先级最高的重构目标。
  - 不要继续在新页面里机械复制生命周期样板代码来读取共享依赖。
