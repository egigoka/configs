import { homedir } from "node:os"
import { join } from "node:path"
import { pathToFileURL } from "node:url"

const entrypoint = join(homedir(), ".local", "share", "opencode-codex-auth", "dist", "index.js")
const plugin = await import(pathToFileURL(entrypoint).href)

export const OpenAIMultiAuthPlugin = plugin.OpenAIMultiAuthPlugin
