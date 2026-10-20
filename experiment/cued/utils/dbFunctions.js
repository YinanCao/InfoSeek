const fs         = require('fs');
// const mysql      = require('mysql2');

// const db         = require('../utils/database');
const queries    = require('../queries/queries');
const dataParser = require('../utils/dataParser');
const {resolve}  = require('path');
const path = require('path');

const db_names   = ['main_table', 'task_table', 'resp_table', 'ques_table'];
const nTables    = db_names.length;
const data_dirNames  = fs.readdirSync('./data/').filter(x => {
    return x != '.DS_Store'
});
const uids = data_dirNames.map(x => x.slice(0));

// ---------- PID -> UID assignment log (CSV) ---------- // YC: 08/Jan/2026
// const csvDirAbs = path.join(__dirname, '..', 'csv');                 // same base as postRespData
// const csvDirAbs = '/home/ycao/COLEXP3bags_csv'; // YC: 15/Jan/2026
const csvDirAbs = path.join(__dirname, '..', '..', 'COLEXPforced_csv'); // YC: 15/Jan/2026
const assignFileAbs = path.join(csvDirAbs, 'assignments.csv');

const ASSIGN_HEADER = 'pid,uid,subj,status,created_at,last_seen_at\n';

function ensureAssignFile() {
    if (!fs.existsSync(csvDirAbs)) {
        fs.mkdirSync(csvDirAbs, { recursive: true });
    }
    if (!fs.existsSync(assignFileAbs)) {
        fs.writeFileSync(assignFileAbs, ASSIGN_HEADER);
    }
}

function readAssignments() {
    ensureAssignFile();
    const text = fs.readFileSync(assignFileAbs, 'utf8');
    const lines = text.split('\n').filter(x => x.trim().length > 0);

    // only header exists
    if (lines.length <= 1) return [];

    const rows = [];
    for (const line of lines.slice(1)) {
        const parts = line.split(',');
        if (parts.length < 6) continue;

        const [pid, uid, subj, status, created_at, last_seen_at] = parts;
        rows.push({
            pid: pid,
            uid: uid,
            subj: Number(subj),
            status: status,
            created_at: created_at,
            last_seen_at: last_seen_at
        });
    }
    return rows;
}

function writeAssignments(rows) {
    ensureAssignFile();
    const out = [ASSIGN_HEADER.trim()];
    for (const r of rows) {
        out.push(`${r.pid},${r.uid},${r.subj},${r.status},${r.created_at},${r.last_seen_at}`);
    }
    fs.writeFileSync(assignFileAbs, out.join('\n') + '\n');
}

function appendAssignment(row) {
    ensureAssignFile();
    const line = `${row.pid},${row.uid},${row.subj},${row.status},${row.created_at},${row.last_seen_at}\n`;
    fs.appendFileSync(assignFileAbs, line);
}

function updateLastSeen(pid, whenStr) {
    const rows = readAssignments();
    let changed = false;
    for (const r of rows) {
        if (r.pid === pid) {
            r.last_seen_at = whenStr;
            changed = true;
            break;
        }
    }
    if (changed) writeAssignments(rows);
}

function setStatusByPID(pid, newStatus) {
    const rows = readAssignments();
    let changed = false;
    for (const r of rows) {
        if (r.pid === pid) {
            r.status = newStatus;
            changed = true;
            break;
        }
    }
    if (changed) writeAssignments(rows);
}

function setStatusByUID(uid, newStatus) {
    const rows = readAssignments();
    let changed = false;
    for (const r of rows) {
        if (r.uid === uid) {
            r.status = newStatus;
            changed = true;
            break;
        }
    }
    if (changed) writeAssignments(rows);
}
// ---------- end assignment helpers ----------

// returns string of values from chosen csv file
const getDataStr = (filename) => {
    if (!['data'].includes(filename)) {
        throw new Error(`${filename} is not a valid file to be processed!`)
    }
    return Array.from(data_dirNames, x => {
        return `"${dataParser.getText(`./data/${x}/${filename}.txt`).slice(1,-1)}"`;

    })
}

// put all subjects' data into an array for transfer into database
const dataArray = getDataStr('data');

// get Boolean array of empty databasesw
const getEmptyDatabases = () => {
    return db.execute(`SHOW TABLES;`)
        .then(([rows]) => {
            // check query results for all tables for missing tables
            const isEmpty = () => {
                isEmptyArray = Array(nTables).fill(Boolean(1));
                for (let i = 0; i < rows.length; i++) {
                    let db_name = Object.values(rows[i])[0];
                    if (db_names.includes(db_name)) {
                        isEmptyArray[db_names.indexOf(db_name)] = false;
                    }
                }
                return isEmptyArray
            };
            return isEmpty();
        });
};

// calculate number of missing tables
const getNEmpty = () => {
    const isTrue = (elem) => {
        return elem == true
    };
    return getEmptyDatabases()
        .then(() => {
            if (isEmptyArray.some(isTrue)) {
                for (let i = 0; i < isEmptyArray.length; i++) {
                    if (isEmptyArray[i]) {
                        console.log(`${db_names[i]} not found in database!`);
                    }
                }
            }
            const nEmptyVal = () => {
                return isEmptyArray.map(x => Number(x)).reduce((a, b) => a + b, 0);
            }
            return nEmptyVal()
        });
}

// builds all tables in the database
const buildAllTables = () => {
    let promises = [];
    db_names.forEach(name => {
        const query = queries.buildAllTables[name]
        promises.push(db.execute(query));
    })
    return Promise.all(promises)
};

// fills main_table with subject and unique id numbers from csvs
const fillMainTable = (uids) => {
    const countQuery = `SELECT COUNT(*) FROM main_table;`;
    db.execute(countQuery)
        .then(([rows]) => {
            const nRows = Object.values(rows[0])[0];
            if (nRows == 0) {
                let promises = [];
                for (let i = 0; i < uids.length; i++) {
                    if (uids[i] == '000TRAINING') {
                        continue
                    }
                    promises.push(new Promise((resolve, reject) => {
                        resolve(`(${i}, "${uids[i]}", NULL)`);
                    }))
                }
                Promise.all(promises)
                    .then((valuesStr) => {
                        const insertQuery = `INSERT INTO main_table (subj, uid, t_init) VALUES ${valuesStr}`;
                        db.execute(insertQuery)
                            .then(([rows]) => {
                                console.log(`${rows.affectedRows} rows affected (main_table).`)
                            })
                    })
            }
        })
};

/*  Fills the task table with experiment data.
    If task table was empty, it will also fill in the main_table with subject numbers and UIDs. */
function fillTaskTable() {
    return new Promise ((resolve, reject) => {
        const countQuery = `SELECT COUNT(*) FROM task_table;`;
        resolve(db.execute(countQuery)
            .then(([rows]) => {
                const nRows = Object.values(rows[0])[0];
                // only insert if table is empty
                if (nRows == 0) {
                    console.log('Writing data to main_table...');
                    fillMainTable(uids);

                    console.log('Writing data to task_table...');
                    let promises = [];
                    for (let i = 0; i < data_dirNames.length; i++) {
                        promises.push(new Promise((resolve, reject) => {
                            resolve(`("${uids[i]}", ${i+1}, ${dataArray[i]})`);
                        }));
                    }
                    Promise.all(promises)
                        .then((valuesStr) => {
                            const insertQuery = `INSERT INTO task_table (uid, subj, data) VALUES ${valuesStr};`;
                            db.execute(insertQuery)
                                .then(([rows]) => {
                                    console.log(`${rows.affectedRows} rows affected (task_table).`)
                                });
                        })
                    
                } else if (nRows < uids.length) {
                    console.error(`There are fewer data rows ${nRows} than there are subject files (${uids.length})! Check!`)
                } 
            })
            .catch(err => console.log(err))
            );
    })
};


/* Checks tables and builds them if they don't exist */
// function checkTables() {
//     return new Promise((resolve, reject) => {
//         getNEmpty()
//             .then((nEmpty) => {
//                 if (nEmpty == nTables) { // if the database is empty, build tables
//                     buildAllTables()
//                         .then(() => { // then fill task_table and main_table with data from data text files
//                             return fillTaskTable()
//                         })
//                         .then(resolve('The database is completely empty! Building tables...'))
//                         .catch(err => console.log(err));

//                 } else if (nEmpty > 0) {
//                     resolve(`There are ${nEmpty} tables in the database. This is strange. Check manually.`);
//                 } else {
//                     resolve(`All tables found (${nEmpty} tables returned from query)!`)
//                 }
//             })
//             .catch((err) => console.log(err))
//     });
// }
function checkTables() {
    // MySQL removed: nothing to check or build
    return Promise.resolve(true);
}

/* Checks for repeated PIDs in main_table*/
// function isRepeatPID(pid) {
//     const checkQuery = `SELECT EXISTS(SELECT * FROM main_table WHERE pid = "${pid}");`
//     return new Promise((resolve, reject) => {
//         db.execute(checkQuery)
//             .then(([rows]) => {
//                 resolve(!!Object.values(rows[0])[0]);
//             })
//     })
// }

// function isRepeatPID(pid) { YC: 08/Jan/2026 commented out
//     // Without a database, we cannot reliably track repeats.
//     // For now: always say "not repeat".
//     return Promise.resolve(false);
// }
// YC: 08/Jan/2026 add:
function isRepeatPID(pid) {
    return new Promise((resolve, reject) => {
        try {
            const rows = readAssignments();
            const existing = rows.find(r => r.pid === pid);

            // Policy: block only if they already finished
            if (existing && existing.status === 'finished') return resolve(true);

            // If you want to block as soon as they ever entered, use this instead:
            // if (existing) return resolve(true);

            return resolve(false);
        } catch (err) {
            reject(err);
        }
    });
}




/* Gets a free UID (and subject number) for new incoming PIDs */
// function getFreeUID(pid) {
//     return new Promise((resolve, reject) => {
//         const getQuery = `SELECT uid, subj FROM main_table WHERE pid IS NULL LIMIT 1;`
//         db.execute(getQuery)
//             .then(([rows]) => {
//                 const vals = Object.values(rows[0]);
//                 const dataObj = {
//                     uid: vals[0],
//                     subj: vals[1],
//                 }
//                 // assign the PID to this UID //DEBUG: need to uncomment when testing uniqueness 
//                 const updateQuery = `UPDATE main_table SET pid = "${pid}", 
//                                                         t_init = NOW() 
//                                      WHERE uid = "${vals[0]}";`

//                 db.execute(updateQuery)
//                     .then(() => {
//                         resolve(dataObj);
//                     }, rej => {
//                         console.log(`Caught duplicate entry error with PID : ${pid}`);
//                         reject(rej);
//                     });
//             })
//     })
// }

// let _subjCounter = 1; // YC: 08/Jan/2026 commented out
// function getFreeUID(pid) {
//     // Use the list of UID folders in ./data/ as the pool.
//     const validUIDs = uids.filter(u => u !== '000TRAINING');

//     return new Promise((resolve, reject) => {
//         if (validUIDs.length === 0) {
//             console.error('No UID folders found in ./data/');
//             return reject(new Error('No UID folders found'));
//         }
//         // Simple round-robin through available UIDs
//         const idx = (_subjCounter - 1) % validUIDs.length;
//         const uid = validUIDs[idx];
//         const subj = _subjCounter;
//         _subjCounter += 1;

//         resolve({ uid, subj });
//     });
// }

// YC: 08/Jan/2026, add:
function getFreeUID(pid) {
    return new Promise((resolve, reject) => {
        try {
            const now = new Date().toISOString();

            // Keep your pool from ./data/, but ignore 000TRAINING
            const validUIDs = uids.filter(u => u !== '000TRAINING');

            if (validUIDs.length === 0) {
                console.error('No UID folders found in ./data/');
                return reject(new Error('No UID folders found'));
            }

            const rows = readAssignments();

            // 1) If PID already has a UID, reuse it
            const existing = rows.find(r => r.pid === pid);
            if (existing) {
                updateLastSeen(pid, now);
                return resolve({ uid: existing.uid, subj: existing.subj });
            }

            // 2) Otherwise pick a free UID that no one else used
            const usedUIDs = new Set(rows.map(r => r.uid));
            const freeUIDs = validUIDs.filter(u => !usedUIDs.has(u));

            if (freeUIDs.length === 0) {
                return reject(new Error('No free UID left. Add more folders in ./data/'));
            }

            const uid = freeUIDs[0];          // simplest and deterministic
            const subj = rows.length + 1;     // simple subject number

            appendAssignment({
                pid: pid,
                uid: uid,
                subj: subj,
                status: 'started',
                created_at: now,
                last_seen_at: now
            });

            return resolve({ uid, subj });

        } catch (err) {
            reject(err);
        }
    });
}



// function getTaskData(uid) {
//     const getQuery = `SELECT data FROM task_table WHERE uid = "${uid}"`;

//     return new Promise((resolve, reject) => {
//         db.execute(getQuery)
//             .then(([rows]) => {
//                 resolve(Object.values(rows[0])[0]);
//             });
//     })
// }
function getTaskData(uid) {
    // Read ./data/<uid>/data.txt and return its raw text (without JSON quotes)
    return new Promise((resolve, reject) => {
        try {
            const textJson = dataParser.getText(`./data/${uid}/data.txt`); // returns JSON-encoded string
            const text = textJson.slice(1, -1); // remove surrounding quotes
            resolve(text);
        } catch (err) {
            console.error(`Failed to read task data for uid = ${uid}`, err);
            reject(err);
        }
    });
}

// function getTrainingData() {
//     const getQuery = `SELECT data FROM task_table WHERE uid = "000TRAINING"`;

//     return new Promise((resolve, reject) => {
//         db.execute(getQuery)
//             .then(([rows]) => {
//                 resolve(Object.values(rows[0])[0]);
//             });
//     })
// }
function getTrainingData() {
    // Read ./data/000TRAINING/data.txt
    return new Promise((resolve, reject) => {
        try {
            const textJson = dataParser.getText('./data/000TRAINING/data.txt');
            const text = textJson.slice(1, -1);
            resolve(text);
        } catch (err) {
            console.error('Failed to read training data (000TRAINING)', err);
            reject(err);
        }
    });
}

// function postRespData(data) {
//     return new Promise((resolve, reject) => {
//         const subj = data.subj,
//               uid = data.uid,
//               dataStrArr = data['dataStrArr[]'];
//         const nQueries = dataStrArr.length;
//         const fieldsStr = `(uid,subj,iblk,iseq_abs,iseq_blk,icnd,
//                             it_abs,it_seq,is_guess,targ_shape,targ_blue,
//                             symm,shape,color,is_left,choice_pos,rt, 
//                             l_shape,m_shape,r_shape, 
//                             l_state,m_state,r_state,  
//                             l_color,m_color,r_color,ts)`;

//         let promises = [];
//         for (let i = 0; i < nQueries; i++) {
//             promises.push(new Promise((resolve, reject) => {
//                 resolve(`('${uid}',${subj},${dataStrArr[i]})`);
//             }))
//         }

//         Promise.all(promises)
//             .then((valuesStr) => {
//                 const postQuery = `INSERT INTO resp_table ${fieldsStr} VALUES ${valuesStr};`;
//                 db.execute(postQuery)
//                     .then(([rows]) => {
//                         const nQueried = Object.values(rows)[1];
//                         if (nQueried == nQueries ? resolve(true) : reject(false));
//                     }, error => {
//                         console.log(`Failed INSERT query for subject ${subj} responses!`);
//                         console.log(error);
//                     })
//             })
//     })
// }

// const RESP_CSV_HEADER =
//     'uid,subj,' +
//     'iblk,iseq_abs,iseq_blk,icnd,goalColor,' +
//     'it_abs,it_seq,is_guess,' +
//     'targ_shape,targ_blue,' +
//     'symm,shape,color,is_left,choice_pos,rt,' +
//     'l_shape,m_shape,r_shape,' +
//     'l_state,m_state,r_state,' +
//     'l_color,m_color,r_color,ts\n';

// const RESP_CSV_HEADER =
//     'uid,subj,' +
//     'iblk,iseq_abs,iseq_blk,icnd,goalColor,' +
//     'it_abs,it_seq,is_guess,' +
//     'targ_shape,targ_blue,' +
//     'symm,shape,color,is_left,choice_pos,rt,' +
//     'l_shape,m_shape,r_shape,' +
//     'l_state,m_state,r_state,' +
//     'l_color,m_color,r_color,' +
//     'perf_draw_hits,perf_guess_corr,perf_nTrials,perf_nGuess,perf_avgScore,' +
//     'medalSum,bonusEarned,' +
//     'ts\n';


const RESP_CSV_HEADER =
    'uid,subj,' +
    'iblk,iseq_abs,iseq_blk,icnd,choiceMode,choiceType,probeTargetIdx,goalColor,' +
    'it_abs,it_seq,is_guess,' +
    'targ_shape,targ_blue,' +
    'symm,shape,color,is_left,choice_pos,rt,' +
    'l_shape,m_shape,r_shape,' +
    'l_state,m_state,r_state,' +
    'l_color,m_color,r_color,' +
    'perf_draw_hits,perf_guess_corr,perf_nTrials,perf_nGuess,perf_avgScore,' +
    'medalSum,bonusEarned,' +
    'ts\n';

function postRespData(data) {
    return new Promise((resolve, reject) => {
        const subj = data.subj;
        const uid  = data.uid;
        // const dataStrArr = data['dataStrArr[]']; // array of "iblk,iseq_abs,..." strings

        let dataStrArr = data['dataStrArr[]']; // usually used when multiple rows are sent

        if (dataStrArr === undefined) {
            dataStrArr = data.dataStrArr;      // fallback, depending on how Express parses it
        }

        if (dataStrArr === undefined) {
            dataStrArr = [];
        }

        if (!Array.isArray(dataStrArr)) {
            dataStrArr = [dataStrArr];         // critical fix: one row arrives as a string
        }


        // const csvDir  = path.join(__dirname, '..', 'csv');
        const csvDir  = csvDirAbs; // YC: 15/Jan/2026
        const csvFile = path.join(csvDir, `resp_${uid}.csv`);

        try {
            if (!fs.existsSync(csvDir)) {
                fs.mkdirSync(csvDir, { recursive: true });
            }
        } catch (err) {
            console.error('Failed to create CSV directory', err);
            return reject(false);
        }

        // If file does not exist yet, write header first
        if (!fs.existsSync(csvFile)) {
            fs.writeFileSync(csvFile, RESP_CSV_HEADER);
        }

        // Append data rows
        const lines =
            dataStrArr
                .map(row => `${uid},${subj},${row}`)
                .join('\n') +
            '\n';

        fs.appendFile(csvFile, lines, (err) => {
            if (err) {
                console.error(`Failed to append resp CSV for subj=${subj}, uid=${uid}`, err);
                reject(false);
            } else {
                resolve(true);
            }
        });

    });
}

// function postTimestamp(uid, type) {
//     const postQuery = `UPDATE main_table SET t_${type} = NOW() WHERE uid = \"${uid}\"`;
//     return new Promise((resolve, reject) => {
//         db.execute(postQuery)
//             .then(([rows]) => {
//                 const nQueried = Object.values(rows)[1];
//                 if (nQueried == 1 ? resolve(true) : reject(false));
//             }, error => {
//                 console.log(`Failed INSERT ${type} for uid = ${uid}`);
//                 console.log(error);
//             });
//     })
// }


// function postTimestamp(uid, type) { //YC: 08/Jan/2026 commented out
//     // No database: optionally log to a small text file if you want.
//     return Promise.resolve(true);
// }

function postTimestamp(uid, type) { // YC: 08/Jan/2026 add
  if (type === 'finish') {
    try {
      setStatusByUID(uid, 'finished');
    } catch (e) {
      console.error('Failed to set finished status for uid=', uid, e);
    }
  }
  return Promise.resolve(true);
}


// function postQuesData(data) {
//     const subj = data.subj,
//            uid = data.uid,
//          label = data.label,
//          resps = data.resps;
          
//     const fieldsStr = `(uid,subj,label,responses)`;
//     const valuesStr = `('${uid}',${subj},'${label}','${resps}')`;
//     return new Promise((resolve, reject) => {
//         const postQuery = `INSERT INTO ques_table ${fieldsStr} VALUES ${valuesStr};`;
//         db.execute(postQuery)
//             .then(([rows]) => {
//                 const nQueried = Object.values(rows)[1];
//                 if (nQueried == 1 ? resolve(true) : reject(false));
//             }, error => {
//                 console.log(`Failed INSERT query for subject ${subj} (${label} questionnaire responses!`);
//                 console.log(error);
//             });
//     })
// }
function postQuesData(data) {
    const subj  = data.subj;
    const uid   = data.uid;
    const label = data.label;
    const resps = data.resps;

    // const csvDir  = './csv';
    const csvDir  = csvDirAbs; // YC: 15/Jan/2026
    const csvFile = `${csvDir}/ques_${uid}.csv`;

    return new Promise((resolve, reject) => {
        try {
            if (!fs.existsSync(csvDir)) {
                fs.mkdirSync(csvDir, { recursive: true });
            }
        } catch (err) {
            console.error('Failed to create CSV directory for ques data', err);
            return reject(false);
        }

        if (!fs.existsSync(csvFile)) {
            fs.writeFileSync(csvFile, 'uid,subj,label,resps\n');
        }
        const safeResps = String(resps)
            .replaceAll('"', '""')
            .replaceAll('\n', ' ')
            .replaceAll('\r', ' ');

        const line = `${uid},${subj},${label},"${safeResps}"\n`;

        // const line = `${uid},${subj},${label},${resps}\n`;

        fs.appendFile(csvFile, line, (err) => {
            if (err) {
                console.error(`Failed to append ques CSV for subj=${subj}, uid=${uid}`, err);
                reject(false);
            } else {
                resolve(true);
            }
        });
    });
}

// function postBonus(uid, bonusCode) {
//     const postQuery = `UPDATE main_table SET bonus = '${bonusCode}' WHERE uid = \"${uid}\"`;
//     return new Promise((resolve, reject) => {
//         db.execute(postQuery)
//             .then(([rows]) => {
//                 const nQueried = Object.values(rows)[1];
//                 if (nQueried == 1 ? resolve(true) : reject(false));
//             }, error => {
//                 console.log(`Failed SET bonus for uid = ${uid}`);
//                 console.log(error);
//             })
//     })
// }
function postBonus(uid, bonus) {
    return Promise.resolve(true);
}

// function postComprehension(uid, comp) {
//     const postQuery = `UPDATE main_table SET comp = '${comp}' WHERE uid = \"${uid}\"`;
//     return new Promise((resolve, reject) => {
//         db.execute(postQuery)
//             .then(([rows]) => {
//                 const nQueried = Object.values(rows)[1];
//                 if (nQueried == 1 ? resolve(true) : reject(false));
//             }, error => {
//                 console.log(`Failed SET comp for uid = ${uid}`);
//                 console.log(error);
//             })
//     })
// }
// function postComprehension(uid, comp) {
//     return Promise.resolve(true);
// }

function postComprehension(uid, comp, responsesJson) {
    const csvDir = csvDirAbs;
    const csvFile = path.join(csvDir, 'comprehension.csv');

    return new Promise((resolve, reject) => {
        try {
            if (!fs.existsSync(csvDir)) {
                fs.mkdirSync(csvDir, { recursive: true });
            }
        } catch (err) {
            console.error('Failed to create CSV directory for comprehension', err);
            return reject(false);
        }

        // header once
        if (!fs.existsSync(csvFile)) {
            fs.writeFileSync(csvFile, 'uid,comprehension,responses,ts\n');
        }

        const ts = new Date().toISOString();
        const safeResponses = (responsesJson || '').replaceAll('\n', ' ').replaceAll('\r', ' ');
        const line = `${uid},${comp},"${safeResponses.replaceAll('"', '""')}",${ts}\n`;

        fs.appendFile(csvFile, line, (err) => {
            if (err) {
                console.error(`Failed to append comprehension CSV for uid=${uid}`, err);
                reject(false);
            } else {
                resolve(true);
            }
        });
    });
}

// YC: 20/Jan/2026
function postBonusSummary(uid, medalSum, bonusEarned) {
    const csvDir  = csvDirAbs;
    const csvFile = path.join(csvDir, 'bonus.csv');

    return new Promise((resolve, reject) => {
        try {
            if (!fs.existsSync(csvDir)) {
                fs.mkdirSync(csvDir, { recursive: true });
            }
        } catch (err) {
            console.error('Failed to create CSV directory for bonus', err);
            return reject(false);
        }

        // header once
        if (!fs.existsSync(csvFile)) {
            fs.writeFileSync(csvFile, 'uid,medalSum,bonusEarned,ts\n');
        }

        const ts = new Date().toISOString();
        const line = `${uid},${Number(medalSum)},${Number(bonusEarned)},${ts}\n`;

        fs.appendFile(csvFile, line, (err) => {
            if (err) {
                console.error(`Failed to append bonus CSV for uid=${uid}`, err);
                reject(false);
            } else {
                resolve(true);
            }
        });
    });
}

// function postPreference(uid, pref) {
//     const postQuery = `UPDATE main_table SET pref = '${pref}' WHERE uid = \"${uid}\"`;
//     return new Promise((resolve, reject) => {
//         db.execute(postQuery)
//             .then(([rows]) => {
//                 const nQueried = Object.values(rows)[1];
//                 if (nQueried == 1 ? resolve(true) : reject(false));
//             }, error => {
//                 console.log(`Failed SET pref for uid = ${uid}`);
//                 console.log(error);
//             })
//     })
// }
function postPreference(uid, pref) {
    return Promise.resolve(true);
}


// function postSequence(uid, seqs) {
//     const postQuery = `UPDATE main_table SET seqs = '${seqs}' WHERE uid = \"${uid}\"`;
//     return new Promise((resolve, reject) => {
//         db.execute(postQuery)
//             .then(([rows]) => {
//                 const nQueried = Object.values(rows)[1];
//                 if (nQueried == 1 ? resolve(true) : reject(false));
//             }, error => {
//                 console.log(`Failed SET seqs for uid = ${uid}`);
//                 console.log(error);
//             })
//     })
// }
function postSequence(uid, seq) {
    return Promise.resolve(true);
}

// function postFeedback(uid, feedbackArr) {
//     const entry1 = feedbackArr[0];
//     const entry2 = mysql.escape(feedbackArr[1]);
//     const feedback = entry1.concat('Q0:"' + entry2.slice(1, -1) + '"');
//     const postQuery = `UPDATE main_table SET feedback = '${feedback}' WHERE uid = '${uid}';`;
//     return new Promise((resolve, reject) => {
//         db.execute(postQuery)
//             .then(([rows]) => {
//                 const nQueried = Object.values(rows)[1];
//                 if (nQueried == 1 ? resolve(true) : reject(false));
//             }, error => {
//                 console.log(`Failed SET feedback for uid = ${uid}`);
//                 console.log(error);
//             });
//     })
// }
function postFeedback(uid, feedback) {
    return Promise.resolve(true);
}


exports.checkTables     = checkTables;
exports.fillTaskTable   = fillTaskTable;
exports.isRepeatPID     = isRepeatPID;
exports.getFreeUID      = getFreeUID;
exports.getTaskData     = getTaskData;
exports.getTrainingData = getTrainingData;
exports.postRespData    = postRespData;
exports.postQuesData    = postQuesData;
exports.postTimestamp   = postTimestamp;
exports.postBonus       = postBonus;
exports.postFeedback    = postFeedback;
exports.postComprehension = postComprehension;
exports.postPreference  = postPreference;
exports.postSequence    = postSequence;

exports.postBonusSummary = postBonusSummary; // YC: 20/Jan/2026