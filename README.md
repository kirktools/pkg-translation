# KirkTranslation

面向 macOS 的共享翻译 Swift Package，最低部署目标为 macOS 14，Swift 工具链要求 6.0。Apple 的本机翻译 API 需要 macOS 15，调用方应保留系统可用性判断。

- `KirkTranslation` 提供 ChatGPT 授权、OpenAI 兼容翻译、系统翻译适配及句段配对，并支持通过相同授权发送显式构造的 PNG 分析请求。网络阶段通过回调提供给宿主。
- `KirkTranslationUI` 提供源自 Screenshot 的上下排列的原文与译文组件。两侧支持选中与复制，悬停时联动高亮。传入原文编辑回调即可粘贴或修改原文。原文变更后，由宿主使旧译文和配对失效。
- 宿主注入本地化标题和复制文案，管理窗口、选区、权限、主按钮和翻译触发时机。使用 `ImageAnalysis` 时，由宿主决定提示词、取得用户发送确认并提供 PNG；共享包负责验证输入大小及构造供应商请求。

## 授权兼容

`ChatGPTPlan` 由宿主显式传入 `service`、`applicationName` 和 `hostPreferenceKey`。会话目录和旧钥匙串查询仍由原有 `service` 推导，注册信息继续随各自的会话保存。以后迁移时应使用各宿主原有值。

| 宿主 | 保留的服务名推导 | 授权名称 | 既有偏好键 |
| --- | --- | --- | --- |
| Screenshot | App Bundle ID 加 `.translation` | `Screenshot` | `capture.translation.chatgpt.host` |
| Hotkey | 翻译插件 Bundle ID 加 `.translation` | `Hotkey` 或 `Hotkey Dev` | 服务名加 `.chatgpt.host` |

Screenshot Dev 与正式版原本就在不同偏好域；Hotkey 应继续使用各自插件的 Bundle ID。保留稳定的 Bundle ID 和签名，并在接入时验证已有授权的读取行为。

运行 `swift test` 验证合成响应、会话读写及文本配对。回环测试需要本机 TCP 监听。后续发布通过此 Git 仓库的 SemVer 标签；宿主固定版本后记录解析结果。源码沿用 MIT 许可证。

## 发布 Swift Package

`make release-dry-run` 仅根据本地标签预览版本。首次发布为 `0.1.0`，以后默认递增 patch，可用 `BUMP=minor` 或 `BUMP=major` 调整。

先将要发布的源码提交到本地 `master`。运行 `make release` 即确认发布。脚本会校验工作区和远端状态，运行测试和 Release 构建，在已验证的提交上创建 SemVer 标签，再原子推送 `master` 和该标签。包版本以 Git 标签为准。

如果推送失败，修复原因后执行脚本输出的原命令，重试同一个提交和标签。
