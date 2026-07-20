---
description: Switch saved OpenAI OAuth subscription
---

Use the `list_openai_accounts` and `switch_openai_account` tools from the opencode-openai-sub-switcher plugin.

Workflow:

1. Call `list_openai_accounts` first.
2. If there is more than one saved account and the user did not provide an exact unique selector, you must ask the user to choose before switching.
3. Use the Question tool for that choice so OpenCode shows the native ask popup instead of a plain text follow-up.
4. When asking, present every saved account as a separate option using its `label`, redacted display text, and `id` so the choice is explicit.
5. If the user included an account selector with this command, match it against account `id`, `label`, `email`, or `accountId`.
6. Only call `switch_openai_account` immediately when exactly one account matches.
7. After switching, reply with the active account.
8. If `switch_openai_account` succeeds or a follow-up `list_openai_accounts` shows the chosen account marked with `*`, treat the switch as successful.

Important:

- Keep the reply concise.
- Do not ask the user to edit files or run commands unless the plugin tools are unavailable.
- Treat `*` in the list as the currently active account.
- Prefer asking over guessing whenever multiple accounts exist.
- Never guess when multiple accounts exist.
- Use the Question tool for account choice whenever a choice is needed.
- Do not say "switch failed" unless the tool explicitly errors or the active account remains different after rechecking.
- After finishing, ask the user one short question about what they want to do next.
