---
description: Rename saved OpenAI OAuth subscription
---

Use the `list_openai_accounts` and `rename_openai_account` tools from the opencode-openai-sub-switcher plugin.

Workflow:

1. Call `list_openai_accounts` first.
2. If the user did not provide both a unique account selector and the new label, ask for the missing value.
3. Match the selector against account `id`, `label`, `email`, or `accountId`.
4. If exactly one account matches, call `rename_openai_account` with that account's `id` and the new label.
5. If matching is ambiguous, ask the user to choose.

Important:

- Keep the reply concise.
- Prefer asking over guessing whenever multiple accounts exist.
- After renaming, ask the user one short question about what they want to do next.
