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
- 工具/响应 JSON 解析

关键文件：

- [openai_compatible_llm_provider.dart](/Users/gche/repos/anibird/lib/backend/api/llm/openai_compatible_llm_provider.dart)
- [llm_provider.dart](/Users/gche/repos/anibird/lib/backend/services/llm_provider.dart)

说明：

- 当前只支持文本输入 + tool calling
- 没有多模态上传、图片输入或视觉模型接入
- `LlmProvider` 抽象已移除，`Agent` 直接依赖 `OpenAICompatibleLlmProvider`

### 3. Agent

当前实现是显式 ReAct 风格的本地 Agent loop：

- 模型输出 JSON 决策
- 客户端按步骤执行工具
- 工具结果作为 Observation 回给模型
- 最后输出 `final_answer`

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

- `present_recommendations` 是可选的，不再强制调用
- 工具错误会结构化回馈给模型，让模型自行修正参数重试
- 搜索类工具支持 `limit`
- 搜索排序做了合法值收口
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
- Markdown 渲染
- 流式回答
- “停止生成”按钮
- ReAct 过程显示在气泡外部上方，默认折叠
- ReAct 每一步点开弹窗查看 `Thought / Action / Observation`
- 推荐卡片在最终回答完成后才显示
- 推荐卡片区域已从气泡中独立出来
- 自动滚动只在用户当前位于底部附近时触发

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

## 最近完成的重要改动

- 目录重构完成：从旧的 `application/domain/infrastructure` 收敛到 `ui/backend`
- 旧 `ChangeNotifier + AnimatedBuilder` controller 方案已移除
- Bangumi episode API 已接入，并暴露给 UI 和 Agent
- 详情页增加单集列表和单集详情弹窗
- `BangumiRepositoryImpl` 已移除
- `ConfigRepository` / `LlmProvider` 接口层已移除
- 全部测试文件已移除

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

### 数据能力

- 目前没有番剧评论正文 / 单集评论正文 API 接入
- 只有评论数，不支持评论列表展示
- 没有多模态输入支持

### 弱网与恢复

- 当前没有会话级断点恢复
- 断网后不能从“第 N 步 Observation”继续跑
- 失败后只能保留已显示内容与错误态，无法精确续传

### 配置/安全

- API key 还没迁到安全存储
- 没有 OAuth
- 没有写操作权限边界体系

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
  - 流式渲染
  - 页面状态管理
  - ReAct 过程可视化
  - 推荐结果与正文联动
  - 错误态与中断处理
  - 单集列表与单集详情交互

## 下一步推荐工作

优先级从高到低建议如下：

1. 继续梳理依赖注入与状态管理边界
   - 评估是否切到 Riverpod/Provider
   - 避免 `AppDependencies` 继续膨胀

2. 重新梳理 Agent 与客户端边界
   - 准备服务端化方案
   - 客户端只保留展示与本地动作执行

3. 补更强的恢复与弱网方案
   - session/turn/action 状态建模
   - 中断恢复
   - pending action

4. 配置安全化
   - API key 改为安全存储

5. 评估是否需要重新引入少量高价值测试
   - 仅保留能挡住真实回归的少量测试

## 建议下一个 Agent 先做什么

如果下一个 Agent 接手，建议先从“继续收敛架构边界，不改核心行为”开始：

1. 明确 `AppScope` 是否继续保留
2. 如果继续扩展功能，优先按 feature 维度而不是再堆全局依赖
3. 如果要继续加 LLM 能力，先决定是否支持多模态
4. 不建议一上来同时做：
   - 服务端化
   - 状态管理框架迁移
   - 大规模 UI 重做

否则容易把当前可运行闭环重新打散。
