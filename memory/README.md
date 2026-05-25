# Project Memory Store

本目录是 Claude Code auto-memory 系统文件的项目级镜像。

## 用途

- **备份**：AI 在对话中积累的项目经验教训
- **版本控制**：记忆文件随项目一起 commit，团队共享
- **可视化**：团队成员可直接阅读这些经验教训

## 文件说明

| 文件 | 内容 |
|------|------|
| `MEMORY.md` | 记忆索引（新会话自动加载前 200 行） |
| `file-operations.md` | 文件操作陷阱（cat> 覆盖事故） |
| `skill-system-integration.md` | 技能系统集成陷阱 |
| `gdscript-runtime-pitfalls.md` | GDScript 运行时陷阱 |
| `sprite-rendering-order.md` | Sprite 渲染顺序与 alpha 策略 |

## 同步机制

记忆文件由 AI 写入系统路径：
```
C:\Users\User\.claude\projects\d--Vibe-Coding-Six-Fighters-Godot\memory\
```

本目录通过 git post-commit hook 自动同步。每次执行 `git commit` 后，hook 会将系统路径的记忆文件复制到这里，确保项目仓库始终包含最新的记忆内容。

### 手动同步

```powershell
# PowerShell
.\memory\sync.ps1
```
