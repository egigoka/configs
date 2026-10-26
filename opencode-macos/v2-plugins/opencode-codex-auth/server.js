import { homedir } from 'node:os';
import { pathToFileURL } from 'node:url';
export default (await import(pathToFileURL(`${homedir()}/.local/share/opencode-v2-plugins/opencode-codex-auth/server.js`).href)).default;
