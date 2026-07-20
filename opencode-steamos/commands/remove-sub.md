---
description: Remove saved OpenAI OAuth subscription
---

Use the `list_openai_accounts` and `remove_openai_account` tools from the opencode-openai-sub-switcher plugin.

Workflow:

1. Call `list_openai_accounts` first.
2. If the user did not provide an exact unique selector, ask them which saved account to remove.
3. Match the selector against account `id`, `label`, `email`, or `accountId`.
4. If exactly one account matches, ask for confirmation before removing it.
5. Only call `remove_openai_account` after explicit confirmation.

Important:

- Keep the reply concise.
- Prefer asking over guessing whenever multiple accounts exist.
- After removing, ask the user one short question about what they want to do next.
