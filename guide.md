# Report2Patch 快速流程

这个文件保留中文速查说明；正式 skill 规范以 `SKILL.md` 和 `references/` 下的文档为准。

## 适用范围

- Linux kernel
- 内存管理或对象生命周期相关问题
- 初始信号来自静态分析
- 目标是生成 patch bundle，而不是只做诊断

## 默认输入

- 对话里直接提供 `bug_report_text`
- 显式提供 `kernel_tree`
- 显式提供 `base_branch`
- 显式提供 `work_branch`
- 显式提供 `patch_output_dir`
- 显式提供 `kasan_artifact_dir`
  这个目录除了放 pre-fix / post-fix 日志，也要承载派生文件 `${kasan_artifact_dir}/failure-notes.md`

当前工作区的推荐约定：

- `patch_output_dir=/home/gzl/linux/patch`
- `kasan_artifact_dir` 按具体 bug 单独命名，例如 `/tmp/rbd_add_disk_uaf` 或 `/tmp/<function-or-bug-tag>`
- `patch_output_dir` 和 `kasan_artifact_dir` 如果不存在，可以先 `mkdir -p`

可选项：

- `signed_off`
- `repro_scripts_dir`
- `commit_template_path`
- `extra_context_files`

## 默认交互

- 自动执行大部分流程
- 只在“修改方案 + commit 草案”准备好后暂停一次
- 用户回复继续后，再进入代码修改、patch 生成和收件人整理

## 主流程

1. 解析 report，确认在 skill 适用范围内
2. 检查环境和输入参数
3. 同步 `work_branch`，不要直接在 `main/master` 上改
4. 尽量做修复前动态复现，并把日志存到 `kasan_artifact_dir/pre-fix`
5. 生成修改方案和 commit 草案，等待用户确认
6. 落实修复并编译验证
7. 尽量做修复后动态复现，日志存到 `kasan_artifact_dir/post-fix`
   如果环境、编译或调用过程出现阻断性错误，把失败说明写到 `${kasan_artifact_dir}/failure-notes.md`
8. 生成 commit
   commit 信息从 `Subject:` 开始生成，不要把前面的 `From:`、`Date:` 或 `From <sha> Mon Sep 17 00:00:00 2001` 这类邮件头一起带进去
9. 生成 patch
10. 跑 `scripts/checkpatch.pl`
11. 跑 `scripts/get_maintainer.pl`
12. 汇总 patch、验证结论和收件人信息

## 降级规则

- 缺少必填输入时，先停下补信息
- 复现或复测如果实际执行了但失败，且编译成功，结论记为 `build-only`
- 如果明确不建议复现，或者本次决定跳过运行时验证，结论记为 `not-runtime-verified`
- 只有复现前后证据完整时，才能标成 `runtime-verified`
- 环境、编译、调用过程里的阻断性错误，要记录到 `${kasan_artifact_dir}/failure-notes.md`，至少写清 step, cause, and context

## 最终产物

- commit message
- `git format-patch` 输出路径
- `checkpatch.pl` 结果摘要
- `get_maintainer.pl` 收件人列表
- 运行时验证结论
- 修复前后日志路径（如果跑过）
- `${kasan_artifact_dir}/failure-notes.md` 路径（如果记录过阻断性错误）

## 参考文件

- `references/input-contract.md`
- `references/workflow-state-machine.md`
- `references/output-bundle.md`
- `references/failure-notes-template.md`
- `references/commit_example.txt`
- `references/example/README.md`
- `ARCHITECTURE.md`
