import { StimulusOptions, StimulusProbe, StimulusProgress, StimulusBlockEnd, StimulusTaskEnd,
         RespDataTemplate } from './modules/task_modules.js'
import { instruction_stim, training_stim } from './modules/instructions_module.js'
import ques_stim from './modules/questionnaire_module.js'
// import get_feedback from './get_feedback.js';

const BONUS_MEDAL_THRESHOLD = 9;

function addCentralFixationDot(dotColor) {
    const parent = document.querySelector('#jspsych-content') || document.body;

    // remove any leftover dot
    const old = document.getElementById('central-fixation-dot');
    if (old) old.remove();

    const dot = document.createElement('div');
    dot.id = 'central-fixation-dot';
    dot.style.position = 'absolute';
    dot.style.left = '50%';
    dot.style.top = '50%';
    dot.style.transform = 'translate(-50%, -50%)';
    dot.style.width = '10px';
    dot.style.height = '10px';
    dot.style.borderRadius = '50%';
    dot.style.backgroundColor = dotColor;
    dot.style.zIndex = '9999';
    dot.style.pointerEvents = 'none';

    parent.appendChild(dot);
}

function removeCentralFixationDot() {
    const dot = document.getElementById('central-fixation-dot');
    if (dot) dot.remove();
}

export default function exec_task(task_data) {
    let timeline = [];

    const debugFlag = false; //DEBUG
    const doTraining = true;

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

    // Denominators for averageScore, per block index (0-based) //YC: 16/jan/2026
    window.blockScoreDenom = Array.from({ length: taskData.length }, () => ({ nTrials: 0, nGuess: 0 }));

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
    let DUMP_IN_FLIGHT = false; //YC: 20/jan
    let DUMP_PENDING = false; //YC: 20/jan
    let BONUS_SAVED = false; //YC: 20/jan

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
        showtext: `
            <p>To take part in the experiment, your browser must be in fullscreen mode.</p>
            <p>Please click the button below to enable fullscreen mode and continue.</p>
        `,
        buttontext: 'Fullscreen',
    };
    if (!debugFlag) timeline.push(fullscreen); //DEBUG - uncomment before launch

    // 3 options **
    // instructions for the DISCOVER condition 
    const instr_disc = {
        get timeline() {
            let stims = [];

            // Initial instruction pages
            Array.from([...Array(4).keys()].map(x => instruction_stim('disc', x))).forEach(x => stims.push(x));
            // orange in tutorial, defined in instructions_module.js

            // Read tutorial constants
            const shapesBase = task_data.constants.shapesTutDisc;    // length 3
            const colorsBase = task_data.constants.colorsTutDisc;    // 3 x nTrials
            const perms      = task_data.constants.sidesTutDisc;     // nTrials x 3

            // Demo trials with 3 options
            for (let i = 0; i < perms.length; i++) {
                const perm = perms[i];

                const bagInputs = perm.map(idx => {
                    return [1, shapesBase[idx], colorsBase[idx][i], null];
                });

                for (let j = 0; j < 2; j++) {
                    const cfg = {
                        isTutorial: true,
                        isTraining: false,
                        bagInputs: bagInputs,
                        trialData: {
                            trialState: j,
                        },
                        // warningText: // in task_modules.js
                            // (i === 0 && j === 0)
                            //     ? 'The grey dot at the centre is a reminder that you are playing the \'DISCOVERING\' game.'
                            //     : (i === 1 && j === 0)
                            //         ? 'Be careful: the bags can change positions!'
                            //         : null
                           warningText:
                                (i === 0 && j === 0)
                                    ? 'The grey dot at the centre is a reminder that you are playing the \'DISCOVERING\' game.<br>' +
                                    'The bags may be in different positions each time.<br>' +
                                    'Now, please choose one bag using one of the three keys (left arrow, up arrow, right arrow).'
                                    : null,
                    };
                    stims.push(new stimChild_trial(cfg));
                }
            }

            // Probe trials (still 2 option, left/right) can remain as in your current code
            const shapes = shapesBase;
            for (let i = 0; i < 3; i++) {
                const cfg = {
                    isTutorial: true,
                    isTraining: false,
                    target: {
                        shape: shapes[0],  // or whatever you prefer
                        color: 1, // blue target, to match colorsTutDisc
                    },
                    isBlue: [0, 1], // correct answer on the right side
                    trialData: {
                        trialState: i,
                    },
                };
                stims.push(new stimChild_probe(cfg));
            }

            // The rest of the DISC instructions
            stims.push(instruction_stim('disc', 4));
            stims.push(instruction_stim('disc', 5));

            return stims;
        }
    };
    
    // // instructions for the DISCOVER condition
    // const instr_disc = {
    //     get timeline() {
    //         let stims = [];
    //         // Initial instructions
    //         Array.from([...Array(4).keys()].map(x => instruction_stim('disc', x))).forEach(x => stims.push(x));
    //         // Sample trials
    //         const sideOpt1 = task_data.constants.sidesTutDisc;
    //         const colors = task_data.constants.colorsTutDisc;
    //         const shapes = task_data.constants.shapesTutDisc;
    //         for (let i = 0; i < sideOpt1.length; i++) {
    //             const bagInputOne = [1,shapes[0],colors[0][i],null];
    //             const bagInputTwo = [1,shapes[1],colors[1][i],null];
    //             const bagInputs = new Array(2);
    //                   bagInputs[sideOpt1[i]] = bagInputOne;
    //                   bagInputs[Number(!sideOpt1[i])] = bagInputTwo;
    //             for (let j = 0; j < 2; j++) {
    //                 const cfg = {
    //                     isTutorial: true,
    //                     isTraining: false,
    //                     bagInputs: bagInputs,
    //                     trialData: {
    //                         trialState: j
    //                     }
    //                 }
    //                 stims.push(new stimChild_trial(cfg));
    //             }
    //         }
    //         // Probe trial 
    //         for (let i = 0; i < 3; i++) {
    //             const cfg = {
    //                 isTutorial: true,
    //                 isTraining: false,
    //                 target: {
    //                     shape: shapes[0],
    //                     color: 1,
    //                 },
    //                 isBlue: [0,1],
    //                 trialData: {
    //                     trialState: i,
    //                 },
    //             }
    //             stims.push(new stimChild_probe(cfg));
    //         }
    //         // The rest of the instructions
    //         stims.push(instruction_stim('disc', 4));
    //         stims.push(instruction_stim('disc', 5));

    //         return stims
    //     }
    // };



    // 3 options **
    // instructions for the DRAW condition
    const instr_draw =  {
        get timeline() {
            let stims = [];

            // Initial instruction pages
            Array.from([...Array(5).keys()].map(x => instruction_stim('draw', x))).forEach(x => stims.push(x));

            // Read tutorial constants
            const shapesBase = task_data.constants.shapesTutDraw;    // length 3
            const colorsBase = task_data.constants.colorsTutDraw;    // 3 x nTrials
            const perms      = task_data.constants.sidesTutDraw;     // nTrials x 3

            // For each tutorial trial
            for (let i = 0; i < perms.length; i++) {
                const perm = perms[i];    // e.g. [0,1,2] or [2,1,0]

                // Build bagInputs for LEFT, UP, RIGHT
                const bagInputs = perm.map(idx => {
                    return [1, shapesBase[idx], colorsBase[idx][i], null];
                });

                // trialState 0 and 1 for each configuration
                for (let j = 0; j < 2; j++) {
                    const cfg = {
                        isTutorial: true,
                        isTraining: false,
                        bagInputs: bagInputs,
                        trialData: {
                            trialState: j,
                            goalColor: 0,
                            icnd: 1,
                        },
                        // warningText:
                        //     (i === 0 && j === 0)
                        //         ? 'The orange dot at the centre is a reminder that you are playing the \'DRAWING orange\' game.'
                        //         : (i === 1 && j === 0)
                        //             ? 'Be careful: the bags can change positions!'
                        //             : null
                           warningText:
                            (i === 0 && j === 0)
                                ? 'The orange dot at the centre is a reminder that you are playing the \'DRAWING orange\' game.<br>' +
                                'The bags may be in different positions each time.<br>' +
                                'Now, please choose one bag using one of the three keys (left arrow, up arrow, right arrow).'
                                : null,
                    };
                    stims.push(new stimChild_trial(cfg));
                }
            }

            // The rest of the DRAW instructions
            if (!debugFlag) stims.push(instruction_stim('draw', 5));

            return stims;
        }
    };

    // instructions for the DRAW condition
    // const instr_draw =  {
    //     get timeline() {
    //         let stims = [];
    //         // Initial instructions
    //         Array.from([...Array(5).keys()].map(x => instruction_stim('draw', x))).forEach(x => stims.push(x));
    //         // Sample trials
    //         const sideOpt1 = task_data.constants.sidesTutDraw;
    //         const colors = task_data.constants.colorsTutDraw;
    //         const shapes = task_data.constants.shapesTutDraw;
    //         for (let i = 0; i < sideOpt1.length; i++) {
    //             const bagInputOne = [1,shapes[0],colors[0][i],null];
    //             const bagInputTwo = [1,shapes[1],colors[1][i],null];
    //             const bagInputs = new Array(2);
    //                   bagInputs[sideOpt1[i]] = bagInputOne;
    //                   bagInputs[Number(!sideOpt1[i])] = bagInputTwo;
    //             for (let j = 0; j < 2; j++) {
    //                 const cfg = {
    //                     isTutorial: true,
    //                     bagInputs: bagInputs,
    //                     trialData: {
    //                         trialState: j
    //                     }
    //                 }
    //                 stims.push(new stimChild_trial(cfg));
    //             }
    //         }
    //         // The rest of the instructions
    //         if (!debugFlag) stims.push(instruction_stim('draw', 5));
    //         return stims
    //     }
    // };

    // 1. Instructions to read carefully
    if (!debugFlag) timeline.push(instruction_stim('read_prompt'));
    
    // 2. Instructions for bags
    const instr_bags = {
        timeline: Array.from([...Array(8).keys()].map(x => instruction_stim('bags', x)))
    }
    if (!debugFlag) timeline.push(instr_bags);

    // 3. Instructions for the 2 conditions (odd subjects start with DRAW)
    // if (subj % 2 == 1) {
    //     if (!debugFlag) timeline.push(instr_draw, instr_disc); 
    // } else {
    //     if (!debugFlag) timeline.push(instr_disc, instr_draw); 
    // }
    if (!debugFlag) timeline.push(instr_draw, instr_disc); 

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
    let nt_totalTraining = 0;
    window.trainCounter = Array(2).fill(0);
    const loadTraining = () => {
        if (doTraining) timeline.push(training_stim('prompt'));

        for (let iseq = 0; iseq < trainData.blockTrials.length; iseq++) {
            const blockInfo = trainData.blockInfo[iseq];
            const posSeq    = trainData.blockSides[iseq];
            const trialVals = trainData.blockTrials[iseq];
            // training sequence parameters
            const cond       = blockInfo[0]; // 1: draw, 2: guess
            const shapes     = [blockInfo[1], blockInfo[2], blockInfo[3]];  // [target, other1, other2]
            const hiddenCols = [blockInfo[4], blockInfo[5], blockInfo[6]];  // 0: orange, 1: blue
            const goalColor  = blockInfo[7]; // 1: blue, 0: orange
            const targetIdx  = 0;  // shapes[0] is target

            const sumColors  = hiddenCols[0] + hiddenCols[1] + hiddenCols[2];
            const notAllSame = (sumColors !== 0 && sumColors !== 3);

            if (cond === 1 && notAllSame) {
                 nt_totalTraining = nt_totalTraining + trialVals.length;
            }
            
            const colorForShape = (shapeIdx, trialColorIdx) => {
                const hidden = hiddenCols[shapeIdx]; // 0 or 1

                if (hidden === 0) {
                    // hidden orange → use the base color index directly
                    return trialColorIdx;
                } else {
                    // hidden blue → use the complementary index (reversed)
                    return reverseIndex[trialColorIdx - 1];
                }
            };

            // training trial loop
            for (let itrial = 0; itrial < trialVals.length; itrial++) {
                
                const targetColorIdx = trialVals[itrial];
                const posVec         = posSeq[itrial];  // [pL, pC, pR] each in {0,1,2}

                // inputs for the bag Object: 3 bags (left, center, right)
                const bagInputs = new Array(3);

                for (let pos = 0; pos < 3; pos++) {
                    const shapeIdx = posVec[pos];              // which logical shape
                    const shapeID  = shapes[shapeIdx];         // actual shape code
                    const colIdx   = colorForShape(shapeIdx, targetColorIdx);
                    const stateID  = hiddenCols[shapeIdx];
                    // [bagFlag, shapeID, colorIndex, extraState]
                    bagInputs[pos] = [1, shapeID, colIdx, stateID];
                }

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
                    if (doTraining) timeline.push(new stimChild_trial(cfg));
                }
                
                // generate stimuli for the 2-state standard training trial 
                for (let i = 0; i < 2; i++) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: true,
                        bagInputs: bagInputs,
                        shapes: [bagInputs[0][1], bagInputs[1][1], bagInputs[2][1]],
                        colors: [bagInputs[0][2], bagInputs[1][2], bagInputs[2][2]],
                        states: [bagInputs[0][3], bagInputs[1][3], bagInputs[2][3]],
                        trialData: {
                            trialState: i,
                            iblk: 0,
                            iseq_abs: 0,
                            iseq_blk: iseq+1,
                            icnd: cond,
                            it_abs: 0,
                            it_seq: itrial+1,
                            symm: hiddenCols,
                            is_guess: false,
                            targ_shape: shapes[targetIdx],
                            targ_blue: hiddenCols[targetIdx], // true hidden color of the target
                            goalColor: goalColor, // YCao added on 01/Jan/2026
                        },
                        get doDump() {
                            return (cond == 1 ? (itrial == trialVals.length-1) : false)
                        }
                    };
                    if (doTraining) timeline.push(new stimChild_trial(cfg));
                }
            } //end training trial loop

            if (cond == 2) { // final question trial for the GUESS condition
 
                // const side = [1, 0];
                const side = Math.random() < 0.5 ? [1, 0] : [0, 1];
                const targetHidden = hiddenCols[targetIdx];

                // generate stimuli for the 3-state probe trial
                for (let i = 0; i < 3; i++) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: true,
                        target: {
                            shape: shapes[targetIdx],
                            color: isBlue[targetHidden],
                            state: targetHidden,
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
                            symm: 0,
                            is_guess: true,
                            targ_shape: shapes[targetIdx],
                            targ_blue: targetHidden,
                            goalColor: goalColor,
                        },
                        doDump: true
                    }
                    if (doTraining) timeline.push(new stimChild_probe(cfg));
                }
            }
        }
        // Show progress and performance at the end of the training block with some explanation
        if (doTraining) timeline.push(StimulusBlockEnd(-1));
        if (doTraining) timeline.push(training_stim('medals'));
        const cfg = {
            nTrials : nt_totalTraining,
            iblock  : -1,
            nGuess  : 4,
        };
        if (doTraining) timeline.push(new stimChild_progress(cfg));
    }
    if (doTraining) loadTraining();


        // 7. Comprehension check //YC: move it here 
    const comprehensionCheckObject = () => {
        const questions = [
            `If one bag is blue, can you guess the colour of the other bags without drawing from it?`,
            `Are all the shapes in the bag of exactly the same shade?`,
            `In the <strong>DRAWING</strong> games, how do you win points?`,
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
                    responses: JSON.stringify(data.response)  // save raw answers too, YC 16/01/2026
                };
                // send to server
                $.ajax({
                    url: 'post_comprehension',
                    type: 'POST',
                    data: dataPacket,
                });
            }
        }
    }
    if (!debugFlag) timeline.push(comprehensionCheckObject());


    const trialsPerBlockInDraw = new Array(taskData.length);

    // experiment loop
    let it_abs = 0;
    let iseq_abs = 0;
    for (let iblock = 0; iblock < taskData.length; iblock++) {
        const blockData = taskData[iblock];
        // Precompute denominators for this block to match StimulusProgress logic
        let nTrialsBlock = 0;
        for (let iseq = 0; iseq < blockData.blockTrials.length; iseq++) {
            const cond = blockData.blockInfo[iseq][0];
            if (cond === 1) {
                nTrialsBlock += blockData.blockTrials[iseq].length;
            }
        }
        const nGuessBlock = Math.floor(task_data.constants.ns_total / 2); // matches StimulusProgress default
        window.blockScoreDenom[iblock] = { nTrials: nTrialsBlock, nGuess: nGuessBlock };

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
        // for (let iseq = 0; iseq < 2; iseq++) {
        for (let iseq = 0; iseq < blockData.blockTrials.length; iseq++) {
            iseq_abs++; 

            // const blockInfo = blockData.blockInfo[iseq];
            // const sideStrks = blockData.blockSides[iseq];
            // const trialVals = blockData.blockTrials[iseq];
            
            // // sequence parameters
            // const cond      = blockInfo[0]; // 1: draw, 2: guess
            // const shapes    = [blockInfo[1],blockInfo[2]];
            // const goalColor = blockInfo[3]; // 1: blue, 0: orange
            // const symmType  = blockInfo[4]; // 1,2 symm, anti-symm; 3 not symm
            // const isSymm    = symmType < 3;

            // // const randNum = Math.round(Math.random()*100);
            // const leftSideShape = sides(sideStrks).map(x => {
            //     // return (x + randNum) % 2 == 0
            //     return x % 2 == 0

            // });

            // 3 option:
            const blockInfo = blockData.blockInfo[iseq];
            const posSeq    = blockData.blockSides[iseq];      // [ [pL,pC,pR], ... ]
            const trialVals = blockData.blockTrials[iseq];

            // sequence parameters (3 options)
            const cond       = blockInfo[0]; // 1: draw, 2: guess
            const shapes     = [blockInfo[1], blockInfo[2], blockInfo[3]];  // [target, other1, other2]
            const hiddenCols = [blockInfo[4], blockInfo[5], blockInfo[6]];  // 0: orange, 1: blue
            const goalColor  = blockInfo[7]; // 1: blue, 0: orange
            // const sym1       = blockInfo[5]; // 1 same hidden state, 0 reversed, for other1
            // const sym2       = blockInfo[6]; // same for other2
            // const symmVals   = [0, sym1, sym2];
            // shape index constants
            const targetIdx  = 0;  // shapes[0] is target
            // const other1Idx  = 1;
            // const other2Idx  = 2;

            // helper: color mapping for any shape index
            // const colorForShape = (shapeIdx, targetColorIdx) => {
            //     if (shapeIdx === targetIdx) {
            //         // target: use the specified color index
            //         return targetColorIdx;
            //     }
            //     if (shapeIdx === other1Idx) {
            //         // first distractor
            //         return sym1 === 1 ? targetColorIdx : reverseIndex[targetColorIdx - 1];
            //     }
            //     if (shapeIdx === other2Idx) {
            //         // second distractor
            //         return sym2 === 1 ? targetColorIdx : reverseIndex[targetColorIdx - 1];
            //     }
            //     // fallback: should not happen
            //     return targetColorIdx;
            // };

            // helper: color mapping for any logical option index
            // trialColorIdx is the "blue" color index from trialVals[itrial]
            const colorForShape = (shapeIdx, trialColorIdx) => {
                const hidden = hiddenCols[shapeIdx]; // 0 or 1

                if (hidden === 0) {
                    // hidden orange → use the base color index directly
                    return trialColorIdx;
                } else {
                    // hidden blue → use the complementary index (reversed)
                    return reverseIndex[trialColorIdx - 1];
                }
            };


            for (let itrial = 0; itrial < trialVals.length; itrial++) {
                if (cond == 1) it_blk++;
                it_abs++;
                // sides: 0/ index of left bag shape, 1/ index of right bag shape
                // const sides = [Number(leftSideShape[itrial]), Number(!leftSideShape[itrial])];

                // // the value of trialVals[itrial] belongs on shapes[0]
                // //  if isSymm, shapes[1] takes the same as shapes[0]
                // //      else, shapes[1] takes the inverted index of shapes[0]
                // const colorIndex = (side,index) => {
                //     if (side == 0) {
                //         return index
                //     } else {
                //         return (isSymm) ? index : reverseIndex[index-1]; 
                //     }
                // }
                // // inputs for the bag Object
                // const bagInputs = new Array(2);
                // const bagInputLeft = [1,shapes[sides[0]],colorIndex(sides[0],trialVals[itrial]),null];
                // const bagInputRight = [1,shapes[sides[1]],colorIndex(sides[1],trialVals[itrial]),null];
                // bagInputs[0] = bagInputLeft;
                // bagInputs[1] = bagInputRight;

                const targetColorIdx = trialVals[itrial];
                const posVec         = posSeq[itrial];  // [pL, pC, pR] each in {0,1,2}

                // inputs for the bag Object: 3 bags (left, center, right)
                const bagInputs = new Array(3);

                for (let pos = 0; pos < 3; pos++) {
                    const shapeIdx = posVec[pos];              // which logical shape
                    const shapeID  = shapes[shapeIdx];         // actual shape code
                    const colIdx   = colorForShape(shapeIdx, targetColorIdx);
                    const stateID  = hiddenCols[shapeIdx];
                    // [bagFlag, shapeID, colorIndex, extraState]
                    bagInputs[pos] = [1, shapeID, colIdx, stateID];
                }

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
                // for (let i = 0; i < 2; i++) {
                //     const cfg = {
                //         isTutorial: false,
                //         isTraining: false,
                //         bagInputs: bagInputs,
                //         shapes: [bagInputs[0][1],bagInputs[1][1]],
                //         colors: [bagInputs[0][2],bagInputs[1][2]],
                //         trialData: {
                //             trialState: i,
                //             iblk: iblock+1,
                //             iseq_abs: iseq_abs,
                //             iseq_blk: iseq+1,
                //             icnd: cond,
                //             it_abs: it_abs,
                //             it_seq: itrial+1,
                //             symm: symmType,
                //             is_guess: false,
                //             targ_shape: shapes[0],
                //             targ_blue: goalColor
                //         },
                //         get doDump() {
                //             return (cond == 1 ? (itrial == trialVals.length-1) : false)
                //         }
                //     };
                //     timeline.push(new stimChild_trial(cfg)); 
                // }

                // generate stimuli for the standard choice + outcome trial
                for (let i = 0; i < 2; i++) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: false,
                        bagInputs: bagInputs,
                        shapes: [bagInputs[0][1], bagInputs[1][1], bagInputs[2][1]],
                        colors: [bagInputs[0][2], bagInputs[1][2], bagInputs[2][2]],
                        states: [bagInputs[0][3], bagInputs[1][3], bagInputs[2][3]],
                        trialData: {
                            trialState: i,
                            iblk: iblock + 1,
                            iseq_abs: iseq_abs,
                            iseq_blk: iseq + 1,
                            icnd: cond,
                            it_abs: it_abs,
                            it_seq: itrial + 1,
                            // symm: symmVals,              // or encode [sym1,sym2] later if needed
                            symm: hiddenCols,
                            is_guess: false,
                            targ_shape: shapes[targetIdx],
                            targ_blue: hiddenCols[targetIdx], // true hidden color of the target
                            goalColor: goalColor, // YCao added on 01/Jan/2026
                        },
                        get doDump() {
                            return (cond == 1 ? (itrial == trialVals.length - 1) : false);
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
                // const leftSide = leftSideShape.slice(-1)[0]; // takes the last value of the array
                // const side = [Number(leftSide), Number(!leftSide)];
                // const side = [1, 0];
                const side = Math.random() < 0.5 ? [1, 0] : [0, 1];
                const targetHidden = hiddenCols[targetIdx];  // 0 = orange, 1 = blue
                // const isTargetBlue = () => { // 1 if blue, 0 if orange
                //     // implement XNOR logic gate with '==='
                //     // return Number(Number(symmType % 2 == 1) === goalColor);
                //     return Number(goalColor === 1);
                // }
                // generate stimuli for the 3-state probe trial
                for (let i = 0; i < 3; i++) {
                    const cfg = {
                        isTutorial: false,
                        isTraining: false,
                        target: {
                            shape: shapes[targetIdx],
                            color: isBlue[targetHidden],
                            state: targetHidden,
                            // color: isBlue[isTargetBlue()],
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
                            symm: 0,
                            is_guess: true,
                            targ_shape: shapes[targetIdx],
                            targ_blue: targetHidden,
                            goalColor: goalColor, // YCao added on 01/Jan/2026
                            // targ_blue: isTargetBlue()
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
                url: 'post_preference',
                type: 'POST',
                data: dataPacket,
            });
        }
    };
    // timeline.push(preferenceCheckObject);

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
                url: 'post_sequence',
                type: 'POST',
                data: dataPacket,
            });
        }
    };
    // timeline.push(sequenceCheckObject);

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
    // ques_stim('q_bfi', subj, UID).forEach(x => timeline.push(x));
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
    // const BONUS_MEDAL_THRESHOLD = 7;
    const bonusStim = {
        type: 'html-keyboard-response',
        stimulus: () => {
            const container = containerElement();
            const div = document.createElement('div');

            // Save bonus summary once when the subject sees this page
            if (!BONUS_SAVED) { //YC: 20/Jan/2026
                BONUS_SAVED = true;

                const medalSum = window.medalCounter.reduce((prev, curr) => prev + curr, 0);
                const bonusEarned = (medalSum >= BONUS_MEDAL_THRESHOLD ? 1 : 0);

                $.ajax({
                    url: 'post_bonus_summary',
                    type: 'POST',
                    data: {
                        uid: UID,
                        medalSum: medalSum,
                        bonusEarned: bonusEarned
                    }
                });
            }

            if (window.medalCounter.reduce((prev, curr) => prev + curr, 0) >= BONUS_MEDAL_THRESHOLD) {
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
        response_ends_trial: false, // YC
        trial_duration: 1500, // YC: not too fast
        on_finish: () => {
            const medalSum = window.medalCounter.reduce((prev, curr) => prev + curr, 0);
            const didGetBonus = () => {
                return (medalSum >= BONUS_MEDAL_THRESHOLD ? 1 : 0)
            };
            const bonusData4DB = () => {
                return window.medalCounter.toString().split(',').join('').concat(didGetBonus())
            };

            // ---- LOG BONUS SCREEN INTO resp.csv ----
            let resp_data = new RespDataTemplate({
                iblk: -99,          // special marker: bonus screen
                iseq_abs: -1,
                iseq_blk: -1,
                icnd: -1,
                goalColor: -1,
                it_abs: -1,
                it_seq: -1,
                is_guess: -1,
                targ_shape: -1,
                targ_blue: -1,
                symm: -1,
            });
            // store bonus-relevant info
            resp_data.perf_draw_hits  = -1;
            resp_data.perf_guess_corr = -1;
            resp_data.perf_nTrials    = -1;
            resp_data.perf_nGuess     = -1;
            resp_data.perf_avgScore   = -1;
            // ADD THESE TWO NEW FIELDS
            resp_data.medalSum    = medalSum;
            resp_data.bonusEarned = didGetBonus();
            // push exactly once
            push_respToBuffer(resp_data, true);

            // update bonus in database
            $.ajax({
                url: 'post_bonus',
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
        // on_finish: () => {
        //     postTimestampToServer('finish'); // YC: 08/Jan/2026 add
        //     window.location = `https://app.prolific.co/submissions/complete?cc=${finishCode}`;
        // }


        on_finish: () => {
            try {
                const body = new URLSearchParams({ uid: UID, type: 'finish' });
                navigator.sendBeacon('post_timestamp', body);
            } catch (e) {
                postTimestampToServer('finish');
            }
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
        this.on_load = () => {
            // Only on sampling trials (choice screen)
            if (cfg.trialData && cfg.trialData.trialState === 0) {
                let dotColor = '#999999'; // default grey
                if (cfg.trialData.icnd === 1) {
                    // DRAW: dot shows goalColor (0 = orange, 1 = blue)
                    dotColor = (cfg.trialData.goalColor === 1) ? '#0080FF' : '#FF8000';
                } else if (cfg.trialData.icnd === 2) {
                    // GUESS: grey
                    dotColor = '#999999';
                }
                addCentralFixationDot(dotColor);
            }
        };

        this.on_finish = () => {
            removeCentralFixationDot();
            const last = jsPsych.data.getLastTrialData().values()[0];
            this.data.response = last.response;
            this.data.rt = last.rt;

            if (!cfg.isTutorial && cfg.trialData.trialState == 0) {
                let resp_data = new RespDataTemplate(cfg.trialData);

                const key = this.data.response;
                const choiceIndex = choiceSet.indexOf(key);   // 0,1,2 for f,j,k

                if (choiceIndex < 0) {
                    console.warn('Unknown response key in stimChild_trial:', key);
                    return;
                }

                // keep is_left field for DB compatibility: 1 if left key, 0 otherwise
                resp_data.is_left = Number(choiceIndex === 0);
                resp_data.choice_pos = choiceIndex;

                resp_data.Lshape = cfg.shapes[0];
                resp_data.Mshape = cfg.shapes[1];
                resp_data.Rshape = cfg.shapes[2];

                resp_data.Lcolor = cfg.colors[0]; // outcome
                resp_data.Mcolor = cfg.colors[1];
                resp_data.Rcolor = cfg.colors[2];

                resp_data.Lstate = cfg.states[0];
                resp_data.Mstate = cfg.states[1];
                resp_data.Rstate = cfg.states[2];


                resp_data.shape = cfg.shapes[choiceIndex];
                resp_data.color = cfg.colors[choiceIndex];
                resp_data.state = cfg.states[choiceIndex];
                // resp_data.symm  = trialData.symm;   // ★ ADD THIS
                // const trialInfo = this.data.trialData;   // ★ correct variable
                resp_data.symm  = cfg.trialData.symm[choiceIndex];         // ★ THIS IS THE FIX
                resp_data.rt    = Math.round(this.data.rt);
                resp_data.goalColor = cfg.trialData.goalColor;
                // if (cfg.trialData.icnd == 1) {
                //     if (cfg.trialData.targ_shape == resp_data.shape) {
                //         if (cfg.isTraining) {
                //             window.trainCounter[0]++;
                //         } else {
                //             window.bonusCounter[cfg.trialData.iblk - 1][0]++;
                //         }
                //     }
                // }

                if (cfg.trialData.icnd == 1) {
                    const sumColors = cfg.states[0] + cfg.states[1] + cfg.states[2];
                    const notAllSame = (sumColors !== 0 && sumColors !== 3);
                    const hitGoal = (cfg.trialData.goalColor == resp_data.state);

                    if (hitGoal && notAllSame) {

                        // console.log(
                        //     '[BONUS]',
                        //     'blk=', cfg.trialData.iblk,
                        //     'choice=', choiceIndex,
                        //     'goalColor=', cfg.trialData.goalColor,
                        //     'chosenColor=', resp_data.color,
                        //     'colors=', cfg.colors,
                        //     'sum=', sumColors
                        // );

                        

                        // window.bonusCounter[cfg.trialData.iblk - 1][0]++;

                        if (cfg.isTraining) {
                            window.trainCounter[0]++;
                        } else {
                            window.bonusCounter[cfg.trialData.iblk - 1][0]++;
                        }

                        // console.log(
                        //     '[draw BONUS COUNTER]',
                        //     'blk=', cfg.trialData.iblk,
                        //     'counter=', JSON.stringify(window.bonusCounter),
                        //     'counterTrain=', JSON.stringify(window.trainCounter),
                        //     'medal=', JSON.stringify(window.medalCounter),
                        //     'medalSum', window.medalCounter.reduce((prev, curr) => prev + curr, 0),
                        //     );

                    }
                }

                // Performance snapshot at this moment (after possible counter update above) // YC: 16/jan/2026
                const s = (cfg.isTraining ? window.trainCounter : window.bonusCounter[cfg.trialData.iblk - 1]);

                const denom = (cfg.isTraining
                    ? { nTrials: nt_totalTraining, nGuess: 4 } // matches your training StimulusProgress call
                    : window.blockScoreDenom[cfg.trialData.iblk - 1]);

                resp_data.perf_draw_hits  = s[0];
                resp_data.perf_guess_corr = s[1];
                resp_data.perf_nTrials    = denom.nTrials;
                resp_data.perf_nGuess     = denom.nGuess;

                const d1 = denom.nTrials > 0 ? (s[0] / denom.nTrials) : 0;
                const d2 = denom.nGuess  > 0 ? (s[1] / denom.nGuess)  : 0;
                resp_data.perf_avgScore   = (d1 + d2) / 2;

                resp_data.medalSum = window.medalCounter.reduce((prev, curr) => prev + curr, 0);
                resp_data.bonusEarned = (resp_data.medalSum >= BONUS_MEDAL_THRESHOLD ? 1 : 0);

                push_respToBuffer(resp_data, cfg.doDump);
                if (resp_data.it_abs == 1) {
                    postTimestampToServer('start');
                }
            }
        }
        // this.on_finish = () => {
        //     this.data.response = jsPsych.data.getLastTrialData().values()[0].response;
        //     this.data.rt = jsPsych.data.getLastTrialData().values()[0].rt;
        //     if (!cfg.isTutorial) {
        //         if (cfg.trialData.trialState == 0) {
        //             let resp_data = new RespDataTemplate(cfg.trialData);
        //                 resp_data.is_left = is_left(this.data.response);
        //                 resp_data.shape = cfg.shapes[Number(!resp_data.is_left)];
        //                 resp_data.color = cfg.colors[Number(!resp_data.is_left)];
        //                 resp_data.rt = Math.round(this.data.rt);
        //             // log for performance feedback
        //             if (cfg.trialData.icnd == 1) {
        //                 if (cfg.trialData.targ_shape == resp_data.shape) {
        //                     if (cfg.isTraining) {
        //                         window.trainCounter[0]++;
        //                     } else {
        //                         window.bonusCounter[cfg.trialData.iblk-1][0]++;
        //                     }
        //                 }
        //             }
        //             push_respToBuffer(resp_data, cfg.doDump);
        //             if (resp_data.it_abs == 1) {
        //                 postTimestampToServer('start');
        //             }
        //         }
        //     }
        // }



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
                        // resp_data.is_left = is_left(this.data.response);
                        const key = this.data.response;
                        resp_data.is_left = Number(key === choiceSet[0]);

                        resp_data.choice_pos = resp_data.is_left ? 0 : 2; // 0 = left, 1 = top, 2 = right

                        resp_data.Lshape = -1;
                        resp_data.Mshape = -1;
                        resp_data.Rshape = -1;

                        resp_data.Lcolor = -1;
                        resp_data.Mcolor = -1;
                        resp_data.Rcolor = -1;

                        resp_data.Lstate = -1;
                        resp_data.Mstate = -1;
                        resp_data.Rstate = -1;

                        // resp_data.color = cfg.isBlue[Number(!resp_data.is_left)]; // 1:blue, 0:orange
                        resp_data.color = cfg.isBlue[resp_data.is_left ? 0 : 1];

                        // console.log('resp color=', resp_data.color, 'target color=', cfg.target.state);
                        // resp_data.symm = trialData.symm;   // ★ needed for SQL ★
                        // const trialInfo = this.data.trialInfo;   // ★ correct variable
                        resp_data.symm = 0;         // ★ THIS IS THE FIX
                        resp_data.rt = Math.round(this.data.rt);
                        resp_data.goalColor = cfg.trialData.goalColor;
                    // log for performance feedback
                    // correctness: probe is correct if chosen color equals true hidden color of target
                    if (cfg.target.state == resp_data.color) {
                        // console.log(
                        // '[GUESS CORRECT]',
                        // 'blk=', cfg.trialData.iblk,
                        // 'choiceLeft=', resp_data.is_left,
                        // 'targetColor=', cfg.target.state,
                        // 'chosenColor=', resp_data.color
                        // );

                        

                        // window.bonusCounter[cfg.trialData.iblk - 1][1]++;

                        if (cfg.isTraining) {
                            window.trainCounter[1]++;
                        } else {
                            window.bonusCounter[cfg.trialData.iblk - 1][1]++;
                        }

                        // console.log(
                        //     '[guess BONUS COUNTER]',
                        //     'blk=', cfg.trialData.iblk,
                        //     'counter=', JSON.stringify(window.bonusCounter),
                        //     'counterTrain=', JSON.stringify(window.trainCounter),
                        //     'medal=', JSON.stringify(window.medalCounter),
                        //     'medalSum', window.medalCounter.reduce((prev, curr) => prev + curr, 0),
                        //     );

                    }
                    // if (cfg.trialData.symm == 2) {
                    //     if (cfg.target.color != resp_data.color) {
                    //         if (cfg.isTraining) {
                    //             window.trainCounter[1]++;
                    //         } else {
                    //             window.bonusCounter[cfg.trialData.iblk - 1][1]++;
                    //         }
                    //     }
                    // } else {
                    //     if (cfg.target.color == resp_data.color) {
                    //         if (cfg.isTraining) {
                    //             window.trainCounter[1]++;
                    //         } else {
                    //             window.bonusCounter[cfg.trialData.iblk - 1][1]++;
                    //         }
                    //     }
                    // }

                    // Performance snapshot at this moment (after possible counter update above)
                    const s = (cfg.isTraining ? window.trainCounter : window.bonusCounter[cfg.trialData.iblk - 1]);

                    const denom = (cfg.isTraining
                        ? { nTrials: nt_totalTraining, nGuess: 4 }
                        : window.blockScoreDenom[cfg.trialData.iblk - 1]);

                    resp_data.perf_draw_hits  = s[0];
                    resp_data.perf_guess_corr = s[1];
                    resp_data.perf_nTrials    = denom.nTrials;
                    resp_data.perf_nGuess     = denom.nGuess;

                    const d1 = denom.nTrials > 0 ? (s[0] / denom.nTrials) : 0;
                    const d2 = denom.nGuess  > 0 ? (s[1] / denom.nGuess)  : 0;
                    resp_data.perf_avgScore   = (d1 + d2) / 2;

                    resp_data.medalSum = window.medalCounter.reduce((prev, curr) => prev + curr, 0);
                    resp_data.bonusEarned = (resp_data.medalSum >= BONUS_MEDAL_THRESHOLD ? 1 : 0);

                    push_respToBuffer(resp_data, cfg.doDump);
                }
            }
        }
        switch (cfg.trialData.trialState) {
            case 0:
                this.choices = ['arrowleft', 'arrowright'];
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
    // YC: 20/jan, to further prevent data loss, race
    // problem: clearing a shared buffer after an async request while new trials keep appending.
    // during pilot, 3 out of 32 subjects had minor issue of data loss.
    const doBufferDump = (doDump) => {
        if (!doDump) return;

        // If a dump is already running, mark pending and exit.
        if (DUMP_IN_FLIGHT) {
            DUMP_PENDING = true;
            return;
        }

        // Snapshot current buffer
        const toSend = RESPONSE_BUFFER.slice();
        if (toSend.length === 0) return;

        // Clear buffer immediately so new trials accumulate in a fresh buffer
        RESPONSE_BUFFER = [];
        DUMP_IN_FLIGHT = true;

        const dataPacket = {
            subj: subj,
            uid: UID,
            dataStrArr: toSend
        };

        $.ajax({
            url: 'post_response',
            type: 'POST',
            data: dataPacket
        }).done((successFlag) => {
            // Be robust to different server return types
            const ok = (successFlag === true || successFlag === 'true' || successFlag === 1 || successFlag === '1');

            if (!ok) {
                // Server reported failure, restore unsent rows in front
                RESPONSE_BUFFER = toSend.concat(RESPONSE_BUFFER);
            }
        }).fail(() => {
            // Network failure, restore unsent rows in front
            RESPONSE_BUFFER = toSend.concat(RESPONSE_BUFFER);
        }).always(() => {
            DUMP_IN_FLIGHT = false;

            // If anything arrived during the dump, or a dump was requested while in-flight, dump again
            if (DUMP_PENDING || RESPONSE_BUFFER.length > 0) {
                DUMP_PENDING = false;
                doBufferDump(true);
            }
        });
    };
    // YC: this is the old function:
    // const doBufferDump = (doDump) => {
    //     if (doDump) {
    //         return new Promise((resolve, reject) => {
    //             const dataPacket = {
    //                 subj: subj,
    //                 uid: UID,
    //                 dataStrArr: RESPONSE_BUFFER
    //             };
    //             // send to server
    //             $.ajax({
    //                     url: 'post_response',
    //                     type: 'POST',
    //                     data: dataPacket
    //                 }).done((successFlag) => {
    //                     resolve(successFlag);
    //                 }).fail((xhr, txt, err) => {
    //                     console.log('FAIL post_resp POST');
    //                     console.log(err);
    //                     resolve(false);
    //                 }).then((isSuccess) => {
    //                     if (isSuccess) {
    //                         RESPONSE_BUFFER = [];
    //                     } else {
    //                         // handle the failed request; do not dump buffer
    //                     }
    //                 });
    //         })
    //     }
    // }

    // Sends a response packet to the server
    function push_respToBuffer(resp, doDump) {
        const dataObj = {
            iblk        : resp.iblk,
            iseq_abs    : resp.iseq_abs,
            iseq_blk    : resp.iseq_blk,
            icnd        : resp.icnd,
            goalColor   : resp.goalColor,
            it_abs      : resp.it_abs,
            it_seq      : resp.it_seq,
            is_guess    : Number(resp.is_guess),
            targ_shape  : resp.targ_shape,
            targ_blue   : resp.targ_blue,
            symm        : resp.symm,
            shape       : resp.shape,
            color       : resp.color,
            is_left     : Number(resp.is_left),
            choice_pos  : (resp.choice_pos != null ? resp.choice_pos : -1),
            rt          : resp.rt,
            l_shape     : resp.Lshape,
            m_shape     : resp.Mshape,
            r_shape     : resp.Rshape,
            l_state     : resp.Lstate,
            m_state     : resp.Mstate,
            r_state     : resp.Rstate,
            l_color     : resp.Lcolor,
            m_color     : resp.Mcolor,
            r_color     : resp.Rcolor,
            perf_draw_hits  : (resp.perf_draw_hits  != null ? resp.perf_draw_hits  : -1),
            perf_guess_corr : (resp.perf_guess_corr != null ? resp.perf_guess_corr : -1),
            perf_nTrials    : (resp.perf_nTrials    != null ? resp.perf_nTrials    : -1),
            perf_nGuess     : (resp.perf_nGuess     != null ? resp.perf_nGuess     : -1),
            perf_avgScore   : (resp.perf_avgScore   != null ? resp.perf_avgScore   : -1),
            medalSum    : (resp.medalSum != null ? resp.medalSum : -1),
            bonusEarned : (resp.bonusEarned != null ? resp.bonusEarned : -1),
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
            url: 'post_timestamp',
            type: 'POST',
            data: {
                uid: UID,
                type: type
            },
        })
    }


}