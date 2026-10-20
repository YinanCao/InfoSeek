const fs         = require('fs');
const mysql      = require('mysql2');

const db         = require('../utils/database');
const queries    = require('../queries/queries');
const dataParser = require('../utils/dataParser');
const {resolve}  = require('path');

const db_names   = ['main_table', 'task_table', 'resp_table', 'ques_table'];
const nTables    = db_names.length;
const data_dirNames  = fs.readdirSync('./data/').filter(x => {
    return x != '.DS_Store'
});
const uids = data_dirNames.map(x => x.slice(0));

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
function checkTables() {
    return new Promise((resolve, reject) => {
        getNEmpty()
            .then((nEmpty) => {
                if (nEmpty == nTables) { // if the database is empty, build tables
                    buildAllTables()
                        .then(() => { // then fill task_table and main_table with data from data text files
                            return fillTaskTable()
                        })
                        .then(resolve('The database is completely empty! Building tables...'))
                        .catch(err => console.log(err));

                } else if (nEmpty > 0) {
                    resolve(`There are ${nEmpty} tables in the database. This is strange. Check manually.`);
                } else {
                    resolve(`All tables found (${nEmpty} tables returned from query)!`)
                }
            })
            .catch((err) => console.log(err))
    });
}

/* Checks for repeated PIDs in main_table*/
function isRepeatPID(pid) {
    const checkQuery = `SELECT EXISTS(SELECT * FROM main_table WHERE pid = "${pid}");`
    return new Promise((resolve, reject) => {
        db.execute(checkQuery)
            .then(([rows]) => {
                resolve(!!Object.values(rows[0])[0]);
            })
    })
}

/* Gets a free UID (and subject number) for new incoming PIDs */
function getFreeUID(pid) {
    return new Promise((resolve, reject) => {
        const getQuery = `SELECT uid, subj FROM main_table WHERE pid IS NULL LIMIT 1;`
        db.execute(getQuery)
            .then(([rows]) => {
                const vals = Object.values(rows[0]);
                const dataObj = {
                    uid: vals[0],
                    subj: vals[1],
                }
                // assign the PID to this UID //DEBUG: need to uncomment when testing uniqueness 
                const updateQuery = `UPDATE main_table SET pid = "${pid}", 
                                                        t_init = NOW() 
                                     WHERE uid = "${vals[0]}";`

                db.execute(updateQuery)
                    .then(() => {
                        resolve(dataObj);
                    }, rej => {
                        console.log(`Caught duplicate entry error with PID : ${pid}`);
                        reject(rej);
                    });
            })
    })
}

function getTaskData(uid) {
    const getQuery = `SELECT data FROM task_table WHERE uid = "${uid}"`;

    return new Promise((resolve, reject) => {
        db.execute(getQuery)
            .then(([rows]) => {
                resolve(Object.values(rows[0])[0]);
            });
    })
}

function getTrainingData() {
    const getQuery = `SELECT data FROM task_table WHERE uid = "000TRAINING"`;

    return new Promise((resolve, reject) => {
        db.execute(getQuery)
            .then(([rows]) => {
                resolve(Object.values(rows[0])[0]);
            });
    })
}

function postRespData(data) {
    return new Promise((resolve, reject) => {
        const subj = data.subj,
              uid = data.uid,
              dataStrArr = data['dataStrArr[]'];
        const nQueries = dataStrArr.length;
        const fieldsStr = `(uid,subj,iblk,iseq_abs,iseq_blk,icnd,
                            it_abs,it_seq,is_guess,targ_shape,targ_blue,
                            symm,shape,color,is_left,rt,ts)`;

        let promises = [];
        for (let i = 0; i < nQueries; i++) {
            promises.push(new Promise((resolve, reject) => {
                resolve(`('${uid}',${subj},${dataStrArr[i]})`);
            }))
        }

        Promise.all(promises)
            .then((valuesStr) => {
                const postQuery = `INSERT INTO resp_table ${fieldsStr} VALUES ${valuesStr};`;
                db.execute(postQuery)
                    .then(([rows]) => {
                        const nQueried = Object.values(rows)[1];
                        if (nQueried == nQueries ? resolve(true) : reject(false));
                    }, error => {
                        console.log(`Failed INSERT query for subject ${subj} responses!`);
                        console.log(error);
                    })
            })
    })
}

function postTimestamp(uid, type) {
    const postQuery = `UPDATE main_table SET t_${type} = NOW() WHERE uid = \"${uid}\"`;
    return new Promise((resolve, reject) => {
        db.execute(postQuery)
            .then(([rows]) => {
                const nQueried = Object.values(rows)[1];
                if (nQueried == 1 ? resolve(true) : reject(false));
            }, error => {
                console.log(`Failed INSERT ${type} for uid = ${uid}`);
                console.log(error);
            });
    })
}

function postQuesData(data) {
    const subj = data.subj,
           uid = data.uid,
         label = data.label,
         resps = data.resps;
          
    const fieldsStr = `(uid,subj,label,responses)`;
    const valuesStr = `('${uid}',${subj},'${label}','${resps}')`;
    return new Promise((resolve, reject) => {
        const postQuery = `INSERT INTO ques_table ${fieldsStr} VALUES ${valuesStr};`;
        db.execute(postQuery)
            .then(([rows]) => {
                const nQueried = Object.values(rows)[1];
                if (nQueried == 1 ? resolve(true) : reject(false));
            }, error => {
                console.log(`Failed INSERT query for subject ${subj} (${label} questionnaire responses!`);
                console.log(error);
            });
    })
}

function postBonus(uid, bonusCode) {
    const postQuery = `UPDATE main_table SET bonus = '${bonusCode}' WHERE uid = \"${uid}\"`;
    return new Promise((resolve, reject) => {
        db.execute(postQuery)
            .then(([rows]) => {
                const nQueried = Object.values(rows)[1];
                if (nQueried == 1 ? resolve(true) : reject(false));
            }, error => {
                console.log(`Failed SET bonus for uid = ${uid}`);
                console.log(error);
            })
    })
}

function postComprehension(uid, comp) {
    const postQuery = `UPDATE main_table SET comp = '${comp}' WHERE uid = \"${uid}\"`;
    return new Promise((resolve, reject) => {
        db.execute(postQuery)
            .then(([rows]) => {
                const nQueried = Object.values(rows)[1];
                if (nQueried == 1 ? resolve(true) : reject(false));
            }, error => {
                console.log(`Failed SET comp for uid = ${uid}`);
                console.log(error);
            })
    })
}

function postPreference(uid, pref) {
    const postQuery = `UPDATE main_table SET pref = '${pref}' WHERE uid = \"${uid}\"`;
    return new Promise((resolve, reject) => {
        db.execute(postQuery)
            .then(([rows]) => {
                const nQueried = Object.values(rows)[1];
                if (nQueried == 1 ? resolve(true) : reject(false));
            }, error => {
                console.log(`Failed SET pref for uid = ${uid}`);
                console.log(error);
            })
    })
}
function postPreference(uid, pref) {
    const postQuery = `UPDATE main_table SET pref = '${pref}' WHERE uid = \"${uid}\"`;
    return new Promise((resolve, reject) => {
        db.execute(postQuery)
            .then(([rows]) => {
                const nQueried = Object.values(rows)[1];
                if (nQueried == 1 ? resolve(true) : reject(false));
            }, error => {
                console.log(`Failed SET pref for uid = ${uid}`);
                console.log(error);
            })
    })
}
function postSequence(uid, seqs) {
    const postQuery = `UPDATE main_table SET seqs = '${seqs}' WHERE uid = \"${uid}\"`;
    return new Promise((resolve, reject) => {
        db.execute(postQuery)
            .then(([rows]) => {
                const nQueried = Object.values(rows)[1];
                if (nQueried == 1 ? resolve(true) : reject(false));
            }, error => {
                console.log(`Failed SET seqs for uid = ${uid}`);
                console.log(error);
            })
    })
}

function postFeedback(uid, feedbackArr) {
    const entry1 = feedbackArr[0];
    const entry2 = mysql.escape(feedbackArr[1]);
    const feedback = entry1.concat('Q0:"' + entry2.slice(1, -1) + '"');
    const postQuery = `UPDATE main_table SET feedback = '${feedback}' WHERE uid = '${uid}';`;
    return new Promise((resolve, reject) => {
        db.execute(postQuery)
            .then(([rows]) => {
                const nQueried = Object.values(rows)[1];
                if (nQueried == 1 ? resolve(true) : reject(false));
            }, error => {
                console.log(`Failed SET feedback for uid = ${uid}`);
                console.log(error);
            });
    })
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