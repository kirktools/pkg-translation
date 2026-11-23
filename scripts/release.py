#!/usr/bin/env python3
"""预览或发布 Swift Package 的 Git 版本标签。"""

import argparse
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "kirktools/pkg-translation"
VERSION = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")
MASTER = "refs/heads/master"
BUMP_INDEX = {"major": 0, "minor": 1, "patch": 2}


def git(*args, output=True):
    return subprocess.run(["git", *args], cwd=ROOT, text=True, check=True,
                          stdout=subprocess.PIPE if output else None).stdout


def check_origin(direction):
    args = ("--push",) if direction == "push" else ()
    urls = git("remote", "get-url", *args, "--all", "origin").splitlines()
    allowed = {
        f"{prefix}{REPOSITORY}{suffix}"
        for prefix in ("https://github.com/", "git@github.com:", "ssh://git@github.com/")
        for suffix in ("", ".git")
    }
    if len(urls) != 1 or urls[0] not in allowed:
        raise ValueError(f"origin 的 {direction} 地址必须唯一且指向 {REPOSITORY}")


def next_version(bump):
    tags = git("tag", "--list").splitlines()
    previous = max((tuple(map(int, tag.split("."))) for tag in tags if VERSION.fullmatch(tag)),
                   default=None)
    if previous is None:
        return "0.1.0"
    parts = list(previous)
    index = BUMP_INDEX[bump]
    parts[index] += 1
    for remaining in range(index + 1, len(parts)):
        parts[remaining] = 0
    return ".".join(map(str, parts))


def clean():
    return not git("status", "--porcelain=v1", "--untracked-files=all").strip()


def head():
    return git("rev-parse", "--verify", "HEAD").strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="仅预览本地状态")
    args = parser.parse_args()
    bump = os.environ.get("BUMP", "patch")
    if bump not in BUMP_INDEX:
        raise ValueError("BUMP 仅支持 patch、minor、major")
    if git("branch", "--show-current").strip() != "master":
        raise ValueError("请在 master 分支发布")
    check_origin("fetch")
    check_origin("push")
    if args.dry_run:
        print(f"预计标签：{next_version(bump)}（基于本地标签）")
        if not clean():
            print("工作区或暂存区有改动。正式发布前需准备好源代码提交。")
        print("正式发布会核对远端、运行 swift test 和 Release 构建，再原子推送 master 与标签。")
        return

    if not clean():
        raise ValueError("工作区或暂存区有改动，请先处理")
    revision = head()
    remote_refs = git("ls-remote", "--heads", "--tags", "origin")
    refs = dict(line.split("\t", 1)[::-1] for line in remote_refs.splitlines())
    if MASTER not in refs and refs:
        raise ValueError("远端已有分支或标签，但缺少 master，请先核对")
    git("fetch", "--tags", "origin", output=False)
    if MASTER in refs:
        git("fetch", "--no-tags", "origin", MASTER, output=False)
        git("merge-base", "--is-ancestor", git("rev-parse", "FETCH_HEAD").strip(), revision)
    tag = next_version(bump)
    push = ["git", "push", "--atomic", "--no-follow-tags", "origin", f"{revision}:{MASTER}", f"refs/tags/{tag}"]
    existing = [tag for tag in git("tag", "--points-at", revision).splitlines() if VERSION.fullmatch(tag)]
    if existing:
        raise ValueError(f"当前提交已打标签 {', '.join(existing)}。如上次推送失败，请按之前输出的命令重试")
    # 未推送的正式版标签可能来自其他提交上的中断发布。
    pending = [tag for tag in git("tag", "--list").splitlines()
               if VERSION.fullmatch(tag) and f"refs/tags/{tag}" not in refs]
    if pending:
        raise ValueError(f"发现尚未发布的本地标签 {', '.join(pending)}，请先处理")
    if f"refs/tags/{tag}" in refs:
        raise ValueError(f"远端标签 {tag} 已存在")

    print(f"发布候选：{tag}（{revision[:12]}）", flush=True)
    build = ["--force-resolved-versions"] if (ROOT / "Package.resolved").is_file() else []
    subprocess.run(["swift", "test", *build], cwd=ROOT, check=True)
    subprocess.run(["swift", "build", "-c", "release", *build], cwd=ROOT, check=True)
    if head() != revision or not clean():
        raise ValueError("构建期间提交、工作区或暂存区发生变化")

    git("tag", "-a", tag, revision, "-m", f"{REPOSITORY} {tag}", output=False)
    print(f"若推送失败，修复原因后重试：{shlex.join(push)}", flush=True)
    subprocess.run(push, cwd=ROOT, check=True)
    print(f"已发布 Swift Package {tag}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"发布停止：{error}", file=sys.stderr)
        sys.exit(1)
