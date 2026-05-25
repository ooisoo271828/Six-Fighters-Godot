---
name: file-operations
description: 写文件前必须确认文件存在。cat> 和 Write 工具的误用导致过 1641 行文档被覆盖。
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bc79e782-1c8a-48ad-8dcd-6daf37732708
---

写文件前先 `git log --oneline -- <file>` 和 `ls -l <file>` 确认文件状态。

Write 工具报 "File has not been read yet" **不等于**文件不存在——它意味着本对话中还没 Read 过该文件，不代表磁盘上没有。

绝对禁止用 `cat >` 覆盖已有文件——Bash 的 `>` 重定向会无条件截断目标。

用户说"汇总到 XXX 文件"时，默认该文件已存在且有内容，先查 git 历史再操作。

**Why:** 实际事故：1641 行的 pitfall guide 被 `cat >` 截断覆盖，仅靠 git 恢复。
**How to apply:** 每次写文件前，先 git log + ls -l 双检查。优先用 Edit 追加而非 Write 全量覆盖。
