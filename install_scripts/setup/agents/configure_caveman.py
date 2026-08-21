import re
import sys
from pathlib import Path


root = Path(sys.argv[1])

for name in ("cavecrew-reviewer.md", "cavecrew-investigator.md"):
    path = root / "agents" / name
    if path.exists():
        text = path.read_text()
        path.write_text(re.sub(r"^model:.*\n", "", text, flags=re.MULTILINE))

readme = root / "skills" / "cavecrew" / "README.md"
if readme.exists():
    model_section = """## Model overrides

By default, cavecrew agents use the API session model. Set env vars in your shell before launching Claude Code to override per-agent:

| Env var | Agent |
|---|---|
| `CAVECREW_REVIEWER_MODEL` | `cavecrew-reviewer` |
| `CAVECREW_BUILDER_MODEL` | `cavecrew-builder` |
| `CAVECREW_INVESTIGATOR_MODEL` | `cavecrew-investigator` |

Example: override the reviewer model, keep others on default:

```sh
export CAVECREW_REVIEWER_MODEL=your-model-name
```

Use the same model name string you'd use in Claude Code agent frontmatter.

Overrides patch only the `model:` line in the installed agent's frontmatter; the prompt body is untouched and keeps receiving upstream updates. Plugin installs only; standalone hook installs have no local agent files to patch. Unset or blank = no change. The patch persists in the installed file until the plugin is updated or reinstalled.
"""
    text = readme.read_text()
    text = re.sub(
        r"## Model overrides\n.*?(?=\n## )",
        model_section.rstrip() + "\n",
        text,
        count=1,
        flags=re.DOTALL,
    )
    readme.write_text(text)

compressor = root / "skills" / "caveman-compress" / "scripts" / "compress.py"
if compressor.exists():
    text = compressor.read_text()
    text = re.sub(
        r"    Prefers the Anthropic SDK when ANTHROPIC_API_KEY.*?(?=\n\n    On Windows)",
        "    Prefers the Anthropic SDK when ANTHROPIC_API_KEY and CAVEMAN_MODEL are set;\n"
        "    otherwise falls back to the ``claude --print`` CLI (which handles desktop\n"
        "    auth and uses the session model).",
        text,
        count=1,
        flags=re.DOTALL,
    )
    text = text.replace(
        "    report. Windows users with non-ASCII content can also set\n"
        "    ``ANTHROPIC_API_KEY`` to route through the SDK and skip the subprocess.",
        "    report. Windows users with non-ASCII content can also set\n"
        "    ``ANTHROPIC_API_KEY`` and ``CAVEMAN_MODEL`` to route through the SDK and\n"
        "    skip the subprocess.",
    )
    text = re.sub(
        r'    api_key = os\.environ\.get\("ANTHROPIC_API_KEY"\)\n'
        r'(?:    model = os\.environ\.get\("CAVEMAN_MODEL"\)\n)?'
        r'    if api_key(?: and model)?:',
        '    api_key = os.environ.get("ANTHROPIC_API_KEY")\n'
        '    model = os.environ.get("CAVEMAN_MODEL")\n'
        '    if api_key and model:',
        text,
        count=1,
    )
    text = re.sub(
        r'model=os\.environ\.get\("CAVEMAN_MODEL",\s*"[^"]+"\),',
        "model=model,",
        text,
        count=1,
    )
    compressor.write_text(text)
