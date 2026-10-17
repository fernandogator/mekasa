// UI-007 AC13: colors live only in src/theme/tokens.css. Fails on hex, rgb()
// or hsl() literals anywhere else under src/.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = new URL('../src', import.meta.url).pathname;
const allowed = new Set(['theme/tokens.css']);
const pattern = /#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?)\s*\(/g;

function* files(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) yield* files(path);
    else if (/\.(tsx?|css)$/.test(name) && !/\.test\.tsx?$/.test(name)) yield path;
  }
}

const problems = [];
for (const path of files(root)) {
  const rel = relative(root, path);
  if (allowed.has(rel)) continue;
  readFileSync(path, 'utf8')
    .split('\n')
    .forEach((line, index) => {
      if (/^\s*(\/\/|\*)/.test(line)) return;
      for (const match of line.matchAll(pattern)) {
        problems.push(`src/${rel}:${index + 1}: ${match[0]}`);
      }
    });
}

if (problems.length) {
  console.error('Hard-coded colors outside src/theme/tokens.css (UI-007 AC13):');
  for (const problem of problems) console.error(`  ${problem}`);
  process.exit(1);
}
console.log('tokens: ok');
