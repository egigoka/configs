import { homedir } from 'node:os';
import { pathToFileURL } from 'node:url';
export default (await import(pathToFileURL(`${homedir()}/.local/share/opencode-v2-plugins/opencode-short-term-memory-v2/server.js`).href)).default;
