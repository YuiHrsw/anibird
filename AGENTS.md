# Anibird Agent 指南

## 项目概况

- 这是一个 Flutter 客户端原型项目，用于展示 Bangumi 浏览能力和 LLM/Agent 交互能力。
- 当前目标是可在 macOS 上运行的 MVP，不是生产级最终架构。
- 现阶段重点是验证客户端交互、tool calling 流程和 Agent 可视化闭环。

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
- 当前状态管理使用 `ValueNotifier`、`Stream` 和 `AppScope`，不要仅为了“更标准”而迁移到 Provider。
- 当前仓库不保留 `test/` 自动化测试代码。

## 工作边界

- 优先做小步、可落地、适合原型阶段的改动，不要上来做大重构。
- 除非明确要求，否则不要优先启动这些工作：
  - 状态管理整体迁移
  - 前端大改版
  - Agent 服务端化迁移
- 如果修改聊天或 Agent 行为，保持当前线性消息流设计不变。
- 当前配置仍是本地文件持久化，不是安全存储；涉及密钥、认证、写权限时要明确这只是原型方案。

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

- 后续多会话与聊天历史持久化，当前优先采用 `sqflite + SQLite`，避免引入 codegen / build_runner。
- 第一阶段只让数据库承接会话相关数据，不要求一次性迁移现有全部本地存储。
- 第一阶段核心表先收敛为两张：
  - `chat_sessions`
  - `chat_messages`
- `chat_sessions` 先承接：
  - 会话 id
  - 会话名称
  - 创建时间
  - 更新时间
  - 最后消息时间
- `chat_messages` 先承接：
  - 消息 id
  - session id
  - sequence
  - role
  - is_error
  - created_at
  - `contents_json`
  - recommendation_subject_ids_json
- `chat_messages` 采用统一消息抽象：每条消息只有一个 `contents` 列表字段，不再额外区分 `content` 和 `timeline` 两套持久化字段。
- `contents_json` 用来保存这条消息的完整内容项序列；当前至少需要支持：
  - `text`
  - `tool_call`
- 用户消息和 assistant 消息都走统一的 `contents` 结构；assistant 的“最终显示文本”由 UI / repository 从 `contents` 中提取，而不是单独冗余存一份。
- 推荐结果第一阶段继续保持现有设计：只持久化推荐时的 subject id 列表，不在消息表中冗余存完整 `Subject` 数据；会话恢复后如需展示卡片，可按 id 再异步补全。
- 第一阶段持久化时机约定：
  - 用户消息在发送后立即持久化。
  - assistant 消息仅在完整回答结束后持久化。
  - 用户主动中断生成时，不持久化该轮未完成的 assistant 正文。
- 当前配置文件、图片缓存和简单缓存文件不必为了统一而立即迁入数据库；按数据类型分层存储即可。
- 后续如需支持导入导出，运行时仍以 SQLite 为主，导出格式可以单独设计为 JSON bundle。

## 页面级 Store 初始化迁移说明

- 当前少量页面仍保留一种过渡写法：在 `didChangeDependencies()` 中从 `AppScope` 读取 store 或 factory，并缓存到页面字段，再触发首次加载。
- 这类写法当前可以继续容忍于“页面独立实例型 store”场景，因为数量不多，且不阻塞当前原型推进。
- 但它属于过渡方案，不应继续扩散成默认模式；问题在于：
  - 页面层会重复出现样板化的依赖读取与首次加载逻辑。
  - 页面直接持有 `AppScope` 具体装配细节，耦合偏高。
  - 后续若要做响应式重组、路由复用或独立注入，迁移成本会上升。
- 后续迁移方向：
  - 全局共享型 store 允许直接从 `AppScope` 读取，不额外复制到页面字段。
  - 页面独立实例型 store 优先改为在页面外完成装配，或通过构造参数显式注入。
  - 不要继续在新页面里机械复制“`didChangeDependencies + _hasStartedLoading + AppScope.of(context)`”模板。
- 当前这部分只记录为结构债，不要求为了清理它而立即做大规模重构；后续在相关页面继续演进时顺手收敛即可。
