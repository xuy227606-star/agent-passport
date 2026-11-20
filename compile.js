const solc = require('solc');
const fs = require('fs');
const path = require('path');
function findImports(p) {
  try {
    const f = path.resolve('node_modules', p);
    return { contents: fs.readFileSync(f, 'utf8') };
  } catch (e) { return { error: 'not found: ' + p }; }
}
const input = {
  language: 'Solidity',
  sources: { 'AgentPassport.sol': { content: fs.readFileSync('contracts/AgentPassport.sol', 'utf8') } },
  settings: { optimizer: { enabled: true, runs: 200 }, viaIR: true, outputSelection: { '*': { '*': ['abi', 'evm.bytecode.object'] } } }
};
const out = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));
if (out.errors) out.errors.forEach(e => console.log(e.severity + ': ' + e.formattedMessage));
const c = out.contracts && out.contracts['AgentPassport.sol'] && out.contracts['AgentPassport.sol']['AgentPassport'];
if (c) {
  console.log('COMPILED OK, bytecode bytes:', c.evm.bytecode.object.length / 2);
  fs.mkdirSync('build', { recursive: true });
  fs.writeFileSync('build/AgentPassport.abi.json', JSON.stringify(c.abi, null, 2));
  fs.writeFileSync('build/AgentPassport.bytecode.txt', c.evm.bytecode.object);
  console.log('ABI functions:', c.abi.filter(x => x.type === 'function').map(x => x.name).join(', '));
} else console.log('COMPILE FAILED');
