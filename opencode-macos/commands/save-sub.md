---
description: Save current OpenAI OAuth subscription
---

Use the `save_current_openai_account` tool from the opencode-openai-sub-switcher plugin.

Workflow:

1. If the user included a label, pass it through.
2. Otherwise call `save_current_openai_account` without a label.
3. Report the saved account.

Important:

- Keep the reply concise.
- After saving, ask the user one short question about what they want to do next.
