const http          = require('http');
const fs            = require('fs');
const express       = require('express');
const path          = require('path');
const bodyParser    = require('body-parser');
const app = express();

// app.use((req, res, next) => {
//   console.log("REQ", req.method, req.originalUrl);
//   next();
// });

// app.get(['/__ping','/colexpforced/__ping'], (req, res) => {
//   res.status(200).send('pong');
// });

const dataParser    = require('./utils/dataParser');
const dbFns         = require('./utils/dbFunctions')

const finishCode    = 'C1K08A9W'; //update this part from prolific

// define listening port
app.set('port', process.env.PORT || 8080);

// launch Express server
var server = http.createServer(app);
server.listen(app.get('port'), function () {
  console.log("Express server listening on port " + app.get('port'));
});

app.use(bodyParser.urlencoded({extended: false})); // specify what is to be parsed
app.use(express.static(path.join(__dirname,'public'))); // statically serve the contents of public folder to client
app.use('/colexpforced', express.static(path.join(__dirname,'public')));
app.use((req, res, next) => {
  req.url = req.url.replace(/\/{2,}/g, '/');
  next();
});
// check for database tables and create/fill if empty
dbFns.checkTables()
.then(res => {
    console.log(res);
});

/* HTTP calls */
app.post(['/get_task_data','/colexpforced/get_task_data'], (req, res, next) => {
    console.log('Task data requested!');
    const pid = req.body.pid;

    // get free UID for requesting PID
    // .then() organize the data and send to client in JSON format
    dbFns.getFreeUID(pid)
    .then(dataObj => {
        const subj_id = dataObj.subj;
        const unique_id = dataObj.uid;
        const promises = [dbFns.getTaskData(unique_id), dbFns.getTrainingData()];

        Promise.all(promises)
        .then(textdata => {
            // parse the data text
            const blockdat = Array.from(textdata[0].split('#'), x => x.slice(1,-1));
            const expArray = new Array(blockdat.length);
            for (i = 0; i < blockdat.length; i++) {
                expArray[i] = dataParser.makeBlockObj(blockdat[i]);
            }
            const traindat = Array.from(textdata[1].split('#'), x => x.slice(1,-1));
            const trainArray = new Array(traindat.length);
            for (i = 0; i < traindat.length; i++) {
                trainArray[i] = dataParser.makeBlockObj(traindat[i]);
            }
            
            const taskData = {
                subj_id: subj_id,
                unique_id: unique_id,
                data: expArray,
                trainData: trainArray,
                finishCode: finishCode,
            };
            console.log(`Sent task data to PID ${pid}!`);
            res.send(taskData);
        });
        
    })
    .catch(err => {
        res.status(500).send({error: 'There are issues with your Prolific ID... please contact the experimenter'});
        console.log(`Task data request rejected for PID ${pid} (duplicate)`);
    })
});

/* SQL batch queries responses into database */
app.post(['/post_response','/colexpforced/post_response'], (req, res, next) => {
    const data = req.body;
    dbFns.postRespData(data)
        .then((isLogged) => res.send(isLogged));
});

/* SQL queries questionnaire responses into database */
app.post(['/post_questionnaire','/colexpforced/post_questionnaire'], (req, res, next) => {
    const data = req.body;
    dbFns.postQuesData(data)
        .then((isLogged) => res.send(isLogged));
});

/* SQL queries a timestamp into database */
app.post(['/post_timestamp','/colexpforced/post_timestamp'], (req, res, next) => {
    const uid = req.body.uid;
    const type = req.body.type;
    console.log(`${uid} ${type}ed the task!`);
    dbFns.postTimestamp(uid, type);
});

/* SQL queries whether subject got the bonus */
app.post(['/post_bonus','/colexpforced/post_bonus'], (req, res, next) => {
    const uid = req.body.uid;
    const bonus = req.body.bonus;
    console.log(`${uid} sent bonus data!`);
    dbFns.postBonus(uid, bonus);
});

// YC: 20/Jan/2026
app.post(['/post_bonus_summary', '/colexpforced/post_bonus_summary'], (req, res) => {
    const uid = req.body.uid;
    const medalSum = req.body.medalSum;
    const bonusEarned = req.body.bonusEarned;

    dbFns.postBonusSummary(uid, medalSum, bonusEarned)
        .then(() => res.send(true))
        .catch(() => res.send(false));
});

app.post(['/post_comprehension','/colexpforced/post_comprehension'], (req, res, next) => {
    const uid = req.body.uid;
    const comprehension = req.body.comprehension;
    console.log(`${uid} sent comprehension check!`)
    dbFns.postComprehension(uid, comprehension); 
});

app.post(['/post_preference','/colexpforced/post_preference'], (req, res, next) => {
    const uid = req.body.uid;
    const preference = req.body.preference;
    dbFns.postPreference(uid, preference); 
});

app.post(['/post_sequence','/colexpforced/post_sequence'], (req, res, next) => {
    const uid = req.body.uid;
    const sequence = req.body.sequence;
    dbFns.postSequence(uid, sequence); 
});

/* SQL queries the feedback received from subject at the end of task into database */
app.post(['/post_fb','/colexpforced/post_fb'], (req, res, next) => {
    const uid = req.body.uid,
     feedback = [req.body.entry1, req.body.entry2];
    console.log(`${uid} sent feedback information!`)
    dbFns.postFeedback(uid,feedback);
});


/* Initial request to server (link access) */
// app.get('/', (req, res, next) => {
app.get(['/', '/colexpforced', '/colexpforced/'], (req, res, next) => {
    const pid   = req.query.pid;
    const ip    = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    if (Object.keys(req.query).length == 0) {
        res.status(404).send(`<h1>Access Denied:<h1/>
            <p>Please access the study with the link provided by Prolific.</p>`)
    } 
    else if (pid.length != 24) { // verify length of PID
        res.status(404).send('<h1>Prolific ID invalid.</h1>');
        console.log(`Client (ip: ${ip}) has an invalid PID!`)
    } else {
        // post IP address of participant (for debugging purposes)
        console.log(`Client (pid: ${pid}, ip: ${ip}) requesting task!`);

        // DEBUG: get browser type for test
        console.log(`Browser (pid: ${pid}): ` + req.headers["user-agent"]);

        // check for PID repeat in database
        // dbFns.isRepeatPID()
        dbFns.isRepeatPID(pid) // YC: 08/Jan/2026
            .then(isRepeat => {
                if (isRepeat) {
                    res.status(404).send(`<h1>You have already accessed the study! 
                        If this is an error, contact the experimenter.</h1>`);
                } else {
                    // send the client the run_task page
                    res.sendFile(path.join(__dirname,'frontend','run_task.html'));
                }
            });
    }
})

/* 404 error page */
app.use((req, res, next) => {
    res.status(404).send('<h1>Page not found. Please contact the experimenter.</h1>');
})

