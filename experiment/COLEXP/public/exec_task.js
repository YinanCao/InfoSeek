import { StimulusOptions, StimulusProbe, StimulusProgress, StimulusBlockEnd, StimulusTaskEnd,
         RespDataTemplate, is_left } from './modules/task_modules.js'
import { instruction_stim, training_stim } from './modules/instructions_module.js'
import ques_stim from './modules/questionnaire_module.js'
// import get_feedback from './get_feedback.js';

export default function exec_task(task_data) {
    let timeline = [];

    const debugFlag = false; //DEBUG

    const { choiceSet, containerElement, reverseIndex, isBlue, inst_imgs,
            outcomeDuration, ITIDuration, probeSelDuration, introDuration, 
            postInstDuration, probeFBDuration, minBreakDuration,
            nb_total } = task_data.constants

    const   taskData = task_data.data,
            trainData = task_data.trainData[0],
            subj = task_data.sid,
            UID = task_data.uid,
            finishCode = task_data.finishCode;
    
    // performance counting array nBlocks x conditions(2)
    window.bonusCounter = Array.from({length: taskData.length}, () => {
        return new Array(2).fill(0)
    });
    // medal counting array for bonus payments
    window.medalCounter = Array(nb_total).fill(0);

    const trialDuration = (duration) => {
        return (debugFlag ? 200 : duration)
    };

    // convert streak lengths to indexable array
    const sides = (streaksArray) => {
        let sideArr = [];
        for (let i = 0; i < streaksArray.length; i++) {
            sideArr = sideArr.concat(Array(streaksArray[i]).fill(i%2));
        }
        return sideArr
    };
    let RESPONSE_BUFFER = [];

    // preload images for the instructions stimuli
    const preload = {
        type: 'preload',
        images: inst_imgs,
    };
    timeline.push(preload);

    /* testing (THIS BLOCK MUST BE ABSOLUTELY CLEAR BEFORE LAUNCH) */
   
    /* */

    // Present consent form
    const check_consent = () => {
        if (document.getElementById('consent_checkbox').checked) {
            return true;
        } else {
            alert("If you wish to participate, you must check the box next to the statement 'I agree to participate in this study.'");
            return false;
        }
    };
    
    // declare the consent block
    const consent_trial = {
        type: 'external-html',
        url: "consent_form/consentpg_rlinf.html",
        cont_btn: "startbutton",
        check_fn: check_consent
    }
    if (!debugFlag) {
        timeline.push(consent_trial); //DEBUG
    }

    // make fullscreen 
    const fullscreen = {
        type: 'fullscreen',
        showtext: '<p>To take part in the experiment, your browser must be in fullscreen mode.<br></br>Please click the button below to enable fullscreen mode and continue.</p>',
        buttontext: "Fullscreen",
    };
    if (!debugFlag) timeline.push(fullscreen); //DEBUG - uncomment before launch
    
    // instructions for the DISCOVER condition
    const instr_disc = {
        get timeline() {
            let stims = [];
            // Initial instructions
            Array.from([...Array(4).keys()].map(x => instruction_stim('disc', x))).forEach(x => stims.push(x));
            // Sample trials
            const sideOpt1 = task_data.constants.sidesTutDisc;
            const colors = task_data.constants.colorsTutDisc;
            const shapes = task_data.constants.shapesTutDisc;
            for (let i = 0; i < sideOpt1.length; i++) {
                const bagInputOne = [1,shapes[0],colors[0][i],null];
                const bagInputTwo = [1,shapes[1],colors[1][i],null];
                const bagInputs = new Array(2);
                      bagInputs[sideOpt1[i]] = bagInputOne;
                      bagInputs[Number(!sideOpt1[i])] = bagInputTwo;
                for (let j = 0; j < 2; j++) {
                    const cfg = {
                        isTutorial: true,
                        isTraining: false,
                        bagInputs: bagInputs,
                        trialData: {
                            trialState: j
                        }
                    }
                    stims.push(new stimChild_trial(cfg));
                }
            }
            // Probe trial 
            for (let i = 0; i < 3; i++) {
                const cfg = {
                    isTutorial: true,
                    isTraining: false,
                    target: {
                        shape: shapes[0],
                        color: 1,
                    },
                    isBlue: [0,1],
                    trialData: {
                        trialState: i,
                    },
                }
                stims.push(new stimChild_probe(cfg));
            }
            // The rest of the instructions
            stims.push(instruction_stim('disc', 4));
            stims.push(instruction_stim('disc', 5));

            return stims
        }
    };

    // instructions for the DRAW condition
    const instr_draw =  {
        get timeline() {
            let stims = [];
            // Initial instructions
            Array.from([...Array(5).keys()].map(x => instruction_stim('draw', x))).forEach(x => stims.push(x));
            // Sample trials
            const sideOpt1 = task_data.constants.sidesTutDraw;
            const colors = task_data.constants.colorsTutDraw;
            const shapes = task_data.constants.shapesTutDraw;
            for (let i = 0; i < sideOpt1.length; i++) {
                const bagInputOne = [1,shapes[0],colors[0][i],null];
                const bagInputTwo = [1,shapes[1],colors[1][i],null];
                const bagInputs = new Array(2);
                      bagInputs[sideOpt1[i]] = bagInputOne;
                      bagInputs[Number(!sideOpt1[i])] = bagInputTwo;
                for (let j = 0; j < 2; j++) {
                    const cfg = {
                        isTutorial: true,
                        bagInputs: bagInputs,
                        trialData: {
                            trialState: j
                        }
                    }
                    stims.push(new stimChild_trial(cfg));
                }
            }
            // The rest of the instructions
            if (!debugFlag) stims.push(instruction_stim('draw', 5));
            return stims
        }
    };

    // 1. Instructions to read carefully
    if (!debugFlag) timeline.push(instruction_stim('read_prompt'));
    
    // 2. Instructions for bags
    const instr_bags = {
        timeline: Array.from([...Array(8).keys()].map(x => instruction_stim('bags', x)))
    }
    if (!debugFlag) timeline.push(instr_bags);

    // 3. Instructions for the 2 conditions (odd subjects start with DRAW)
    if (subj % 2 == 1) {
        if (!debugFlag) timeline.push(instr_draw, instr_disc); 
    } else {
        if (!debugFlag) timeline.push(instr_disc, instr_draw); 
    }

    // 4. Instructions for overview
    const instr_overview = {
        timeline: Array.from([...Array(3).keys()].map(x => instruction_stim('overview', x)))
    };
    if (!debugFlag) timeline.push(instr_overview);

    // 5. Instructions for reminders
    const instr_keepinmind = {
        timeline: Array.from([...Array(6).keys()].map(x => instruction_stim('keepinmind', x)))
    }
    if (!debugFlag) timeline.push(instr_keepinmind);

    // 6. Training block
    let nt_totalTraining;
    window.trainCounter = Array(2).fill(0);
    const loadTraining = () => {
        if (!debugFlag) timeline.push(training_stim('prompt'));

        for (let iseq = 0; iseq < trainData.blockTrials.length; iseq++) {
            const blockInfo = trainData.blockInfo[iseq];
            const sideStrks = trainData.blockSides[iseq];
            const trialVals = trainData.blockTrials[iseq];
            
            // training sequence parameters
            const cond      = blockInfo[0]; // 1: draw, 2: guess
            const shapes    = [blockInfo[1],blockInfo[2]];
            const goalColor = blockInfo[3]; // 1: blue, 0: orange
            const symmType  = blockInfo[4]; // 1,2 symm, anti-symm; 3 not symm
            const isSymm    = symmType < 3;
    
            const randNum = Math.round(Math.random()*100);
            const leftSideShape = sides(sideStrks).map(x => {
                return (x + randNum) % 2 == 0
            });

            // training trial loop
            for (let itrial = 0; itrial < trialVals.length; itrial++) {
                if (cond == 1) {
                    nt_totalTraining = nt_totalTraining + trialVals.length;
                }
                // sides: 0/ index of left bag shape, 1/ index of right bag shape
                const sides = [Number(leftSideShape[itrial]), Number(!leftSideShape[itrial])];
                const colorIndex = (side,index) => {
                    if (side == 0) {
                        return index
                    } else {
                        return (isSymm) ? index : reverseIndex[index-1]; 
                    }
                }
                // inputs for the bag Object
                const bagInputs = new Array(2);
                const bagInputLeft = [1,shapes[sides[0]],colorIndex(sides[0],trialVals[itrial]),null];
                const bagInputRight = [1,shapes[sides[1]],colorIndex(sides[1],trialVals[itrial]),null];
                bagInputs[0] = bagInputLeft;
                bagInputs[1] = bagInputRight;
    
                // generate stimulus to introduce the sequence
                if (itrial == 0) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: true,
                        bagInputs: bagInputs,
                        trialData: {
                            trialState: 2,
                            condition: cond,
                            goalColor: goalColor,
                            iblock: 0,
                            iseq: iseq,
                        },
                    };
                    if (!debugFlag) timeline.push(new stimChild_trial(cfg));
                }
                
                // generate stimuli for the 2-state standard training trial 
                for (let i = 0; i < 2; i++) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: true,
                        bagInputs: bagInputs,
                        shapes: [bagInputs[0][1],bagInputs[1][1]],
                        colors: [bagInputs[0][2],bagInputs[1][2]],
                        trialData: {
                            trialState: i,
                            iblk: 0,
                            iseq_abs: 0,
                            iseq_blk: iseq+1,
                            icnd: cond,
                            it_abs: 0,
                            it_seq: itrial+1,
                            symm: symmType,
                            is_guess: false,
                            targ_shape: shapes[0],
                            targ_blue: goalColor
                        },
                        get doDump() {
                            return (cond == 1 ? (itrial == trialVals.length-1) : false)
                        }
                    };
                    if (!debugFlag) timeline.push(new stimChild_trial(cfg));
                }
            } //end training trial loop

            if (cond == 2) { // final question trial for the GUESS condition
                const leftSide = leftSideShape.slice(-1)[0];
                const side = [Number(leftSide), Number(!leftSide)];
                const isTargetBlue = () => { // 1 if blue, 0 if orange
                    // implement XNOR logic gate with '==='
                    return Number(Number(symmType % 2 == 1) === goalColor);
                }
                // generate stimuli for the 3-state probe trial
                for (let i = 0; i < 3; i++) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: true,
                        target: {
                            shape: shapes[0],
                            color: isBlue[isTargetBlue()],
                        },
                        isBlue: side,
                        trialData: {
                            trialState: i,
                            iblk: 0,
                            iseq_abs: 0,
                            iseq_blk: iseq+1,
                            icnd: cond,
                            it_abs: 0,
                            it_seq: trialVals.length+1,
                            symm: symmType,
                            is_guess: true,
                            targ_shape: shapes[0],
                            targ_blue: isTargetBlue()
                        },
                        doDump: true
                    }
                    if (!debugFlag) timeline.push(new stimChild_probe(cfg));
                }
            }
        }
        // Show progress and performance at the end of the training block with some explanation
        if (!debugFlag) timeline.push(StimulusBlockEnd(-1));
        if (!debugFlag) timeline.push(training_stim('medals'));
        const cfg = {
            nTrials : nt_totalTraining,
            iblock  : -1,
        };
        timeline.push(new stimChild_progress(cfg));
    }
    if (!debugFlag) loadTraining();

    const trialsPerBlockInDraw = new Array(taskData.length);

    // experiment loop
    let it_abs = 0;
    let iseq_abs = 0;
    for (let iblock = 0; iblock < taskData.length; iblock++) {
        const blockData = taskData[iblock];

        // start of new block stimulus
        const stimBlockStart = {
            type: 'html-keyboard-response-min-duration',
            stimulus: () => {
                const container = containerElement();
                // text
                const div = document.createElement('div');
                div.appendChild(document.createTextNode(`Block ${iblock+1}/${taskData.length}`));
                container.appendChild(div);
                // spacebar text
                const div_continueSpacebar = document.createElement('div');
                    div_continueSpacebar.style.width = '100%';
                    div_continueSpacebar.style.position = 'absolute';
                    div_continueSpacebar.style.top = '92%';
                    div_continueSpacebar.style.left = '50%';
                    div_continueSpacebar.style.transform = "translate(-50%, -92%)";
                div_continueSpacebar.appendChild(document.createTextNode('Press [spacebar] to continue'));
                container.appendChild(div_continueSpacebar);
            
                return container.innerHTML
            }
        }
        timeline.push(stimBlockStart);

        let it_blk = 0;
        for (let iseq = 0; iseq < blockData.blockTrials.length; iseq++) {
            iseq_abs++; 

            const blockInfo = blockData.blockInfo[iseq];
            const sideStrks = blockData.blockSides[iseq];
            const trialVals = blockData.blockTrials[iseq];
            
            // sequence parameters
            const cond      = blockInfo[0]; // 1: draw, 2: guess
            const shapes    = [blockInfo[1],blockInfo[2]];
            const goalColor = blockInfo[3]; // 1: blue, 0: orange
            const symmType  = blockInfo[4]; // 1,2 symm, anti-symm; 3 not symm
            const isSymm    = symmType < 3;

            // const randNum = Math.round(Math.random()*100);
            const leftSideShape = sides(sideStrks).map(x => {
                // return (x + randNum) % 2 == 0
                return x % 2 == 0

            });

            for (let itrial = 0; itrial < trialVals.length; itrial++) {
                if (cond == 1) it_blk++;
                it_abs++;
                // sides: 0/ index of left bag shape, 1/ index of right bag shape
                const sides = [Number(leftSideShape[itrial]), Number(!leftSideShape[itrial])];

                // the value of trialVals[itrial] belongs on shapes[0]
                //  if isSymm, shapes[1] takes the same as shapes[0]
                //      else, shapes[1] takes the inverted index of shapes[0]
                const colorIndex = (side,index) => {
                    if (side == 0) {
                        return index
                    } else {
                        return (isSymm) ? index : reverseIndex[index-1]; 
                    }
                }
                // inputs for the bag Object
                const bagInputs = new Array(2);
                const bagInputLeft = [1,shapes[sides[0]],colorIndex(sides[0],trialVals[itrial]),null];
                const bagInputRight = [1,shapes[sides[1]],colorIndex(sides[1],trialVals[itrial]),null];
                bagInputs[0] = bagInputLeft;
                bagInputs[1] = bagInputRight;

                // generate stimulus to introduce the sequence
                if (itrial == 0) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: false,
                        bagInputs: bagInputs,
                        trialData: {
                            trialState: 2,
                            condition: cond,
                            goalColor: goalColor,
                            iblock: iblock,
                            iseq: iseq,
                        },
                    };
                    timeline.push(new stimChild_trial(cfg));
                }
                
                // generate stimuli for the 2-state standard trial 
                for (let i = 0; i < 2; i++) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: false,
                        bagInputs: bagInputs,
                        shapes: [bagInputs[0][1],bagInputs[1][1]],
                        colors: [bagInputs[0][2],bagInputs[1][2]],
                        trialData: {
                            trialState: i,
                            iblk: iblock+1,
                            iseq_abs: iseq_abs,
                            iseq_blk: iseq+1,
                            icnd: cond,
                            it_abs: it_abs,
                            it_seq: itrial+1,
                            symm: symmType,
                            is_guess: false,
                            targ_shape: shapes[0],
                            targ_blue: goalColor
                        },
                        get doDump() {
                            return (cond == 1 ? (itrial == trialVals.length-1) : false)
                        }
                    };
                    timeline.push(new stimChild_trial(cfg)); 
                }
            } //end trial loop
            
            // final question trial for the GUESS condition
            if (cond == 2) {
                // blank screen
                timeline.push({
                    type: 'html-keyboard-response',
                    stimulus: ' ',
                    trial_duration: 300
                });
                it_abs++;
                const leftSide = leftSideShape.slice(-1)[0]; // takes the last value of the array
                const side = [Number(leftSide), Number(!leftSide)];
                const isTargetBlue = () => { // 1 if blue, 0 if orange
                    // implement XNOR logic gate with '==='
                    return Number(Number(symmType % 2 == 1) === goalColor);
                }
                // generate stimuli for the 3-state probe trial
                for (let i = 0; i < 3; i++) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: false,
                        target: {
                            shape: shapes[0],
                            color: isBlue[isTargetBlue()],
                        },
                        isBlue: side,
                        trialData: {
                            trialState: i,
                            iblk: iblock+1,
                            iseq_abs: iseq_abs,
                            iseq_blk: iseq+1,
                            icnd: cond,
                            it_abs: it_abs,
                            it_seq: trialVals.length+1,
                            symm: symmType,
                            is_guess: true,
                            targ_shape: shapes[0],
                            targ_blue: isTargetBlue()
                        },
                        doDump: true
                    }
                    timeline.push(new stimChild_probe(cfg));
                }
            }
        }
        // Show progress and performance at the end of a block
        timeline.push(StimulusBlockEnd(iblock));
        trialsPerBlockInDraw[iblock] = it_blk;
        const cfg = {
            nTrials : trialsPerBlockInDraw[iblock],
            iblock: iblock
        };
        timeline.push(new stimChild_progress(cfg));
        
        // break stimulus
        const stimBreak = (letContinue) => {
            const stimObject = {
                type: 'html-keyboard-response-min-duration',
                stimulus: () => {
                    const container = containerElement();
                    // text
                    const div = document.createElement('div');
                    div.appendChild(document.createTextNode('You may take a short break here before moving on to the next block.'));
                    div.appendChild(document.createElement('br'));
                    div.appendChild(document.createTextNode('You will be able to continue in 2 seconds.'));
                    div.appendChild(document.createElement('br'));
                    container.appendChild(div);
                    
                    // spacebar text
                    if (letContinue) {
                        const div_continueSpacebar = document.createElement('div');
                            div_continueSpacebar.style.width = '100%';
                            div_continueSpacebar.style.position = 'absolute';
                            div_continueSpacebar.style.top = '92%';
                            div_continueSpacebar.style.left = '50%';
                            div_continueSpacebar.style.transform = "translate(-50%, -92%)";
                        div_continueSpacebar.appendChild(document.createTextNode('Press [spacebar] to continue'));
                        container.appendChild(div_continueSpacebar);
                    }

                    return container.innerHTML
                },
            }
            if (!letContinue) {
                stimObject.minimum_duration = trialDuration(minBreakDuration);
            }
            
            return stimObject
        }
        if (iblock < taskData.length-1) { // no break at the end of the last block
            timeline.push(stimBreak(false));
            timeline.push(stimBreak(true));
        }
    }

    // 7. Comprehension check
    const comprehensionCheckObject = () => {
        const questions = [
            `If one bag is blue, can you guess the colour of the other bag without drawing from it?`,
            `Are all the shapes in the bag of exactly the same shade?`,
            `In the <strong>DRAWING</strong> games, how to you win points?`,
            `In the <strong>DISCOVERING</strong> games, how do you win points?`,
        ];
        const responses = [
            ['Yes', 'No'],
            [`Based on how well you've drawn of the requested colour`, `If you are correct at the final question when the series ends`]
        ]

        let q_arr = [];
        for (let i = 0; i < questions.length; i++) {
            q_arr.push({
                prompt: `${i+1}) ${questions[i]}`,
                options: responses[Number(i > 1)],
                required: true
            });
        }
        return {
            type: 'survey-multi-choice',
            questions: q_arr,
            preamble: 'Please answer some questions about your understanding of the task.',
            on_finish: (data) => {
                const compValArr = Object.values(data.response).map(val => {
                    if ([responses[0][0], responses[1][0]].includes(val)) {
                        return 0
                    } else {
                        return 1
                    }
                });
                const dataPacket = {
                    uid: UID,
                    comprehension: compValArr.toString().split(',').join(''),
                };
                // send to server
                $.ajax({
                    url: '/post_comprehension',
                    type: 'POST',
                    data: dataPacket,
                });
            }
        }
    }
    timeline.push(comprehensionCheckObject());

    // 8. Task preference question
    const preferenceCheckObject = {
        type: 'html-slider-response',
        stimulus: 'Overall, which game did you prefer?',
        labels: ['DRAWING', 'DISCOVERING'],
        min: 1,
        max: 100,
        require_movement: true,
        on_finish: (data) => {
            const dataPacket = {
                uid: UID,
                preference: data.response.toString()
            };
            // send to server
            $.ajax({
                url: '/post_preference',
                type: 'POST',
                data: dataPacket,
            });
        }
    };
    timeline.push(preferenceCheckObject);

    // 9. Sequence length questions
    const sequenceCheckObject = {
        type: 'survey-text',
        questions: [
            {prompt: `What was the shortest sequence you played (i.e. the smallest number of choices you made in a sequence)? -- <strong>Please type in a number</strong>."`}, 
            {prompt: `What was the average length of the sequences (i.e. the average number of choices you made in a sequence)? -- <strong>Please type in a number</strong>.`}
        ],
        on_finish: (data) => {
            // truncate the input to contain only 5 characters
            const dataPacket = {
                uid: UID,
                sequence: data.response.Q0.substring(0,5).concat(',',data.response.Q1.substring(0,5)).toString()
            };
            // send to server
            $.ajax({
                url: '/post_sequence',
                type: 'POST',
                data: dataPacket,
            });
        }
    };
    timeline.push(sequenceCheckObject);

    const stimPreQuesObject = (letContinue) => {
        const stimObject = {
            type: 'html-keyboard-response-min-duration',
            stimulus: () => {
                const container = containerElement();
                // text
                const div = document.createElement('div');
                div.appendChild(document.createTextNode('Congratulations! You have reached the end of the games.'));
                div.appendChild(document.createElement('br')); div.appendChild(document.createElement('br')); 
                div.appendChild(document.createTextNode('Now, we will move on to the questionnaire part of the study.'));
                div.appendChild(document.createElement('br')); div.appendChild(document.createElement('br')); 
                div.appendChild(document.createTextNode(`You will answer questions about yourself (~10-15 minutes) and solve a few puzzles.`));
                div.appendChild(document.createElement('br')); div.appendChild(document.createElement('br')); 
                div.appendChild(document.createTextNode('Before moving on to the questionnaire, you may take a break.'));
                div.appendChild(document.createElement('br')); div.appendChild(document.createElement('br')); 
                div.appendChild(document.createTextNode('You will be able to continue in 20 seconds.'));
                div.appendChild(document.createElement('br'));
                container.appendChild(div);

                // spacebar text
                if (letContinue) {
                    const div_continueSpacebar = document.createElement('div');
                    div_continueSpacebar.style.width = '100%';
                    div_continueSpacebar.style.position = 'absolute';
                    div_continueSpacebar.style.top = '92%';
                    div_continueSpacebar.style.left = '50%';
                    div_continueSpacebar.style.transform = "translate(-50%, -92%)";
                    div_continueSpacebar.appendChild(document.createTextNode('Press [spacebar] to continue'));
                    container.appendChild(div_continueSpacebar);
                }

                return container.innerHTML
            },
        }
        if (!letContinue) {
            stimObject.trial_duration = 20000;
            stimObject.minimum_duration = 20000;
        } else {
            stimObject.choices = [' '];
            stimObject.on_finish = () => {
                postTimestampToServer('ques'); 
            }
        }
        return stimObject
    };
    timeline.push(stimPreQuesObject(false), stimPreQuesObject(true));

    // questionnaires: NFCS, BFI-II, ICAR (in that order)
    ques_stim('q_nfcs', subj, UID).forEach(x => timeline.push(x));
    ques_stim('q_bfi', subj, UID).forEach(x => timeline.push(x));
    ques_stim('q_icar', subj, UID).forEach(x => timeline.push(x));

    // end of questionnaire stim
    const postQuesStim = {
        type: 'html-keyboard-response',
        stimulus: () => {
            const container = containerElement();
            const div = document.createElement('div');
            div.appendChild(document.createTextNode('You have reached the end of the questionnaires.'));
            div.appendChild(document.createElement('br')); div.appendChild(document.createElement('br')); 
            div.appendChild(document.createTextNode('Continue to see if you obtained a bonus.'));
            div.appendChild(document.createElement('br')); div.appendChild(document.createElement('br')); 
            div.appendChild(document.createTextNode('Press SPACEBAR to continue.'));
            container.appendChild(div);

            return container.innerHTML
        },
        choices: [' '],
        trial_duration: 3000,
    };
    timeline.push(postQuesStim);

    // Bonus calculation: screen + schedule
    const bonusStim = {
        type: 'html-keyboard-response',
        stimulus: () => {
            const container = containerElement();
            const div = document.createElement('div');
            if (window.medalCounter.reduce((prev, curr) => prev + curr, 0) >= 7) {
                div.appendChild(document.createTextNode('Congratulations! You earned enough medals for the £2 bonus!'));
                div.appendChild(document.createElement('br')); div.appendChild(document.createElement('br')); 
            } else {
                div.appendChild(document.createTextNode('Sorry. You did not earn enough medals for the bonus.'));
                div.appendChild(document.createElement('br')); div.appendChild(document.createElement('br')); 
            }
            div.appendChild(document.createTextNode('Press SPACEBAR to continue'));
            container.appendChild(div);

            return container.innerHTML
        },
        choices: [' '],
        on_finish: () => {
            const medalSum = window.medalCounter.reduce((prev, curr) => prev + curr, 0);
            const didGetBonus = () => {
                return (medalSum >= 6 ? 1 : 0)
            };
            const bonusData4DB = () => {
                return window.medalCounter.toString().split(',').join('').concat(didGetBonus())
            };

            // update bonus in database
            $.ajax({
                url: '/post_bonus',
                type: 'POST',
                data: {
                    uid: UID,
                    bonus: bonusData4DB()
                },
            })
        }
    };
    timeline.push(bonusStim)

    // get feedback from subject
    // get_feedback(UID).forEach(x => timeline.push(x)); //DISABLED - 8 June 2022 - JL

    // end the study completely after thanking them
    timeline.push(new stimTaskEnd());

    // initialize jsPsych
    jsPsych.init({
        timeline: timeline,
        minimum_valid_rt: 0,
        on_finish: () => {
            window.location = `https://app.prolific.co/submissions/complete?cc=${finishCode}`;
        }
    });

    /* -- Utility functions -- */

    // child function of the task end stimulus 
    function stimTaskEnd() {
        StimulusTaskEnd.call(this);
        this.trial_duration = 2000;
        this.on_finish = () => {
            postTimestampToServer('end'); 
        }
    }

    // child function of the medals stimulus
    function stimChild_progress(cfg) {
        StimulusProgress.call(this, cfg);
        
    }

    // child function of standard trial stimulus
    function stimChild_trial(cfg) {
        StimulusOptions.call(this, cfg);
        this.on_finish = () => {
            this.data.response = jsPsych.data.getLastTrialData().values()[0].response;
            this.data.rt = jsPsych.data.getLastTrialData().values()[0].rt;
            if (!cfg.isTutorial) {
                if (cfg.trialData.trialState == 0) {
                    let resp_data = new RespDataTemplate(cfg.trialData);
                        resp_data.is_left = is_left(this.data.response);
                        resp_data.shape = cfg.shapes[Number(!resp_data.is_left)];
                        resp_data.color = cfg.colors[Number(!resp_data.is_left)];
                        resp_data.rt = Math.round(this.data.rt);
                    // log for performance feedback
                    if (cfg.trialData.icnd == 1) {
                        if (cfg.trialData.targ_shape == resp_data.shape) {
                            if (cfg.isTraining) {
                                window.trainCounter[0]++;
                            } else {
                                window.bonusCounter[cfg.trialData.iblk-1][0]++;
                            }
                        }
                    }
                    push_respToBuffer(resp_data, cfg.doDump);
                    if (resp_data.it_abs == 1) {
                        postTimestampToServer('start');
                    }
                }
            }
        }
        // Permission of response keys dependent on trialState
        switch (cfg.trialData.trialState) {
            case 0:
                this.choices = choiceSet;
                break
            case 1: // outcome
                this.trial_duration = trialDuration(outcomeDuration);
                this.post_trial_gap = trialDuration(ITIDuration());
                this.choices = jsPsych.NO_KEYS;
                break
            case 2: // sequence intro
                this.choices = [' '];
                this.minimum_duration = trialDuration(introDuration);
                this.post_trial_gap = trialDuration(postInstDuration);
                break
        }

        
    }

    // child function of probe trial stimulus
    function stimChild_probe(cfg) {
        StimulusProbe.call(this, cfg);
        this.on_finish = () => {
            this.data.response = jsPsych.data.getLastTrialData().values()[0].response;
            this.data.rt = jsPsych.data.getLastTrialData().values()[0].rt;
            if (!cfg.isTutorial) {
                if (cfg.trialData.trialState == 0) {
                    let resp_data = new RespDataTemplate(cfg.trialData);
                        resp_data.shape = cfg.target.shape; // is not dependent on response
                        resp_data.is_left = is_left(this.data.response);
                        resp_data.color = cfg.isBlue[Number(!resp_data.is_left)]; // 1:blue, 0:orange
                        resp_data.rt = Math.round(this.data.rt);
                    // log for performance feedback
                    if (cfg.trialData.symm == 2) {
                        if (cfg.target.color != resp_data.color) {
                            if (cfg.isTraining) {
                                window.trainCounter[1]++;
                            } else {
                                window.bonusCounter[cfg.trialData.iblk - 1][1]++;
                            }
                        }
                    } else {
                        if (cfg.target.color == resp_data.color) {
                            if (cfg.isTraining) {
                                window.trainCounter[1]++;
                            } else {
                                window.bonusCounter[cfg.trialData.iblk - 1][1]++;
                            }
                        }
                    }
                    push_respToBuffer(resp_data, cfg.doDump);
                }
            }
        }
        switch (cfg.trialData.trialState) {
            case 0:
                this.choices = choiceSet;
            break
            case 1:
                this.trial_duration = trialDuration(probeSelDuration);
            break
            case 2:
                this.trial_duration = trialDuration(probeFBDuration);
                this.choices = jsPsych.NO_KEYS;
                this.post_trial_gap = trialDuration(probeSelDuration);
            break
        }
    }

    /* -----Client-Server comms functions----- */

    // buffer dumping function
    const doBufferDump = (doDump) => {
        if (doDump) {
            return new Promise((resolve, reject) => {
                const dataPacket = {
                    subj: subj,
                    uid: UID,
                    dataStrArr: RESPONSE_BUFFER
                };
                // send to server
                $.ajax({
                        url: '/post_response',
                        type: 'POST',
                        data: dataPacket
                    }).done((successFlag) => {
                        resolve(successFlag);
                    }).fail((xhr, txt, err) => {
                        console.log('FAIL post_resp POST');
                        console.log(err);
                        resolve(false);
                    }).then((isSuccess) => {
                        if (isSuccess) {
                            RESPONSE_BUFFER = [];
                        } else {
                            // handle the failed request; do not dump buffer
                        }
                    });
            })
        }
    }

    // Sends a response packet to the server
    function push_respToBuffer(resp, doDump) {
        const dataObj = {
            iblk        : resp.iblk,
            iseq_abs    : resp.iseq_abs,
            iseq_blk    : resp.iseq_blk,
            icnd        : resp.icnd,
            it_abs      : resp.it_abs,
            it_seq      : resp.it_seq,
            is_guess    : Number(resp.is_guess),
            targ_shape  : resp.targ_shape,
            targ_blue   : resp.targ_blue,
            symm        : resp.symm,
            shape       : resp.shape,
            color       : resp.color,
            is_left     : Number(resp.is_left),
            rt          : resp.rt,
            ts          : `"${new Date().toISOString().slice(0, 19).replace('T', ' ')}"`
        };
        const dataArr = Object.keys(dataObj).map((key) => [dataObj[key]]);
        new Promise((resolve, reject) => {
            resolve(RESPONSE_BUFFER.push(`${dataArr}`));
        })
        .then(() => {
            doBufferDump(doDump);
        });
    }

    // send queries to server to update main_table
    const postTimestampToServer = (type) => {
        $.ajax({
            url: '/post_timestamp',
            type: 'POST',
            data: {
                uid: UID,
                type: type
            },
        })
    }


}