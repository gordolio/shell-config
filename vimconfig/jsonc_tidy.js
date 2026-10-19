#!/usr/bin/env node

const readline = require('readline');
const fs = require('fs');

let jsoncParser;
try {
  jsoncParser = require('jsonc-parser');
} catch(e) {
  // npm installs global packages under `npm root -g` (lib/node_modules), but
  // node's own require() global fallback looks in a different, unrelated
  // path (lib/node) -- so a globally-installed package still isn't found by
  // require() unless we point at npm's actual global root ourselves.
  try {
    const path = require('path');
    const { execFileSync } = require('child_process');
    const globalRoot = execFileSync('npm', ['root', '-g'], { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    jsoncParser = require(path.join(globalRoot, 'jsonc-parser'));
  } catch(e2) {
    console.log("install jsonc-parser `npm install -g jsonc-parser`");
    process.exit(1);
  }
}

let input = '-';
if(process.argv && process.argv.length > 2) {
    input = process.argv[2];
}
let output = '-';
if(process.argv && process.argv.length > 3) {
    output = process.argv[3];
}

let inputStream;
if(input === '-') {
    inputStream = process.stdin;
} else {
    inputStream = fs.createReadStream(input);
}
let outputStream;
if(output === '-') {
    outputStream = process.stdout;
} else {
    outputStream = fs.createWriteStream(output);
}

const rl = readline.createInterface({
  input: inputStream,
  crlfDelay: Infinity,
});

let lines = [];

rl.on('line', (line)=>{
  lines.push(line);
}).on('close', ()=>{
  const text = lines.join('\n');
  const edits = jsoncParser.format(text, undefined, { tabSize: 2, insertSpaces: true });
  const formatted = jsoncParser.applyEdits(text, edits);
  outputStream.write(formatted.replace(/\n*$/, '') + "\n");
});
