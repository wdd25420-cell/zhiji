# Quality Gate Hook — 知记项目

## 规则
1. 任务必须按 ID 从小到大顺序执行，不得跳号
2. 每个任务必须输出 `✅ [ID] 标题 — 通过/blocked` 带证据
3. 工具调用失败必须重试至少 1 次，2 次仍失败才标记 blocked
4. 不得写"已完成"而不给具体输出/行号/文件路径作为证据
5. flutter analyze 和 flutter test 在每次编辑后必须重新运行验证
6. blocked 任务需写明原因，后续任务继续，不得因一个 blocked 停下全部
7. 连续 3 个 blocked 暂停请求人工介入
