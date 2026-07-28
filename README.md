# 顶栖（TopNest）

顶栖是一款常驻 Windows 11 桌面顶部的 Flutter 组件容器。当前内置 Codex、Gemini、Claude & GPT 三个额度组件，支持固定三槽布局、组件增删和拖动排序，并可继续扩展音乐等桌面组件。

## 开发命令

```powershell
C:\work\inv\flutter\bin\flutter.bat analyze
C:\work\inv\flutter\bin\flutter.bat test
C:\work\inv\flutter\bin\flutter.bat build windows --release
```

Release 输出位于 `build\windows\x64\runner\Release`。安装脚本位于 `installer\topnest.iss`。

## 数据说明

- Codex：优先读取 `%USERPROFILE%\.codex` 最近会话的本地额度事件，并通过 app-server 获取官方可用重置次数。
- Gemini、Claude & GPT：读取本机正在运行的 Antigravity language server。
- 数据读取失败时不会制造模拟额度；有旧数据则保留并标记为 stale，无旧数据则显示不可用。
