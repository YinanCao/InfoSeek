// task_modules.js

// import constants
import {constants} from './global_constants.js';

const {choiceSet, nb_total, ns_total,
        bagElement, medalElement, shapeElement, containerElement, bagPixelSize, medalPixelSize, shapePixelSize,
        bag_gif, blankShape_gif, blueShape_gif, orangeShape_gif, shape_gif, blank_gif, medal_gif,
        medalColors, colorMap, colorDefault, isBlue, stimSize} = constants;

const R = stimSize * 0.85;      // radius in pixels
const theta = 26;   // degrees
const rad = theta * Math.PI / 180;
const cosTheta = Math.cos(rad);
const sinTheta = Math.sin(rad);
// middle option on top, left and right below
const coords = [
    { x: -cosTheta * R,  y: +sinTheta * R },       // left
    { x: 0,              y: -R },               // middle (top)
    { x: +cosTheta * R,  y: +sinTheta * R }        // right
];

const bagImg = bagElement();
const medalImg = medalElement();
const shapeImgs = Array.from([...Array(10).keys()].map(x=>shapeElement(x)));

// export const is_left = (key) => {
//     return (jsPsych.pluginAPI.compareKeys(key,choiceSet[0]) ? true : false) 
// };

// primitive of medal visual object
export const medal = (rank) => {
    // // instantiate medal (deprecated)
    // const medal = medalImg.cloneNode('true');
    // medal.setAttribute('height',medalPixelSize);

    // // color medal
    // const outerColor = medalColors[rank-1][0];
    // const innerColor = medalColors[rank-1][1];
    // const medalOuterElemPath = medal.getElementsByClassName('st3');
    // for (let i = 0; i < medalOuterElemPath.length; i++) {
    //     medalOuterElemPath[i].style.stroke = outerColor;
    // }
    // const medalInnerElemPath = medal.getElementsByClassName('st4');
    // for (let i = 0; i < medalInnerElemPath.length; i++) {
    //     medalInnerElemPath[i].style.fill = innerColor;
    // }

    const medal = document.createElement('img')
    medal.src = medal_gif[rank-1];
    medal.style.width = "75%";

    // put medal in a div
    const div_medal = document.createElement('div');
          div_medal.style.width = "max-content";
          div_medal.style.position = 'relative';
          div_medal.style.justifyContent = "center";
    div_medal.appendChild(medal);

    return div_medal
}

// primitive of single bag visual object
export const bag = (bagInput) => {
    /* bagInput:
        0/ bag index (if 0, no bag shown)
        1/ shape index (if 0, no shape shown; otherwise index of shape)
        2/ color index
        3/ color what (0: nothing, 1: bag, 2: shape, 3: both)
    */
    const bagIndex   = bagInput[0];
    const shapeIndex = () => {
        if (bagInput[1] == 0) {
            return -1 // DEBUG need to change
        } else {
            return bagInput[1] - 1
        }
    };
    const colorIndex = bagInput[2]-1;
    const colorOpt   = bagInput[3];

    // load the proper GIF depending on stimulus type
    const optionElement = () => {
        const img = document.createElement('img');
        if (shapeIndex() == -1 && colorIndex == -1) {
            img.src = blank_gif;
        } else if (bagIndex == 0) { 
            /* When the bag is NOT shown: This occurs only as feedback after choice
                Inputs: shape index and color index
            */
            img.src = shape_gif[shapeIndex()][colorIndex];
        } else { 
            /* When the bag is shown:
                1. When showing the options on DISCOVER trial. (bags with only pure blue/orange)
                2. When options are presented and target for DISCOVER (bags with shape but no color)
                3. When the true color of target bag for DISCOVER is shown (bag with shape and pure blue/orange)
            */  
            if (shapeIndex() == -1) { 
                // 1. show purely blue/orange bag
                if (colorIndex == 0) {
                    img.src = bag_gif[0];
                } else if (colorIndex == 7) {
                    img.src = bag_gif[1];
                }
            } else if (shapeIndex() == -1 || colorOpt == 0) { 
                // 2. show non-colored bags w/ shapes
                img.src = blankShape_gif[shapeIndex()];
            } else if (colorOpt == 3) { 
                // 3. show fully-colored shape bag
                if (colorIndex == 0) {
                    img.src = blueShape_gif[shapeIndex()];
                } else if (colorIndex == 7) {
                    img.src = orangeShape_gif[shapeIndex()];
                }
            }
        }
        return img
    };

    // make div for container, bag, and shape
    const div_option = document.createElement('div');
            div_option.style.position = "relative";
            div_option.style.width = "max-content";
            div_option.style.justifyContent = "center";
    
    // GIF-specific div
    const div_gif = document.createElement('div');
            div_gif.style.position = "relative";
    
    div_gif.appendChild(optionElement());
    div_gif.firstChild.style.width = stimSize + "px"; // bag size 
    div_option.appendChild(div_gif);

    return div_option
}

// end of task stimulus
export function StimulusTaskEnd() {
    this.type = 'html-keyboard-response';
    this.stimulus = () => {
        const container = containerElement();

        const div = document.createElement('div');
        const text = [`You have reached the end of the study!`,
                        `Thank you for your participation!`,
                        `You will automatically be redirected to Prolific for the completion code...`];
        text.forEach(x => {
            div.appendChild(document.createTextNode(x));
            div.appendChild(document.createElement('br')); 
            div.appendChild(document.createElement('br'));
        })
        const span = document.createElement('span');
        span.style.fontWeight = "bold";
        span.appendChild(document.createTextNode('Do not close the browser!'));
        div.appendChild(span);
        container.appendChild(div);
        
        return container.innerHTML
    }
}

// primitive of end-of-block stimulus
export function StimulusBlockEnd(iblock) {
    return {
        type: 'html-keyboard-response',
        stimulus: () => {
            const container = containerElement();

            const div = document.createElement('div');
            if (iblock == -1) {
                div.appendChild(document.createTextNode(`End of training block`));
            } else {
                div.appendChild(document.createTextNode(`End of block ${iblock+1}/${nb_total}`));
            }
            container.appendChild(div);
            
            const div_continueSpacebar = document.createElement('div');
                  div_continueSpacebar.style.width = '100%';
                  div_continueSpacebar.style.position = 'absolute';
                  div_continueSpacebar.style.top = '92%';
                  div_continueSpacebar.style.left = '50%';
                  div_continueSpacebar.style.transform = "translate(-50%, -92%)";
            div_continueSpacebar.appendChild(document.createTextNode('Press [spacebar] to continue'));
            container.appendChild(div_continueSpacebar);

            return container.innerHTML
        },
        choices: [' ']
    }
}

// primitive of the scoring block stimulus (badges depending on performance)
export function StimulusProgress(cfg) {
    const nTrials = cfg.nTrials;
    const iBlock = cfg.iblock;

    const nGuess = cfg.nGuess ?? Math.floor(ns_total / 2);

    this.type = 'html-keyboard-response';
    this.stimulus = () => {
        const score = () => {
            return (iBlock  == -1 ? window.trainCounter : window.bonusCounter[iBlock])
        }

        console.log('[progress]', { nTrials, nGuess });

        // the score of the GUESS sequences are calculated assuming that they comprise half the sequences in a block
        const averageScore = ((score()[0]/nTrials)+(score()[1]/(nGuess)))/2;
        const rank = () => {
            if (averageScore < 0.5) {
                return 0
            } else if (averageScore >= 0.5 & averageScore < 0.60) {
                return 1
            } else if (averageScore >= 0.60 & averageScore < 0.65) {
                return 2
            } else if (averageScore >= 0.65) {
                return 3
            } else {
                return 0
            }
        };

        // push number of medals into global variable
        if (iBlock != -1) {
            window.medalCounter[iBlock] = rank();
        }

        const container = containerElement();
        // upper text
        const div_upper = document.createElement('div');
              div_upper.style.position = 'absolute';
              div_upper.style.width = '100%';
              div_upper.style.top = '20%';
              div_upper.style.left = '50%';
              div_upper.style.transform = "translate(-50%, -20%)";
        div_upper.appendChild(document.createTextNode(`This is how you did on this block!`));
        container.appendChild(document.createElement('br'));
        container.appendChild(div_upper);
        // medal if attained
        if (rank() != 0) {
            const medalDescription = ['bronze','silver','gold'];
            container.appendChild(document.createTextNode(`You got a ${medalDescription[rank()-1]} medal!`));
            container.appendChild(document.createElement('br'));
            container.appendChild(document.createElement('br'));
            const medalImg = medal(rank());
            container.appendChild(medalImg);
        } else {
            container.appendChild(document.createTextNode('You did not receive any medals this block!'));
        }
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
    };
    this.choices = [' '];
}

// primitive of probe trial (2 option display with text and target)
export function StimulusProbe(cfg) {
    /* 
        cfg : object containing fields
            target: 
                shape: index of target shape for central bag
                color: index of target color for central bag

            isBlue: location of blue option on lower bags
            trialData: object containing trial data
                trialState: 0/ wait for response 
                            1/ post-response 
                            2/ (dis)confirmatory feedback
    */
    const trialState = cfg.trialData.trialState;
    const isBlueArr = cfg.isBlue;
    const shape = cfg.target.shape;
    const color = cfg.target.color;

    // input for (upper) target bag
    function targetStateInput (trialState) {
        const bagInput = new Array(4);
        if (trialState == 2) { // feedback state
            bagInput[0] = 1;
            bagInput[1] = shape;
            bagInput[2] = color;
            bagInput[3] = 3;
        } else { // blank state
            bagInput[0] = 1;
            bagInput[1] = shape;
            bagInput[3] = 0;
        }

        return bagInput
    }

    // input for (lower) option bags
    function bagStateInputs () {
        const bagInputs = Array.from({length: 2}, () => {
            return new Array(4);
        });
        // color bags
        for (let ibag = 0; ibag < 2; ibag++){
            bagInputs[ibag][0] = 1;
            bagInputs[ibag][1] = 0;
            bagInputs[ibag][2] = isBlue[isBlueArr[ibag]];
            bagInputs[ibag][3] = 1;
        }
        
        return bagInputs
    }

    this.type = "html-keyboard-response";
    this.stimulus = () => {
        const upperBagInput = targetStateInput(trialState);
        const lowerBagInputs = bagStateInputs();

        // instruction div
        const div_text = document.createElement("div");
        div_text.style.textAlign = "center";
        const text = 'What was the dominant color of this bag?';
        div_text.appendChild(document.createTextNode(text));

        // upper bag div
        const div_upper = document.createElement('div');
        div_upper.style.display = "flex";
        div_upper.style.position = "relative";
        div_upper.style.alignItems = "center";
        div_upper.style.justifyContent = "center";
        div_upper.style.paddingBottom = "30px"; // controls distance between upper and lower divs
        div_upper.appendChild(bag(upperBagInput));

        // get the response side 
        // const respSide = () => {
        //     let respKey = () => {
        //         if (trialState == 1) {
        //             return jsPsych.data.get().last(1).values()[0].response;
        //         } else if (trialState == 2) {
        //             return  jsPsych.data.get().last(2).values()[0].response;
        //         }
        //     }
        //     return (respKey() == 'f' ? 0 : 1)
        // };
        // const respSide = () => {
        //     let respKey = () => {
        //         if (trialState == 1) return jsPsych.data.get().last(1).values()[0].response;
        //         if (trialState == 2) return jsPsych.data.get().last(2).values()[0].response;
        //     };
        //     return (respKey() === 'arrowleft' ? 0 : 1);   // probe stays 2-option
        // };

        const respSide = () => {
            // read the key from the *previous* probe state
            const respKey = () => {
                if (trialState === 1) {
                    return jsPsych.data.get().last(1).values()[0].response;
                } else if (trialState === 2) {
                    return jsPsych.data.get().last(2).values()[0].response;
                }
                return null;
            };

            const key = respKey();

            if (key === 'arrowleft')  return 0;  // left bag
            if (key === 'arrowright') return 1;  // right bag

            // any other value (including null) → no side
            return null;
        };
        
        // lower bag divs 
        const subDivs = new Array(lowerBagInputs.length);
        for (let i = 0; i < lowerBagInputs.length; i++) {
            subDivs[i] = document.createElement('div');
            subDivs[i].style.display = "inline-flex";
            subDivs[i].appendChild(bag(lowerBagInputs[i]));
            subDivs[i].style.padding = "10px 0px";
            subDivs[i].style.margin = "0px 100px";
            if (i == respSide()) {
                if (trialState > 0) {
                    subDivs[i].style.outline = "5px solid black";
                }
            }
        }

        // div containing lower bag divs
        const div_lower = document.createElement('div');
        div_lower.style.display = "block"
        div_lower.appendChild(subDivs[0]);
        div_lower.appendChild(subDivs[1]);

        // div containing all elements
        const div = document.createElement('div');
        div.style.position = "absolute";
        div.style.width = "max-content";
        div.style.top = "50%";
        div.style.left = "50%";
        div.style.transform = "translate(-50%, -50%)";

        // DEBUG: later add text here as well
        div.appendChild(div_text);
        div.appendChild(document.createElement('br'));
        div.appendChild(div_upper);
        div.appendChild(div_lower);
        

        const container = containerElement();
            container.appendChild(div);
        
        return container.innerHTML;
    };
    // this.choices = choiceSet;
    // this.choices = ['f','j'];   // probe remains 2-option
    // this.choices = ['arrowleft', 'arrowright'];
    // Only allow responses in the first probe state (trialState == 0),
    // and only with left/right arrows. In later states, ignore all keys.
    if (trialState === 0) {
        this.choices = ['arrowleft', 'arrowright'];
    } else {
        this.choices = jsPsych.NO_KEYS;
    }

    this.data = {};
}

// primitive of a single trial (2 option display)
export function StimulusOptions(cfg) {
    /* 
        cfg : object containing fields
            bagInputs: Array(2) of type bagInput 
                bagInput: Array(4)
            trialData: object containing trial data
                trialState: 0/ wait for response
                            1/ post-response
                            2/ is introduction trial
                condition:  1/ draw
                            2/ guess
                goalColor:  0/ orange
                            1/ blue
                (other data for database)
    */
    const trialState = cfg.trialData.trialState;
    const condition  = cfg.trialData.condition;
    const isTraining = cfg.isTraining;
    const goalColor = () => {
        const colText = ['orange','blue'];
        const nMinus1 = colorMap.length-1;
        return {
            text: colText[cfg.trialData.goalColor], 
            hex: colorMap[-nMinus1*cfg.trialData.goalColor+nMinus1]
        }
    };
    const iblock = cfg.trialData.iblock;
    const iseq = cfg.trialData.iseq;

    // bagInput values for pre and post choice
    // function bagStateInputs (trialState) {
    //     const bagInputs = Array.from({length: 2}, () => {
    //         return new Array(4);
    //     });

    //     switch (trialState) {
    //         case 1:
    //             const respKey = jsPsych.data.get().last(1).values()[0].response;
    //             // fill inputs based on response
    //             let chosenBag;
    //             if (respKey == 'f') { // left option chosen
    //                 chosenBag = 0;
    //             } else { // right option chosen
    //                 chosenBag = 1;
    //             }
    //             // show shape on chosen option
    //             bagInputs[chosenBag][0] = 0;
    //             bagInputs[chosenBag][1] = cfg.bagInputs[chosenBag][1];
    //             bagInputs[chosenBag][2] = cfg.bagInputs[chosenBag][2];
    //             bagInputs[chosenBag][3] = 2;
    //             // remove nonchosen option
    //             for (let iInput = 0; iInput < 4; iInput++){
    //                 bagInputs[Number(!chosenBag)][iInput] = 0;
    //             }
    //             break
    //         default:
    //             // fill inputs with bare minimum
    //             for (let ibag = 0; ibag < cfg.bagInputs.length; ibag++){
    //                 bagInputs[ibag][0] = 1;
    //                 bagInputs[ibag][1] = cfg.bagInputs[ibag][1];
    //                 bagInputs[ibag][3] = 0;
    //             }
    //     }
    //     return bagInputs
    // }

    function bagStateInputs(trialState) {
        const bagInputs = Array.from({length: cfg.bagInputs.length}, () => {
            return new Array(4);
        });

        switch (trialState) {
            case 1: {
                const respKey = jsPsych.data.get().last(1).values()[0].response;

                // map key → bag index
                const chosenBag = choiceSet.indexOf(respKey);   // 0,1,2

                // show chosen bag’s shape + color
                bagInputs[chosenBag][0] = 0;
                bagInputs[chosenBag][1] = cfg.bagInputs[chosenBag][1];
                bagInputs[chosenBag][2] = cfg.bagInputs[chosenBag][2];
                bagInputs[chosenBag][3] = 2;

                // remove all others
                for (let i = 0; i < cfg.bagInputs.length; i++) {
                    if (i !== chosenBag) {
                        for (let j = 0; j < 4; j++) {
                            bagInputs[i][j] = 0;
                        }
                    }
                }
                break;
            }

            default:
                for (let ibag = 0; ibag < cfg.bagInputs.length; ibag++) {
                    bagInputs[ibag][0] = 1;
                    bagInputs[ibag][1] = cfg.bagInputs[ibag][1];
                    bagInputs[ibag][3] = 0;
                }
        }
        return bagInputs;
    }
    
    const jsPsychStimTypes = () => {
        return (trialState == 2 ? "html-keyboard-response-min-duration" : "html-keyboard-response")
    }

    this.type = jsPsychStimTypes();
    this.choices = (trialState === 0 ? choiceSet : jsPsych.NO_KEYS);
    this.stimulus = () => {
        const bagInputs = bagStateInputs(trialState);
        // make div for each option
        const subDivs = new Array(bagInputs.length);
        for (let i = 0; i < bagInputs.length; i++) {
            subDivs[i] = document.createElement('div');
            subDivs[i].style.display = "inline-flex";
            subDivs[i].appendChild(bag(bagInputs[i]));
            subDivs[i].style.padding = "0px 10px";
        }
        
        // optional: tighter spacing for 3 bags, * old: 3 bags on horizontal line
        // if (bagInputs.length === 3) {
        //     for (let i = 0; i < 3; i++) {
        //         subDivs[i].style.margin = "0px 10px";
        //     }
        // }
        // // make div containing the option divs
        // const div = document.createElement('div');
        //     div.style.position = "absolute";
        //     div.style.width = "max-content";
        //     div.style.top = "50%";
        //     div.style.left = "50%";
        //     div.style.transform = "translate(-50%, -50%)";

        // layout container for the bag options
        const div = document.createElement('div');
        if (bagInputs.length === 3) {
            // triangle layout centered on screen
            div.style.position = "absolute";
            div.style.width = "100%";
            div.style.height = "100%";
            div.style.top = "0";
            div.style.left = "0";

            // const R = stimSize * 0.85;      // radius in pixels
            // const theta = 26;   // degrees
            // const rad = theta * Math.PI / 180;
            // const cosTheta = Math.cos(rad);
            // const sinTheta = Math.sin(rad);

            // // middle option on top, left and right below
            // const coords = [
            //     { x: -cosTheta * R,  y: +sinTheta * R },       // left
            //     { x: 0,              y: -R },               // middle (top)
            //     { x: +cosTheta * R,  y: +sinTheta * R }        // right
            // ];

            for (let i = 0; i < 3; i++) {
                const d = subDivs[i];
                d.style.position = "absolute";
                d.style.left = `calc(50% + ${coords[i].x}px)`;
                d.style.top  = `calc(50% + ${coords[i].y}px)`;
                d.style.transform = "translate(-50%, -50%)";
            }
        } else {
            // original center row layout for 2 bags or other cases
            div.style.position = "absolute";
            div.style.width = "max-content";
            div.style.top = "50%";
            div.style.left = "50%";
            div.style.transform = "translate(-50%, -50%)";
        }
        
        // ✅ ADD WARNING HERE
        // warning just above the top (middle) bag
        if (cfg.warningText) {
            const offset = stimSize; // distance above the top bag (px)
            const div_warn = document.createElement('div');
            div_warn.className = 'warning-text';
            // div_warn.textContent = cfg.warningText;
            div_warn.innerHTML = cfg.warningText;   // ← change 1
            div_warn.style.position = 'absolute';
            div_warn.style.left = '50%';
            div_warn.style.top = `calc(50% + ${coords[0].y + offset}px)`;
            div_warn.style.transform = 'translate(-50%, -50%)';
            // div_warn.style.fontWeight = 'bold';
            div_warn.style.color = '#A60000';
            div_warn.style.textAlign = 'center';
            // div_warn.style.whiteSpace = 'nowrap';
            div_warn.style.whiteSpace = 'pre';   // ← change 2
            div.appendChild(div_warn);
        }
        
        
        // make div containing introduction text
        if (trialState == 2) {
            const div_text = document.createElement('div');
            // line 1
            const line1Text = `Here are the bags for this series.`;
            div_text.appendChild(document.createTextNode(line1Text)); // first line of text
            div_text.appendChild(document.createElement('br'));
            // line 2
            const line2TextFn = () => {
                return [
                    [`This time the goal is to draw shapes with the strongest shades of `, `${goalColor().text}`, ` possible.`],
                    [`This time, the goal is to `, `discover`, ` the dominant colour of each bag!`]
                ]
            };
            const line2Text = line2TextFn()[condition-1];
            // span of the key word in line 2
            const span_word = document.createElement('span');
            if (condition == 1) { // draw: color is specified
                span_word.style.color = goalColor().hex;
            }
            span_word.style.fontStyle = "italic";
            span_word.style.fontWeight = "bold";
            span_word.appendChild(document.createTextNode(line2Text[1]));
            // span of 2nd line text
            const span = document.createElement('span');
            span.appendChild(document.createTextNode(line2Text[0]));
            span.appendChild(span_word);
            span.appendChild(document.createTextNode(line2Text[2]));
            div_text.appendChild(span);
            div_text.appendChild(document.createElement('br'));
            div_text.style.paddingBottom = '50px';
            div.appendChild(div_text);

  

        }
        // attach the bag divs
        // div.appendChild(subDivs[0]);
        // div.appendChild(subDivs[1]);

        // attach the bag divs
        for (let i = 0; i < subDivs.length; i++) {
            div.appendChild(subDivs[i]);
        }
        // continue prompt for instruction trial
        // if (trialState == 2) {
        //     const div_continue = document.createElement('div');
        //     div_continue.appendChild(document.createTextNode('Press [spacebar] to start'));
        //     div_continue.style.paddingTop = '60px';
        //     div.appendChild(div_continue);
        // }
        if (trialState == 2) { // YC: 16/01/2026 to match style 
            const div_continueSpacebar = document.createElement('div');
            div_continueSpacebar.style.width = '100%';
            div_continueSpacebar.style.position = 'absolute';
            div_continueSpacebar.style.top = '92%';
            div_continueSpacebar.style.left = '50%';
            div_continueSpacebar.style.transform = 'translate(-50%, -92%)';
            div_continueSpacebar.appendChild(
                document.createTextNode('Press [spacebar] to start')
            );
            div.appendChild(div_continueSpacebar);
        }
        // add everything to main container
        const container = containerElement();
            container.appendChild(div);
        
        // show progress bar 
        if (trialState == 2 && !isTraining) {
            const barWidth = '120px';
            const barHeight = '20px';
            const div_progress = document.createElement('div');
                div_progress.style.width = '100%';
                div_progress.style.position = 'absolute';
                div_progress.style.top = '10%';
                div_progress.style.left = '50%';
                div_progress.style.transform = "translate(-50%, -10%)";
                
            const divs_block = Array.from({length: nb_total}, () => {
                return document.createElement('div');
            });
            for (let i = 0; i < nb_total; i++) {
                // draw borders
                divs_block[i].style.boxShadow = "-1px -1px black, -1px 1px black, -1px 1px black";
                if (i == nb_total-1) {
                    divs_block[i].style.boxShadow = "-1px -1px black, 1px 1px black, -1px 1px black, 1px -1px black";
                }
                divs_block[i].style.display = "inline-flex";
                divs_block[i].style.width = barWidth;
                divs_block[i].style.height = barHeight;

                // fill in the progress
                if (i < iblock) {
                    // fill the entire block
                    divs_block[i].style.backgroundColor = '#E1E1E1';
                } else if (i == iblock) {
                    // fill based on sequence position
                    const div_currentBlock = document.createElement('div');
                    div_currentBlock.style.position = 'relative';
                    div_currentBlock.style.width = `${Math.round(iseq/ns_total*100)}%`;
                    div_currentBlock.style.height = '100%';
                    div_currentBlock.style.backgroundColor = '#E1E1E1';
                    divs_block[i].appendChild(div_currentBlock);
                }
                div_progress.appendChild(divs_block[i]);
            }
            container.appendChild(div_progress);
        }

        return container.innerHTML;
    };
    this.data = {};
    this.on_finish = (data) => {
        // copy metadata from cfg.trialData
        Object.assign(data, cfg.trialData);

        // only on the choice state (trialState 0) do we have a keypress
        if (trialState === 0) {
            const respKey   = data.response;
            const chosenBag = choiceSet.indexOf(respKey);  // 0,1,2 for f,j,k

            data.chosen_bag = chosenBag;

            if (cfg.shapes && cfg.shapes.length > chosenBag) {
                data.shape = cfg.shapes[chosenBag];
            }
            if (cfg.colors && cfg.colors.length > chosenBag) {
                data.color = cfg.colors[chosenBag];
            }
        }
    };
    
}

// template for data responses
export class RespDataTemplate {
    constructor (data) {
        const { iblk, iseq_abs, iseq_blk, icnd, it_abs, it_seq, symm,
                is_guess, targ_shape, targ_blue } = data;
        this.iblk = iblk;
        this.iseq_abs = iseq_abs;
        this.iseq_blk = iseq_blk;
        this.icnd = icnd;
        this.it_abs = it_abs;
        this.it_seq = it_seq;
        this.symm = symm;
        this.is_guess = is_guess;
        this.targ_shape = targ_shape;
        this.targ_blue = targ_blue;
    }
}