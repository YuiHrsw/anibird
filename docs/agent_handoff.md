# Anibird Agent Handoff

## 项目概况

- 项目类型：Flutter 客户端个人项目，用于展示 Bangumi 第三方客户端 + LLM/Agent 交互能力
- 当前目标：客户端 MVP，可在 macOS 上运行，完成 Bangumi 浏览、搜索、详情、单集查看、LLM 推荐问答
- 当前定位：原型验证优先，重点展示客户端交互、Agent 可视化、工具调用链路，不是最终生产架构

## 当前目录结构

```text
lib/
├── app/
│   ├── app.dart
│   ├── app_scope.dart
│   └── bootstrap.dart
├── backend/
│   ├── api/
│   │   ├── bangumi/
│   │   ├── config/
│   │   └── llm/
│   ├── models/
│   └── services/
└── ui/
    ├── pages/
    ├── state/
    └── widgets/
```

补充：

- `bangumi_api/` 是克隆下来的 Bangumi API/OpenAPI 参考仓库，不是运行时依赖
- `test/` 目录中的测试文件已全部移除，当前项目不保留测试代码

## 当前已完成能力

### 1. Bangumi 只读能力

已实现并接入：

- 搜索条目
- 按 tag 搜索条目
- 获取条目详情
- 获取关联作品
- 获取角色
- 获取人物/制作人员
- 浏览条目
- 获取单集列表
- 获取单集详情

关键文件：

- [bangumi_api_client.dart](/Users/gche/repos/anibird/lib/backend/api/bangumi/bangumi_api_client.dart)
- [bangumi_repository.dart](/Users/gche/repos/anibird/lib/backend/api/bangumi_repository.dart)
- [episode.dart](/Users/gche/repos/anibird/lib/backend/models/episode.dart)

注意：

- 请求体统一用 UTF-8 bytes 发送，避免中文 JSON 导致 `Contains invalid characters`
- Bangumi query string 现在会自动过滤 `null` 值，避免把 `type=null` 这种无效参数发给服务端
- `BangumiRepositoryImpl` 和对应 parse 测试已移除，`BangumiRepository` 现在就是唯一的具体实现类

### 2. LLM 接入

已实现：

- OpenAI compatible provider
- 流式输出
- 基础日志
- 请求 URL 规范化
- SSE 增量解析
- 原生 function calling 请求/响应处理

关键文件：

- [openai_compatible_llm_provider.dart](/Users/gche/repos/anibird/lib/backend/api/llm/openai_compatible_llm_provider.dart)
- [llm_provider.dart](/Users/gche/repos/anibird/lib/backend/services/llm_provider.dart)

说明：

- 当前只支持文本输入 + function calling
- 没有多模态上传、图片输入或视觉模型接入
- `LlmProvider` 抽象已移除，`Agent` 直接依赖 `OpenAICompatibleLlmProvider`

### 3. Agent

当前实现是客户端侧的 function calling Agent loop：

- 请求体带 `tools`
- 模型通过 `tool_calls` 触发工具调用
- 客户端执行工具后用 `role=tool` 回填 observation
- assistant 文本与工具调用统一组织为 timeline
- 所有可见消息都按线性消息流在 UI 展示

关键文件：

- [agent.dart](/Users/gche/repos/anibird/lib/backend/services/agent.dart)
- [bangumi_tools.dart](/Users/gche/repos/anibird/lib/backend/services/bangumi_tools.dart)
- [tool.dart](/Users/gche/repos/anibird/lib/backend/models/tool.dart)

当前工具列表：

- `search_anime`
- `search_subjects_by_tags`
- `get_subject_detail`
- `get_related_subjects`
- `get_subject_cast`
- `get_subject_episodes`
- `get_episode_detail`
- `browse_subjects`
- `present_recommendations`

当前行为特点：

- Agent loop 已收敛成 message-driven 结构
- `present_recommendations` 是可选的，不再强制调用
- 工具错误会结构化回馈给模型，模型自行决定继续调用、调整参数或直接回答
- 搜索类工具支持 `limit`
- 搜索排序做了合法值收口
- 已移除 recommendation/finalization/retry/max-turn 等运行时特判
- 当前 `AgentReplyUpdate` 只保留：
  - `timeline`
  - `recommendations`
  - `isFinal`
- `timeline` 是当前真正的消息主通道：
  - `assistant`
  - `toolCall`
- `AgentReply` 和非流式 `sendUserMessage()` 已删除
- Agent 仍然完全运行在客户端

### 4. UI

当前页面：

- 发现页
- 聊天页
- 设置页
- 条目详情页

关键文件：

- [home_page.dart](/Users/gche/repos/anibird/lib/ui/pages/home_page.dart)
- [discovery_page.dart](/Users/gche/repos/anibird/lib/ui/pages/discovery_page.dart)
- [chat_page.dart](/Users/gche/repos/anibird/lib/ui/pages/chat_page.dart)
- [settings_page.dart](/Users/gche/repos/anibird/lib/ui/pages/settings_page.dart)
- [subject_detail_page.dart](/Users/gche/repos/anibird/lib/ui/pages/subject_detail_page.dart)

聊天页当前特性：

- `CustomScrollView + Sliver` 实现
- 所有 assistant 文本按 timeline 线性显示
- 工具调用在线性消息流中显示为普通链接文本：`调用 xxx`
- 点击工具调用可弹窗查看 `Action / Observation`
- “停止生成”按钮
- 不再显示 `thought`
- 不再使用旧的 ReAct 折叠框/步骤列表组件
- 推荐卡片附着在当前 assistant 消息下方
- 自动滚动只在用户当前位于底部附近时触发
- 工具调用默认无气泡背景
- assistant 最终文本与中间 assistant 文本现在统一按消息流展示，不再走单独 `text` 通道

详情页当前特性：

- 条目基础信息
- 角色阵容
- 制作人员
- 关联作品
- 单集列表
- 点击单集后弹出单集详情底部弹窗

### 5. 配置

已实现：

- LLM base URL / API key / model 配置
- Bangumi user agent 等基础配置
- 本地文件持久化

关键文件：

- [app_config.dart](/Users/gche/repos/anibird/lib/backend/models/app_config.dart)
- [file_config_repository.dart](/Users/gche/repos/anibird/lib/backend/api/config/file_config_repository.dart)
- [settings_store.dart](/Users/gche/repos/anibird/lib/ui/state/settings_store.dart)

注意：

- 配置持久化还是本地文件方案，不是安全存储
- `ConfigRepository` 抽象已移除，`SettingsStore` 直接依赖 `FileConfigRepository`

## 当前状态管理方案

目前使用轻量原生响应式方案：

- `ValueNotifier + ValueListenableBuilder`
- `Stream + StreamBuilder`
- `AppScope` 注入应用级共享依赖

相关文件：

- [app_scope.dart](/Users/gche/repos/anibird/lib/app/app_scope.dart)
- [discovery_store.dart](/Users/gche/repos/anibird/lib/ui/state/discovery_store.dart)
- [chat_store.dart](/Users/gche/repos/anibird/lib/ui/state/chat_store.dart)
- [settings_store.dart](/Users/gche/repos/anibird/lib/ui/state/settings_store.dart)
- [subject_detail_store.dart](/Users/gche/repos/anibird/lib/ui/state/subject_detail_store.dart)

说明：

- 页面级快照状态基本已迁到 `ui/state`
- 聊天页使用 `StreamBuilder` 驱动消息区
- 发现页 / 设置页 / 详情页使用 `ValueListenableBuilder`
- 当前 `AppScope` 更像轻量依赖注入容器，不是 controller
- 当前阶段不建议为“更标准”而专门迁到 Provider
- 如果未来真的要升级状态管理，优先重新评估 Riverpod，而不是先迁 Provider

## 最近完成的重要改动

- 目录重构完成：从旧的 `application/domain/infrastructure` 收敛到 `ui/backend`
- 旧 `ChangeNotifier + AnimatedBuilder` controller 方案已移除
- Bangumi episode API 已接入，并暴露给 UI 和 Agent
- 详情页增加单集列表和单集详情弹窗
- `BangumiRepositoryImpl` 已移除
- `ConfigRepository` / `LlmProvider` 接口层已移除
- 全部测试文件已移除
- Agent 已从“文本 ReAct JSON 协议”迁到原生 function calling
- `present_recommendations` 优化为优先复用已拿到的 `Subject` 缓存，并允许部分成功
- 详情页提前退出时，已修复 `SubjectDetailStore` dispose 后异步回写崩溃
- Agent loop 已重构为更短的 message-driven function-calling loop
- `steps`、`toolTraces`、`processText`、`statusText` 已从主消息/UI链路移除
- `ChatMessage` 当前主字段已收敛为：
  - `content`（用户/错误消息）
  - `timeline`
  - `recommendations`
  - `isLoading / isError`
- 聊天页已改成线性消息流 UI，不再使用旧的 ReAct 折叠面板

## 已修复过的重要问题

- macOS 出站网络权限缺失
- 详情页点击卡死
- LLM 中文请求体发送时报 `Contains invalid characters`
- Bangumi 中文搜索请求体同类编码问题
- OpenAI compatible tool/response 协议兼容问题
- SSE 流式输出重复生成前缀消息气泡
- TLS 图片握手失败时 UI 缺少兜底
- 推荐卡片与正文不一致
- “正在调用工具”状态覆盖正文
- ReAct 面板过长、内容过重的问题
- 推荐卡片布局 overflow
- episode 列表请求时错误发送 `type=null` 导致 Bangumi 400
- Widget Inspector 触发 `late final _store` 二次初始化崩溃
- 详情页未加载完就退出导致 `SubjectDetailStore was used after being disposed`
- recommendation 工具末尾补详情时，单次 TLS/握手失败导致整组推荐卡片失败
- 最终正文跑进工具调用 Thought、final answer 只剩一句总结的问题
- 聊天气泡下方多余的 loading 状态条闪现
- 工具调用与中间 assistant 文本顺序错乱的问题
- 工具调用仍保留卡片背景、不符合线性消息流设计的问题

## 当前明确存在的取舍/不足

### 架构

- `AppScope + AppDependencies` 仍然是应用级共享依赖容器，粒度偏粗
- 当前方案够轻，但继续扩张会逐渐接近“手写 provider”
- 还没有切到更成熟的 DI / state management 框架（如 Riverpod）

### Agent

- ReAct 仍然跑在客户端
- LLM 调用仍在客户端
- API key / base URL 仍由客户端本地维护
- 这是原型方案，不是最终生产设计
- 当前 assistant 文本和 tool call 已统一进 timeline，但对“最终答案提交边界”还没有单独协议动作
- 目前仍可能出现“模型在调用 recommendation 前先输出较长正文”的问题，当前主要通过 prompt 约束缓解
- 本地 Agent 中断后，不支持真正恢复未完成轮次；设计上更接近“保住用户输入，丢弃未完成回复”

### 数据能力

- 目前没有番剧评论正文 / 单集评论正文 API 接入
- 只有评论数，不支持评论列表展示
- 没有多模态输入支持

### 弱网与恢复

- 当前没有会话级断点恢复
- 断网后不能从“第 N 步 Observation”继续跑
- 失败后只能保留已显示内容与错误态，无法精确续传
- Bangumi API 目前只做了 recommendation 补全链路的局部稳健化，还没有统一的网络重试/退避策略

### 配置/安全

- API key 还没迁到安全存储
- 没有 OAuth
- 没有写操作权限边界体系
- 会话数据仍未正式持久化到本地数据库
- 还没有多会话支持与会话恢复

### 测试与质量保障

- 当前项目不保留测试代码
- 目前校验主要依赖 `flutter analyze` 和手工验证

## 当前测试与校验

最近已通过：

- `flutter analyze`

说明：

- `flutter test` 已无测试文件可跑
- 当前仓库没有自动化测试覆盖

## 面试相关结论

当前项目建议统一口径：

- 这是个人学习项目，但按可演示、可迭代的 MVP 来做
- 当前 Agent 放在客户端是为了快速验证交互闭环
- 真正产品化时，主 Agent 更适合迁到服务端
- 客户端重点展示的是：
  - function calling 驱动的 ReAct 闭环
  - 线性消息流渲染
  - 页面状态管理
  - tool call / observation 可视化
  - 推荐结果与消息流联动
  - 错误态与中断处理
  - 单集列表与单集详情交互

## 下一步推荐工作

优先级从高到低建议如下：

1. 会话数据持久化
   - 引入 `drift + SQLite`
   - 建立：
     - `sessions`
     - `messages`
     - `timeline_items`
     - `message_recommendations`
   - 目标是多会话、历史恢复、本地缓存

2. 网络层升级
   - 迁到 `Dio`
   - 为后续 multi-host / OAuth / interceptor / retry / cancel 做准备

3. Bangumi 后端能力分层
   - 不再继续扩张单一大 repository
   - 拆成：
     - `SearchApi`
     - `SubjectApi`
     - `EpisodeApi`
     - `UserApi`
     - `CollectionApi`
     - `AuthApi`
   - 上层增加一个统一的 `BangumiGateway`

4. 认证模块独立
   - OAuth 作为横切能力独立出来
   - 不和 public/private API 强绑定
   - 规划：
     - `AuthSession`
     - `TokenRepository`
     - `BangumiAuthApi`
     - `AuthService/AuthStore`

5. 会话/Agent 数据流继续收敛
   - 保持 message-driven loop
   - 如果后面要继续解决“最终答案边界”，优先考虑协议层动作，而不是再加业务特判

6. 评估导航结构升级
   - 主 Tab 后续若要独立保存状态和子页面栈，采用：
     - `IndexedStack`
     - 每个 Tab 一个独立 `Navigator`

## 建议下一个 Agent 先做什么

如果下一个 Agent 接手，建议先从“后端基础设施”开始，而不是继续动聊天页表现层：

1. 先设计本地会话数据表结构和 `SessionRepository`
2. 再评估并落地 `Dio` 迁移
3. 梳理 Bangumi public/private API 的能力映射
4. 预留 OAuth 模块边界，但不要先把 UI 做复杂
5. 当前不建议一上来同时做：
   - Riverpod 迁移
   - 服务端化 Agent
   - private API 全量替换
   - 大规模前端重写

优先把数据存储、网络层、auth/API 分层这三块地基收稳。
