import { readFile } from 'fs/promises';
import { resolve } from 'path';
import readline from 'readline/promises';

// Path to your YAML configuration file
const CONFIG_PATH = resolve(
  '/Users/gordon/src/shell-config/fishconfig/jandedobbeleer.omp.yaml'
);

// Regex to extract Unicode icons
const unicodeRegex = /\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8}/g;

// Read and parse the YAML file asynchronously
async function extractIcons(filePath) {
  try {
    const fileContent = await readFile(filePath, 'utf8');
    const matches = fileContent.match(unicodeRegex);
    return matches ? Array.from(new Set(matches)) : [];
  } catch (err) {
    console.error(`Failed to read file at ${filePath}: ${err.message}`);
    process.exit(1);
  }
}

// Decode Unicode escape sequences into actual characters
function decodeUnicode(unicode) {
  return unicode.startsWith('\\U')
    ? String.fromCodePoint(parseInt(unicode.slice(2), 16))
    : String.fromCharCode(parseInt(unicode.slice(2), 16));
}

// Interactively verify icons
async function verifyIcons(icons) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  console.log('Checking icons...\n');
  for (const icon of icons) {
    const decodedIcon = decodeUnicode(icon);
    console.log(`Icon: ${icon} -> ${decodedIcon}`);
    const response = await rl.question('Does this icon appear correctly? (y/n): ');
    if (response.toLowerCase() !== 'y') {
      console.log(`Marking ${icon} as problematic.\n`);
    } else {
      console.log('Icon verified.\n');
    }
  }

  await rl.close();
}

// Main function
async function main() {
  console.log('Starting icon check...');
  const icons = await extractIcons(CONFIG_PATH);

  if (icons.length === 0) {
    console.log('No Unicode icons found in the configuration file.');
    return;
  }

  await verifyIcons(icons);
  console.log('Icon check complete!');
}

main().catch((err) => {
  console.error(`An error occurred: ${err.message}`);
  process.exit(1);
});

