#!/usr/bin/env node

const readline = require('readline');
const fs = require('fs');
let yaml;
try {
  yaml = require('js-yaml');
} catch(e) {
  // npm installs global packages under `npm root -g` (lib/node_modules), but
  // node's own require() global fallback looks in a different, unrelated
  // path (lib/node) -- so a globally-installed package still isn't found by
  // require() unless we point at npm's actual global root ourselves.
  try {
    const path = require('path');
    const { execFileSync } = require('child_process');
    const globalRoot = execFileSync('npm', ['root', '-g'], { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    yaml = require(path.join(globalRoot, 'js-yaml'));
  } catch(e2) {
    console.log("install js-yaml `npm install -g js-yaml`");
    process.exit(1);
  }
}
const yamlLoad = yaml.load || yaml.safeLoad;


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
let isTerminal = false;
let outputStream;
if(output === '-') {
    isTerminal = true;
    outputStream = process.stdout;
} else {
    outputStream = fs.createWriteStream(output);
}

const rl = readline.createInterface({
  input: inputStream,
  crlfDelay: Infinity,
});

let yaml_content = '';

rl.on('line', (line)=>{
  yaml_content += line + "\n";
}).on('close', ()=>{
  try {
    let obj = yamlLoad(yaml_content);
    outputStream.write(JSON.stringify(obj, null, 2) + "\n");
  } catch(e) {
    console.log(e);
  }
});



