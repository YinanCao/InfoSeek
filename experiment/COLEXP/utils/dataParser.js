const fs   = require('fs');
const path = require('path');
const rootDir = require('../utils/path');

// function that parses csv file to JSON
const getText = (filePath) => {
    let text = fs.readFileSync(path.join(rootDir,filePath),"utf8");
    text = JSON.stringify(text);
    return text;
};

// takes in a string containing single block data, parses it, returns as numerical arrays
const makeBlockObj = (blockData) => {
    const seqdat = Array.from(blockData.split('%'));
    const blockLen = seqdat.length;

    let blockSeqInfo = new Array(blockLen);
    let blockSeqSides = new Array(blockLen);
    let blockSeqTrials = new Array(blockLen);

    for (let i = 0; i < blockLen; i++) {
        const seq       = seqdat[i].split(')'); // results in array of size 3: info, side, and trial data 
        const info      = seq[0].split('(')[1].split('*').map(Number);
        const sides     = seq[1].split('(')[1].split('').map(Number);
        const trials    = seq[2].slice(0,-1).split(',').map(Number);
        
        blockSeqInfo[i] = info;
        blockSeqSides[i] = sides;
        blockSeqTrials[i] = trials;
    }
    
    return {
        blockInfo: blockSeqInfo,
        blockSides: blockSeqSides,
        blockTrials: blockSeqTrials
    }
}

exports.getText = getText;
exports.makeBlockObj = makeBlockObj;