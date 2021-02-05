#!/usr/bin/env node

const fs = require('fs');
let yaml;
try {
  yaml = require('js-yaml');
} catch(e) {
  console.log("install js-yaml `npm install -g js-yaml`");
  process.exit(1);
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
  yaml_content += line;
}).on('close', ()=>{
  try {
    let obj = yaml.safeLoad(yaml_content);
    outputStream.write(JSON.stringify(obj, null, 2) + "\n");
  } catch(e) {
    console.log(e);
  }
});



