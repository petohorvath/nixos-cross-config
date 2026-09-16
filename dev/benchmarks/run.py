"""Compare frozen public factories in fresh, serial Nix evaluator processes."""

import argparse
import datetime
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import tarfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--baseline", default="3fa01e7b5b92a707a857b9a85a13e8feae0dd89a"
    )
    parser.add_argument("--pairs", type=int, default=7)
    parser.add_argument("--count", type=int, default=800)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.pairs < 7 or args.count < 1:
        parser.error("Use at least seven measured pairs and a positive workload size.")
    time_executable = shutil.which("time")
    if time_executable is None:
        parser.error(
            "GNU time is required; run the benchmark in the root development shell."
        )

    repo = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    baseline_revision = command(["git", "rev-parse", args.baseline], cwd=repo).strip()
    archive = subprocess.check_output(["git", "archive", baseline_revision], cwd=repo)
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        source.extractall(output / "baseline", filter="data")
    candidate = output / "candidate"
    candidate.mkdir()
    shutil.copy2(repo / "flake.nix", candidate / "flake.nix")
    shutil.copytree(repo / "lib", candidate / "lib")

    # Both variants use precisely these workloads, independently of their own tests.
    workload_files = [
        "dev/benchmarks/writable-tags.nix",
        "dev/benchmarks/nixos.nix",
        "tests/fixtures/mk-module-nodes.nix",
        "tests/fixtures/tagged-nixos.nix",
        "tests/mk-nodes.nix",
    ]
    workload_tree = output / "workloads"
    for name in workload_files:
        destination = workload_tree / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo / name, destination)

    pins = json.loads(
        command(
            nix_command()
            + [
                "--expr",
                f"let f = builtins.getFlake {nix_string(repo)}; in "
                "builtins.mapAttrs (_: input: { path = input.outPath; revision = input.rev; }) "
                "{ inherit (f.inputs) stable unstable; }",
            ]
        )
    )
    system = command(
        ["nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem"]
    ).strip()
    cpu_info = Path("/proc/cpuinfo").read_text()
    record = {
        "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "baseline_revision": baseline_revision,
        "candidate_parent": command(["git", "rev-parse", "HEAD"], cwd=repo).strip(),
        "source_sha256": {
            variant: {
                name: digest((output / variant / name).read_bytes())
                for name in ["flake.nix", "lib/mk-module.nix"]
            }
            for variant in ["baseline", "candidate"]
        },
        "workload_sha256": {
            name: digest((repo / name).read_bytes()) for name in workload_files
        },
        "runner_sha256": digest(Path(__file__).read_bytes()),
        "nix_version": command(["nix", "--version"]).strip(),
        "gnu_time_version": command([time_executable, "--version"]).splitlines()[0],
        "python_version": platform.python_version(),
        "platform": platform.platform(),
        "cpu_model": next(
            line.split(":", 1)[1].strip()
            for line in cpu_info.splitlines()
            if line.startswith("model name")
        ),
        "cpu_count": os.cpu_count(),
        "memory_total": Path("/proc/meminfo").read_text().splitlines()[0],
        "system": system,
        "pins": pins,
        "pairs": args.pairs,
        "count": args.count,
        "warmups": [],
        "measurements": [],
        "summaries": {},
    }
    for workload in ["writable-tags", "nixos"]:
        record["summaries"][workload] = {}
        for pin, source in pins.items():
            expected = None
            for pair in ["warmup"] + list(range(args.pairs)):
                variants = ["baseline", "candidate"]
                if isinstance(pair, int) and pair % 2:
                    variants.reverse()
                for variant in variants:
                    expression = (
                        f"let crossConfig = (import (builtins.toPath {nix_string(output / variant / 'flake.nix')})).outputs {{ }}; "
                        f"nixpkgs = (import (builtins.toPath {nix_string(Path(source['path']) / 'flake.nix')})).outputs "
                        f"{{ self.outPath = builtins.toPath {nix_string(source['path'])}; }}; "
                        f"in import (builtins.toPath {nix_string(workload_tree / 'dev/benchmarks' / (workload + '.nix'))}) "
                        "{ inherit crossConfig nixpkgs; "
                        + (
                            f"count = {args.count};"
                            if workload == "writable-tags"
                            else f"system = {nix_string(system)};"
                        )
                        + " }"
                    )
                    label = f"{workload}-{pin}-{variant}-{pair}"
                    timing_path = output / f"{label}.time"
                    invocation = (
                        [time_executable, "-f", "%e %U %S %M", "-o", str(timing_path)]
                        + nix_command()
                        + ["--expr", expression]
                    )
                    before = time.perf_counter()
                    result = subprocess.run(
                        invocation, capture_output=True, text=True, timeout=300
                    )
                    wall = time.perf_counter() - before
                    if result.returncode:
                        raise RuntimeError(f"{label}: {result.stderr}")
                    value = json.loads(result.stdout)
                    validate(workload, value, args.count)
                    output_digest = digest(result.stdout.encode())
                    if expected is None:
                        expected = output_digest
                    if output_digest != expected:
                        raise RuntimeError(
                            f"{label}: baseline/candidate outputs differ"
                        )
                    (output / f"{label}.json").write_text(result.stdout)
                    elapsed, user, kernel, rss = timing_path.read_text().split()
                    row = {
                        "workload": workload,
                        "pin": pin,
                        "variant": variant,
                        "pair": pair,
                        "wall_seconds": float(elapsed),
                        "process_wall_seconds": wall,
                        "user_seconds": float(user),
                        "system_seconds": float(kernel),
                        "peak_rss_kib": int(rss),
                        "output_sha256": output_digest,
                    }
                    record["warmups" if pair == "warmup" else "measurements"].append(
                        row
                    )
                print(f"{workload} {pin}: pair {pair} matched", flush=True)
            rows = [
                row
                for row in record["measurements"]
                if row["workload"] == workload and row["pin"] == pin
            ]
            record["summaries"][workload][pin] = summarize(rows)
        (output / f"{workload}.md").write_text(report(workload, record))
    (output / "results.json").write_text(json.dumps(record, indent=2) + "\n")
    print(f"Reports and raw measurements: {output}")


def command(arguments, **kwargs):
    return subprocess.check_output(arguments, text=True, **kwargs)


def nix_command():
    return [
        "nix",
        "--extra-experimental-features",
        "nix-command flakes",
        "eval",
        "--json",
        "--impure",
        "--offline",
        "--option",
        "eval-cache",
        "false",
        "--option",
        "allow-import-from-derivation",
        "false",
    ]


def nix_string(value):
    return json.dumps(str(value)).replace("${", r"\${")


def digest(value):
    return hashlib.sha256(value).hexdigest()


def validate(workload, value, count):
    if workload == "writable-tags":
        if len(value) != count or any(
            row["value"] != f"contributed-{index}" for index, row in enumerate(value)
        ):
            raise RuntimeError("Unexpected stress-workload values")
        assertions = [row["assertions"] for row in value]
    else:
        if value["publication"] != {
            "domain": "application.example",
            "upstream": "http://192.0.2.10:8080",
        }:
            raise RuntimeError("Unexpected NixOS publication")
        if (
            value["proxyPass"] != "http://192.0.2.10:8080"
            or 80 not in value["firewallPorts"]
        ):
            raise RuntimeError("Unexpected NixOS nginx/firewall configuration")
        assertions = [value["assertions"]]
    if not all(
        flag is True
        for nodes in assertions
        for flags in nodes.values()
        for flag in flags
    ):
        raise RuntimeError("A node assertion failed")


def summarize(rows):
    result = {}
    for metric in ["wall_seconds", "peak_rss_kib"]:
        result[metric] = {}
        for variant in ["baseline", "candidate"]:
            values = [row[metric] for row in rows if row["variant"] == variant]
            result[metric][variant] = {
                "median": statistics.median(values),
                "min": min(values),
                "max": max(values),
            }
        result[metric]["ratio_of_medians"] = (
            result[metric]["candidate"]["median"] / result[metric]["baseline"]["median"]
        )
        pairs = sorted({row["pair"] for row in rows})
        changes = []
        for pair in pairs:
            values = {
                row["variant"]: row[metric] for row in rows if row["pair"] == pair
            }
            changes.append(100 * (values["candidate"] / values["baseline"] - 1))
        result[metric]["paired_change_percent"] = {
            "median": statistics.median(changes),
            "min": min(changes),
            "max": max(changes),
        }
    return result


def report(workload, record):
    dimensions = (
        f"{record['count']} distinct two-node collections per evaluator process, each forwarding an indexed string into a writable tagged submodule with name-dependent permissions."
        if workload == "writable-tags"
        else "One two-node NixOS collection per evaluator process: an application publishes a conditional upstream through a writable HTTP tag, and a proxy uses the result in nginx with a receiver-owned domain and firewall configuration."
    )
    lines = [
        f"# {workload} evaluation benchmark",
        "",
        dimensions,
        "",
        "JSON evaluation forces every projected configuration value and both nodes' assertion booleans. Successful assertion messages remain lazy. Every warm-up and measured output matches the baseline byte for byte within its pin and passes independent value/assertion checks.",
        "",
        f"Measured at {record['started_at']} using {record['nix_version']}, {record['gnu_time_version']}, and Python {record['python_version']}. Machine: {record['platform']}; {record['cpu_count']} logical CPUs ({record['cpu_model']}); {record['memory_total']}. Evaluated system: `{record['system']}`.",
        "",
        f"Baseline: `{record['baseline_revision']}`. Candidate production module SHA-256: `{record['source_sha256']['candidate']['lib/mk-module.nix']}`. Both factories are frozen in separate directories before measurement; identical workloads use resolved local Nixpkgs paths. The raw results record all source hashes and sample outputs' hashes.",
        "",
        f"Each variant and pin receives one warm-up followed by {record['pairs']} measured pairs in alternating baseline/candidate order. Fresh evaluators run serially with evaluation caching and import-from-derivation disabled, offline, without builds or downloads. GNU time measures wall seconds and peak resident KiB; the raw data also retain a higher-resolution process wall timer. Memory below is MiB (KiB / 1024).",
        "",
        "| Pin | Metric | Baseline median (range) | Candidate median (range) | Ratio of medians | Median paired change (range) |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for pin, summary in record["summaries"][workload].items():
        for metric, unit, scale in [
            ("wall_seconds", "Wall (s)", 1),
            ("peak_rss_kib", "Peak RSS (MiB)", 1024),
        ]:
            data = summary[metric]
            cells = []
            for variant in ["baseline", "candidate"]:
                sample = data[variant]
                cells.append(
                    f"{sample['median'] / scale:.3f} ({sample['min'] / scale:.3f}–{sample['max'] / scale:.3f})"
                )
            paired = data["paired_change_percent"]
            lines.append(
                f"| {pin} | {unit} | {cells[0]} | {cells[1]} | {data['ratio_of_medians']:.3f} | {paired['median']:+.2f}% ({paired['min']:+.2f}%–{paired['max']:+.2f}%) |"
            )
    lines += [
        "",
        "## Reproduction",
        "",
        "Run from the repository root with the locked inputs already available locally and no competing evaluator or build workloads. Choose a new output directory:",
        "",
        "```bash",
        f"python3 dev/benchmarks/run.py --baseline {record['baseline_revision']} --pairs {record['pairs']} --count {record['count']} --output /tmp/cross-config-benchmark",
        "```",
        "",
    ]
    for pin, source in record["pins"].items():
        lines.append(
            f"- {pin}: `{source['revision']}`, resolved locally as `{source['path']}`."
        )
    lines += [
        "",
        "The runner writes both reports, raw measurements, timed commands' outputs, and frozen source/workload trees. There is no numerical performance gate; the stress cost of supported evaluation is accepted. These workloads measure evaluation only and do not predict deployment or full system-build costs.",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    main()
