# Report2Patch 快速流程

这个文件保留中文速查说明；正式 skill 规范以 `SKILL.md`、`specs/` 和 `templates/` 下的文档为准。

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

- `patch_output_dir=$PWD/patch`
- `kasan_artifact_dir` 按具体 bug 单独命名，例如 `/tmp/rbd_add_disk_uaf` 或 `/tmp/<function-or-bug-tag>`
- `patch_output_dir` 和 `kasan_artifact_dir` 如果不存在，可以先 `mkdir -p`
- 默认值集中写在 `report2patch.yaml`
- commit 草稿写入 `tools/testing/report2patch/bug函数名称/commit.md`

可选项：

- `signed_off`
- `repro_scripts_dir`
- `commit_template_path`
- `extra_context_files`

## 默认交互

- 自动执行大部分流程
- 必须显示让用户审核代码修改方案 + commit 草案
- 用户必须明确通过后，才能继续后续 commit 和 patch 的生成

## 主流程

1. 解析 report，确认在 skill 适用范围内
2. 检查环境和输入参数
3. 先切到 `base_branch`
4. 对 `base_branch` 执行 `git pull --ff-only`
5. 处理新 bug 时，在 Linux 仓库里新建一个以 bug 函数命名的 branch，并把这个函数名作为 `work_branch`；不要直接在 `main/master` 上改
6. 让 `work_branch` rebase 到更新后的 `base_branch`
7. 进行动态测试时，请你通过配置正确的 Linux 编译选项，并在 QEMU（密码为 `root`）上运行得到 KASAN 的报告，同时记录完整可复现的流程到 `${kasan_artifact_dir}/repro-steps.md`
8. 保存修复前动态复现日志到 `kasan_artifact_dir/pre-fix`
9. 生成修改方案和 commit 草案，并写入 `tools/testing/report2patch/bug函数名称/commit.md`
10. `commit.md` 里要包括：主题、参考 `references/commit_example.txt` 的描述、可自定义的 `signed off`，以及该 bug 要抄送的对象
11. 显示让用户审核代码修改方案 + commit 草案
12. 用户必须明确通过后，才能继续后续 commit 和 patch 的生成
13. 落实修复并编译验证
14. 尽量做修复后动态复现，日志存到 `kasan_artifact_dir/post-fix`，并把复现后的完整流程继续写回 `${kasan_artifact_dir}/repro-steps.md`
   如果环境、编译或调用过程出现阻断性错误，把失败说明写到 `${kasan_artifact_dir}/failure-notes.md`
15. 生成 commit
   commit 信息从 `Subject:` 开始生成，不要把前面的 `From:`、`Date:` 或 `From <sha> Mon Sep 17 00:00:00 2001` 这类邮件头一起带进去
16. 对 commit 内容做一次自检，检查是否符合 Linux patch 常见提交规范
17. 自检通过后再生成 patch
18. 跑 `scripts/checkpatch.pl`
19. 跑 `scripts/get_maintainer.pl`
20. 汇总 patch、验证结论和收件人信息

## 降级规则

- 缺少必填输入时，先停下补信息
- 复现或复测如果实际执行了但失败，且编译成功，结论记为 `build-only`
- 如果明确不建议复现，或者本次决定跳过运行时验证，结论记为 `not-runtime-verified`
- 只有复现前后证据完整时，才能标成 `runtime-verified`
- 环境、编译、调用过程里的阻断性错误，要记录到 `${kasan_artifact_dir}/failure-notes.md`，至少写清 step, cause, and context

## 最终产物

- commit message
- `tools/testing/report2patch/bug函数名称/commit.md` 路径
- `git format-patch` 输出路径
- `checkpatch.pl` 结果摘要
- `get_maintainer.pl` 收件人列表
- 运行时验证结论
- 修复前后日志路径（如果跑过）
- `${kasan_artifact_dir}/repro-steps.md` 路径（如果跑过动态测试）
- `${kasan_artifact_dir}/failure-notes.md` 路径（如果记录过阻断性错误）

## 参考文件

- `specs/input-contract.md`
- `specs/workflow-state-machine.md`
- `specs/output-bundle.md`
- `templates/commit-draft-template.md`
- `templates/failure-notes-template.md`
- `references/commit_example.txt`
- `references/example/README.md`
- `ARCHITECTURE.md`
- `report2patch.yaml`
