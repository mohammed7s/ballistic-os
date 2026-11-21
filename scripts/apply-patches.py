#!/usr/bin/env python3
"""Apply the recipe only to pinned sources or an exact prefix of this patch series."""
import argparse
import json
import pathlib
import subprocess

RECIPE = pathlib.Path(__file__).resolve().parents[1]


def git(project, *args, data=None):
    return subprocess.check_output(["git", "-C", str(project), *args], input=data).decode().strip()


def patch_id(project, patch):
    result = git(project, "patch-id", "--stable", data=patch)
    if not result:
        raise RuntimeError("Empty patch is not supported")
    return result.split()[0]


def apply(source):
    pins = json.loads((RECIPE / "source-pins.json").read_text())
    if pins["tag"] != (RECIPE / "MANIFEST").read_text().strip():
        raise RuntimeError("MANIFEST and source-pins.json disagree")
    pending = []
    # Audit all projects before mutating any of them. Never reset/rebase someone else's work.
    for path, base in pins["projects"].items():
        project = source / path
        if git(project, "status", "--porcelain"):
            raise RuntimeError(f"Dirty source project: {project}")
        subprocess.run(["git", "-C", str(project), "merge-base", "--is-ancestor", base, "HEAD"], check=True)
        patches = sorted((RECIPE / "patches" / path.replace("/", "_")).glob("*.patch"))
        commits = git(project, "rev-list", "--reverse", "--first-parent", f"{base}..HEAD").splitlines()
        if len(commits) > len(patches):
            raise RuntimeError(f"Unexpected commits above pinned base: {project}")
        for commit, patch in zip(commits, patches):
            actual = git(project, "show", "--format=email", "--binary", commit).encode()
            if patch_id(project, actual) != patch_id(project, patch.read_bytes()):
                raise RuntimeError(f"Source is not an exact recipe prefix: {project} at {commit}")
        pending.append((project, patches[len(commits):]))
    for project, patches in pending:
        for patch in patches:
            subprocess.run(["git", "-C", str(project), "am", str(patch)], check=True)
        print(f"Verified/applied: {project}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=pathlib.Path)
    apply(parser.parse_args().source.resolve())
