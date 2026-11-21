#!/usr/bin/env python3
"""Lightweight clean git-am check using existing research clones, without fetching source."""
import argparse
import json
import pathlib
import subprocess
import tempfile

RECIPE = pathlib.Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("clones", type=pathlib.Path, help="Directory containing platform_* research clones")
    args = parser.parse_args()
    pins = json.loads((RECIPE / "source-pins.json").read_text())["projects"]
    with tempfile.TemporaryDirectory(prefix="computer-control-apply-") as temp:
        source = pathlib.Path(temp)
        for path, base in pins.items():
            repository = args.clones / ("platform_" + path.replace("/", "_"))
            destination = source / path
            subprocess.run(["git", "clone", "--quiet", "--shared", "--no-checkout", str(repository), str(destination)], check=True)
            patches = sorted((RECIPE / "patches" / path.replace("/", "_")).glob("*.patch"))
            files = sorted({line.split(" b/", 1)[1] for patch in patches
                            for line in patch.read_text().splitlines() if line.startswith("diff --git ")})
            # Include only files touched by the series. The index still contains the entire base.
            subprocess.run(["git", "-C", str(destination), "sparse-checkout", "set", "--no-cone", "--stdin"],
                           input="\n".join("/" + file for file in files).encode(), check=True)
            subprocess.run(["git", "-C", str(destination), "checkout", "--quiet", "-b", "verify", base], check=True)
        command = ["python3", str(RECIPE / "scripts/apply-patches.py"), str(source)]
        subprocess.run(command, check=True)
        subprocess.run(command, check=True)  # Re-running must recognize the exact prefix.
        for path in pins:
            tree = subprocess.check_output(["git", "-C", str(source / path), "rev-parse", "HEAD^{tree}"]).decode().strip()
            print(f"PASS clean git am + idempotence: {path}; tree {tree}")
        # Refuse dirty checkouts before applying anything.
        marker = source / "frameworks/base/.unrelated-work"
        marker.write_text("preserve me\n")
        rejected = subprocess.run(command, capture_output=True, text=True)
        assert rejected.returncode != 0 and "Dirty source project" in rejected.stderr
        assert marker.read_text() == "preserve me\n"
        print("PASS dirty source refusal preserves work")


if __name__ == "__main__":
    main()
