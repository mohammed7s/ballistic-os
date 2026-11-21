#!/usr/bin/env python3
"""Compile fixture Java against a header derived from the pinned public extension signature.

This is a lightweight type-contract check, NOT the Soong/metalava build or a runtime test.
No generated header/implementation is shipped in an APK. Full-tree builds must also build
computercontrol.extension.stubs.public and the fixture APK modules.
"""
import argparse
import pathlib
import re
import subprocess
import tempfile


def declarations(signature):
    package = None
    nodes = {}
    current = None
    for raw in signature.splitlines():
        line = re.sub(r"@[\w.]+(?:\([^)]*\))?\s*", "", raw.strip())
        if line.startswith("package "):
            package = line.split()[1]
        elif re.match(r"public (?:static )?(?:final )?(class|interface) ", line):
            match = re.search(r"\b(class|interface) ([\w.]+)", line)
            kind, name = match.groups()
            current = (package, name)
            nodes[current] = {"decl": line[:-1].strip(), "kind": kind, "members": []}
        elif line.startswith(("method ", "ctor ", "field ")):
            nodes[current]["members"].append(line)
    return nodes


def render(nodes, key):
    node = nodes[key]
    package, name = key
    short = name.split(".")[-1]
    declaration = re.sub(r"\b(class|interface) " + re.escape(name),
                         lambda m: m.group(1) + " " + short, node["decl"])
    lines = [declaration + " {"]
    for member in node["members"]:
        kind, member = member.split(" ", 1)
        if kind == "field":
            lines.append(member)
            continue
        member = member[:-1]  # semicolon
        if kind == "ctor":
            member = member.replace(name + "(", short + "(")
        left, args = member.split("(", 1)
        args, right = args.rsplit(")", 1)
        # Split parameter types at commas outside generic type arguments.
        params = re.split(r",(?![^<]*>)", args) if args.strip() else []
        params = [p.strip() + " arg" + str(i) for i, p in enumerate(params)]
        body = " { throw new RuntimeException(\"Contract stub\"); }"
        if kind == "ctor" and "extends android.widget.FrameLayout" in node["decl"]:
            body = " { super(arg0); throw new RuntimeException(\"Contract stub\"); }"
        if node["kind"] == "interface" and " default " not in " " + member:
            body = ";"
        lines.append(left + "(" + ", ".join(params) + ")" + right + body)
    for child in nodes:
        if child[0] == package and child[1].rpartition(".")[0] == name:
            lines.append(render(nodes, child))
    return "\n".join(lines) + "\n}\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frameworks_base", type=pathlib.Path)
    parser.add_argument("android_jar", type=pathlib.Path)
    parser.add_argument("--javac", default="javac")
    args = parser.parse_args()
    signature = args.frameworks_base / "libs/computercontrol/api_extension/current.txt"
    nodes = declarations(signature.read_text())
    with tempfile.TemporaryDirectory(prefix="computer-control-contract-") as temp:
        root = pathlib.Path(temp)
        sources = []
        for key in nodes:
            if "." in key[1]:
                continue
            source = root / "src" / key[0].replace(".", "/") / (key[1] + ".java")
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text("package " + key[0] + ";\n" + render(nodes, key))
            sources.append(source)
        subprocess.run([args.javac, "-Xlint:all,-serial", "-classpath", str(args.android_jar),
                        "-d", str(root / "headers"), *map(str, sources)], check=True)
        fixtures = pathlib.Path(__file__).resolve().parents[1] / "fixtures"
        for fixture in ("assistant", "target"):
            sources = sorted((fixtures / fixture / "src").rglob("*.java"))
            subprocess.run([args.javac, "-Xlint:all,-deprecation", "-classpath",
                            str(args.android_jar) + ":" + str(root / "headers"),
                            "-d", str(root / fixture), *map(str, sources)], check=True)
        print("PASS: full extension signature and both fixture Java sources compile against public SDK")
        print("NOT RUN: Soong/metalava, APK packaging, Settings/framework tests, device execution")


if __name__ == "__main__":
    main()
