#!/usr/bin/env python3
"""Stage, port, validate, and install selected third-party agent skills."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import tempfile
import uuid


MATT_SKILLS = {
    "code-review": "skills/engineering/code-review",
    "codebase-design": "skills/engineering/codebase-design",
    "domain-modeling": "skills/engineering/domain-modeling",
    "improve-codebase-architecture": "skills/engineering/improve-codebase-architecture",
    "resolving-merge-conflicts": "skills/engineering/resolving-merge-conflicts",
    "wizard": "skills/engineering/wizard",
    "writing-for-agents": "skills/productivity/writing-for-agents",
    "grilling": "skills/productivity/grilling",
}

PSTACK_SKILLS = {
    "blast-radius": "pstack/skills/blast-radius",
    "technical-writing": "pstack/skills/technical-writing",
    "typescript-best-practices": "pstack/skills/typescript-best-practices",
    "show-me-your-work": "pstack/skills/show-me-your-work",
    "principle-type-system-discipline": "pstack/skills/principle-type-system-discipline",
    "principle-boundary-discipline": "pstack/skills/principle-boundary-discipline",
    "principle-encode-lessons-in-structure": "pstack/skills/principle-encode-lessons-in-structure",
}

SUPPORT_RELOCATIONS: dict[str, list[tuple[str, str]]] = {
    "codebase-design": [
        ("DEEPENING.md", "references/DEEPENING.md"),
        ("DESIGN-IT-TWICE.md", "references/DESIGN-IT-TWICE.md"),
    ],
    "domain-modeling": [
        ("CONTEXT-FORMAT.md", "references/CONTEXT-FORMAT.md"),
        ("ADR-FORMAT.md", "references/ADR-FORMAT.md"),
    ],
    "improve-codebase-architecture": [
        ("HTML-REPORT.md", "references/HTML-REPORT.md"),
    ],
    "wizard": [
        ("template.sh", "templates/template.sh"),
    ],
    "writing-for-agents": [
        ("SKILL-MECHANICS.md", "references/SKILL-MECHANICS.md"),
    ],
}

TRANSFORMS: dict[str, list[tuple[str, str]]] = {
    "code-review": [
        (
            "The issue tracker should have been provided to you. If `docs/agents/issue-tracker.md` is missing, tell the user to run `/setup-matt-pocock-skills`.",
            "If `docs/agents/issue-tracker.md` exists, use it. Otherwise inspect issue references with the available Git and hosting tools. Do not block the review on repository-specific Matt Pocock setup.",
        ),
        (
            "1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in `docs/agents/issue-tracker.md`.",
            "1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched through `docs/agents/issue-tracker.md` when present or through the available GitHub, GitLab, or Git tools.",
        ),
    ],
    "blast-radius": [
        (
            "1. Read the change. The diff, the symbols it adds, changes, and deletes, and what it now does differently, including the part the diff doesn't spell out. Use `why` step 2 to pull the PR and commits.",
            "1. Read the change. Inspect the diff, PR, commits, and every symbol it adds, changes, or deletes. Work out what now behaves differently, including effects the diff does not state explicitly. Use the available Git and hosting tools directly; `why` is optional.",
        ),
        (
            "6. For a big or wide change, run it as an `arena`. Ask several models the same question and merge the answers. Different models catch different real bugs.",
            "6. For a big or wide change, dispatch independent review subagents in parallel when the active harness supports it, then verify and merge their findings yourself. A single-agent review remains valid when delegation is unavailable.",
        ),
        (
            "Same rules as `why`. Cite a real `file:line`, a search that finds nothing is still an answer, and never make up a caller or an API.",
            "Calibrate confidence from the evidence. Cite a real `file:line`; a search that finds nothing is still an answer. Never invent a caller or API.",
        ),
    ],
    "typescript-best-practices": [
        (
            "Apply the **type-system-discipline** principle skill first; this skill grounds it in TypeScript syntax.",
            "Load **principle-type-system-discipline** first; this skill grounds it in TypeScript syntax.",
        ),
        (
            "See the **boundary-discipline** principle skill.",
            "See the **principle-boundary-discipline** skill.",
        ),
    ],
    "show-me-your-work": [
        (
            "the **encode-lessons-in-structure** principle skill",
            "the **principle-encode-lessons-in-structure** skill",
        ),
        (
            "At the end of the run, before handing back, check the log told the truth. Read this run's transcript under the active workspace's `agent-transcripts/` directory (the system prompt names the path). Don't glob across `~/.cursor/projects/*/`; that reads unrelated private chats. Walk the log against what actually happened:",
            "At the end of the run, before handing back, check that the log tells the truth. Use the active harness's current conversation history or targeted session-search tool. Never search unrelated private sessions. Walk the log against what actually happened:",
        ),
        (
            "Before handing back, you must spawn a subagent on a different model family from the one that did the work. Self-review is not a substitute; the point is fresh eyes you cannot bring yourself. The subagent reads the audit trail and the run's transcript, then flags what the user should pay attention to. Not a redo of the work, a scan for what's suboptimal or risky.",
            "Before handing back, spawn an independent review subagent when delegation is available. Use a different model family when the harness supports model selection; otherwise use a fresh isolated subagent. If delegation is unavailable, perform a clearly labelled independent second pass. The review reads the audit trail and available run history, then flags what the user should scrutinize. It is a risk scan, not a redo of the work.",
        ),
        (
            "Every reply for a run that produced a trail ends with an \"Attention\" section. Lead with the reviewer's model on its own line (`reviewed by <model>`), then list each flag pointing to specific rows or moments. \"No flags\" is a valid value; the model name is not. The self-audit asks if the log told the truth; this asks what the user should still scrutinize even when it did.",
            "Every reply for a run that produced a trail ends with an `Attention` section. Identify the reviewer as `reviewed by <model>` when the model is known, or `reviewed by independent pass` otherwise. List each flag with a pointer to a specific row or moment. `No flags` is valid. The self-audit asks whether the log is truthful; this pass asks what the user should still scrutinize.",
        ),
    ],
}


def tree_hash(root: Path, *, exclude: set[str] | None = None) -> str:
    digest = hashlib.sha256()
    excluded = exclude or set()
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(root).as_posix()
        if relative in excluded:
            continue
        if path.is_symlink():
            raise ValueError(f"symlink rejected: {path}")
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        if path.is_file():
            digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def validate_skill(directory: Path, expected_name: str) -> None:
    skill = directory / "SKILL.md"
    if not skill.is_file():
        raise ValueError(f"missing SKILL.md: {directory}")
    raw = skill.read_bytes()
    if not raw or len(raw) > 100_000 or b"\0" in raw:
        raise ValueError(f"invalid SKILL.md size/content: {skill}")
    text = raw.decode("utf-8")
    match = re.match(r"\A---\n(.*?)\n---\n(.*)\Z", text, re.DOTALL)
    if not match:
        raise ValueError(f"invalid frontmatter: {skill}")
    frontmatter, body = match.groups()
    name = re.search(r"(?m)^name:\s*([^\n]+?)\s*$", frontmatter)
    description = re.search(r"(?m)^description:\s*(.+?)\s*$", frontmatter)
    if not name or name.group(1).strip('"\'') != expected_name:
        raise ValueError(f"unexpected skill name in {skill}")
    if not description or not description.group(1).strip('"\' '):
        raise ValueError(f"empty description in {skill}")
    if not body.strip():
        raise ValueError(f"empty body in {skill}")
    for path in directory.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"symlink rejected: {path}")
        if path.is_file() and path.stat().st_size > 2_000_000:
            raise ValueError(f"oversized support file: {path}")


def relocate_support_files(name: str, directory: Path) -> list[str]:
    relocations: list[str] = []
    skill_path = directory / "SKILL.md"
    text = skill_path.read_text(encoding="utf-8")
    for source_name, target_name in SUPPORT_RELOCATIONS.get(name, []):
        source = directory / source_name
        target = directory / target_name
        if not source.is_file():
            raise ValueError(f"upstream support file is missing: {source}")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(source, target)
        text = text.replace(f"]({source_name})", f"]({target_name})")
        text = text.replace(f"](./{source_name})", f"]({target_name})")
        text = text.replace(f"`{source_name}`", f"`{target_name}`")
        relocations.append(f"move-{source_name}-to-{target_name}")
    skill_path.write_text(text, encoding="utf-8")
    return relocations


def apply_transforms(name: str, directory: Path) -> list[str]:
    applied: list[str] = []
    path = directory / "SKILL.md"
    text = path.read_text(encoding="utf-8")
    for index, (old, new) in enumerate(TRANSFORMS.get(name, []), start=1):
        if old not in text:
            raise ValueError(f"upstream changed; portability transform {name}#{index} no longer applies")
        text = text.replace(old, new, 1)
        applied.append(f"portability-transform-{index}")
    path.write_text(text, encoding="utf-8")
    return applied


def prepare_skill(
    *,
    source_root: Path,
    source_path: str,
    source_repo: str,
    source_ref: str,
    license_path: Path,
    name: str,
    staging_root: Path,
) -> Path:
    source = source_root / source_path
    if not source.is_dir():
        raise ValueError(f"missing upstream skill directory: {source}")
    source_sha = tree_hash(source)
    destination = staging_root / name
    shutil.copytree(source, destination)
    transforms = relocate_support_files(name, destination)
    transforms.extend(apply_transforms(name, destination))
    validate_skill(destination, name)
    shutil.copy2(license_path, destination / "LICENSE")
    content_sha = tree_hash(destination, exclude={"UPSTREAM"})
    transform_text = ", ".join(transforms) if transforms else "none"
    (destination / "UPSTREAM").write_text(
        "\n".join(
            [
                f"repository: {source_repo}",
                f"commit: {source_ref}",
                f"path: {source_path}",
                f"source_tree_sha256: {source_sha}",
                f"installed_content_sha256: {content_sha}",
                f"porter_sha256: {hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}",
                f"local_transforms: {transform_text}",
                "",
            ]
        ),
        encoding="utf-8",
    )
    validate_skill(destination, name)
    return destination


def atomic_install(source: Path, destination: Path) -> bool:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_dir() and tree_hash(source) == tree_hash(destination):
        return False
    staged = Path(tempfile.mkdtemp(prefix=f".{destination.name}.new.", dir=destination.parent))
    backup: Path | None = None
    try:
        shutil.copytree(source, staged, dirs_exist_ok=True)
        if destination.exists() or destination.is_symlink():
            backup = destination.parent / f".{destination.name}.old.{uuid.uuid4().hex}"
            os.replace(destination, backup)
        os.replace(staged, destination)
        if backup is not None:
            if backup.is_dir() and not backup.is_symlink():
                shutil.rmtree(backup)
            else:
                backup.unlink(missing_ok=True)
        return True
    except Exception:
        if not destination.exists() and backup is not None and backup.exists():
            os.replace(backup, destination)
        raise
    finally:
        if staged.exists():
            shutil.rmtree(staged)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--matt-root", type=Path, required=True)
    parser.add_argument("--matt-ref", required=True)
    parser.add_argument("--pstack-root", type=Path, required=True)
    parser.add_argument("--pstack-ref", required=True)
    parser.add_argument("--configs-dir", type=Path, required=True)
    parser.add_argument("--hermes-home", type=Path, required=True)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="selected-agent-skills-stage.") as temporary:
        staging_root = Path(temporary)
        prepared: dict[str, Path] = {}
        matt_license = args.matt_root / "LICENSE"
        pstack_license = args.pstack_root / "pstack/LICENSE"
        if "MIT License" not in matt_license.read_text(encoding="utf-8"):
            raise ValueError("Matt Pocock repository license is not MIT")
        if "MIT License" not in pstack_license.read_text(encoding="utf-8"):
            raise ValueError("pstack license is not MIT")

        for name, source_path in MATT_SKILLS.items():
            prepared[name] = prepare_skill(
                source_root=args.matt_root,
                source_path=source_path,
                source_repo="https://github.com/mattpocock/skills.git",
                source_ref=args.matt_ref,
                license_path=matt_license,
                name=name,
                staging_root=staging_root,
            )
        for name, source_path in PSTACK_SKILLS.items():
            prepared[name] = prepare_skill(
                source_root=args.pstack_root,
                source_path=source_path,
                source_repo="https://github.com/cursor/plugins.git",
                source_ref=args.pstack_ref,
                license_path=pstack_license,
                name=name,
                staging_root=staging_root,
            )

        roots = [
            args.configs_dir / "opencode-macos/skills",
            args.configs_dir / "opencode-other/skills",
            args.configs_dir / "opencode-steamos/skills",
            args.hermes_home / "skills",
        ]
        for root in roots:
            for name, source in prepared.items():
                changed = atomic_install(source, root / name)
                status = "updated" if changed else "current"
                print(f"{name}: {status} -> {root / name}")


if __name__ == "__main__":
    main()
