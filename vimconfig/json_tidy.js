#!/usr/bin/env node

const readline = require('readline');
const fs = require('fs');

let input = '-';
if(process.argv && process.argv.length > 2) {
    input = process.argv[2];
}
let output = '-';
if(process.argv && process.argv.length > 3) {
    output = process.argv[3];
}

var inputStream;
if(input === '-') {
    inputStream = process.stdin;
} else {
    inputStream = fs.createReadStream(input);
}
var isTerminal = false;
var outputStream;
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

var json_content = '';

rl.on('line', (line)=>{
  json_content += line;
}).on('close', ()=>{
    var obj = JSON.parse(json_content);
    outputStream.write(JSON.stringify(obj, null, 2) + "\n");
});




