// import constants
import { constants } from './global_constants.js'
import { bag } from './task_modules.js'

const { containerElement, inst_imgs, choiceSet, colorMap } = constants;

export function instruction_stim(instr_type, type_index) {
    // spacebar continue text 
    const div_continueSpacebar = document.createElement('div');
          div_continueSpacebar.style.width = '100%';
          div_continueSpacebar.style.position = 'absolute';
          div_continueSpacebar.style.top = '92%';
          div_continueSpacebar.style.left = '50%';
          div_continueSpacebar.style.transform = "translate(-50%, -92%)";
    div_continueSpacebar.appendChild(document.createTextNode('Press [spacebar] to continue'));

    const visibilityHandle = ['hidden','visible'];
    const displayHandle = ['none','initial'];

    // load the instructions by type
    const stimObject = () => {
        
        let textArray = [];
        switch (instr_type) {
            case 'read_prompt':
                textArray.push('Read the instructions carefully, you will have to answer questions about them!');

                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();
                        const div_text = document.createElement('div');
                        div_text.appendChild(document.createTextNode(textArray[0]));
                        container.appendChild(div_text);
                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML
                    },
                    choices: [' '],
                }

            case 'bags':
                // visibility for each image (indices 0-7)
                const imgVisibility = () => {
                    switch (type_index) {
                        case 0: // 1 upper div
                            return [1,0,0,0,0,0,0,0]
                        case 1: // 2 upper div
                            return [0,1,0,0,0,0,0,0]
                        case 2: // 1 upper div, 3 lower left div
                            return [1,0,1,0,0,0,0,0]
                        case 3: // 1 upper div, 3 & 4 lower left div
                            return [1,0,1,1,0,0,0,0]
                        case 4: // 1 upper div, 3 & 4 & 5 lower left div
                            return [1,0,1,1,1,0,0,0]
                        case 5: // 1 upper div, 3 & 4 lower left div, 6 lower right div
                            return [1,0,1,1,0,1,0,0]
                        case 6: // 1 upper div, 3 & 4 lower left div, 6 & 7 lower right div
                            return [1,0,1,1,0,1,1,0]
                        case 7: // 1 upper div, 3 & 4 lower left div, 6 & 7 & 8 lower right div
                            return [1,0,1,1,0,1,1,1]
                    }
                }
                
                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();
                        // div positioning 
                        const div_upperText = document.createElement('div');
                            div_upperText.style.position = 'absolute';
                            div_upperText.style.width = '100%';
                            div_upperText.style.top = '5%';
                            div_upperText.style.left = '50%';
                            div_upperText.style.transform = "translate(-50%, -5%)";

                        const div_upper = document.createElement('div');
                            div_upper.style.position = 'absolute';
                            div_upper.style.width = '100%';
                            div_upper.style.top = '20%';
                            div_upper.style.left = '50%';
                            div_upper.style.transform = "translate(-50%, -20%)";

                        const div_lower = document.createElement('div');
                            div_lower.style.position = 'absolute';
                            div_lower.style.width = '90%';
                            div_lower.style.top = '65%';
                            div_lower.style.transform = "translate(-50%, -60%)";

                        const div_lowerCont = document.createElement('div');
                            div_lowerCont.style.display = 'flex';
                            div_lowerCont.style.flexFlow = 'row';

                        const div_lowerL = document.createElement('div');
                            div_lowerL.style.display = "inline-flex";

                        const div_lowerR = document.createElement('div');
                            div_lowerR.style.display = "inline-flex";
                        
                        div_lowerCont.appendChild(div_lowerL);
                        div_lowerCont.appendChild(div_lowerR);
                        div_lower.appendChild(div_lowerCont);

                        const bagInstImgs = Array.from({length: 8}, () => {
                            return document.createElement('img')
                        });

                        // source and place the images in their appropriate divs
                        for (let i = 0; i < 8; i++) {
                            bagInstImgs[i].src = inst_imgs[i];
                            
                            if (i < 2) { // bag lineup
                                bagInstImgs[i].style.width = '80%';
                                bagInstImgs[i].style.display = displayHandle[imgVisibility()[i]];
                                div_upper.appendChild(bagInstImgs[i]);

                            } else if (i < 5) { // blue bags
                                bagInstImgs[i].style.width = '85%';
                                bagInstImgs[i].style.visibility = visibilityHandle[imgVisibility()[i]];

                                const div_stackLeft = document.createElement('div');
                                if (i == 2) {
                                    div_stackLeft.style.position = 'relative';
                                } else {
                                    div_stackLeft.style.position = 'absolute';
                                    div_stackLeft.style.top = '50%';
                                    div_stackLeft.style.left = '50%';
                                    div_stackLeft.style.transform = "translate(-100%, -50%)";
                                }
                                div_stackLeft.appendChild(bagInstImgs[i]);
                                div_lowerL.appendChild(div_stackLeft);

                            } else if (i < 8) { // orange bags
                                bagInstImgs[i].style.width = '85%';
                                bagInstImgs[i].style.visibility = visibilityHandle[imgVisibility()[i]];

                                const div_stackRight = document.createElement('div');
                                if (i == 5) {
                                    div_stackRight.style.position = 'relative';
                                } else {
                                    div_stackRight.style.position = 'absolute';
                                }
                                div_stackRight.appendChild(bagInstImgs[i]);
                                div_lowerR.appendChild(div_stackRight);
                            }
                        }

                        // put the red-colored text prompts here
                        if (type_index == 4 | type_index == 7) {
                            const div_blurb = document.createElement('div');
                                div_blurb.style.position = 'absolute';
                                div_blurb.style.width = 'max-content';
                                div_blurb.style.backgroundColor = '#F7E8E8';
                                div_blurb.style.top = '55%';
                                div_blurb.style.left = '50%';
                                div_blurb.style.transform = "translate(-50%, -50%)";
                                div_blurb.style.border = "2px solid #A60000";
                                div_blurb.style.padding = "0px 10px";

                            const blurb_text = () => {
                                switch (type_index) {
                                    case 4:
                                        return [`The actual shades can be`,
                                            `more or less intense, or`,
                                            `there can be some`,
                                            `mismatched colours, but`,
                                            `on the whole you will see`,
                                            `mainly blue`];
                                    case 7:
                                        return [`Again, some`,
                                            `mismatched`,
                                            `draws, but over`,
                                            `all the shapes,`,
                                            `we see mainly`,
                                            `orange`];
                                } 
                            };
                            for (let i = 0; i < blurb_text().length; i++) {
                                const span = document.createElement('span');
                                span.style.color = '#A60000';
                                if (i >= blurb_text().length-2) { // bold and italicize last 2 lines
                                    span.style.fontWeight = "bold";
                                    span.style.fontStyle = "italic";
                                }
                                span.appendChild(document.createTextNode(blurb_text()[i]));
                                div_blurb.appendChild(span);
                                div_blurb.appendChild(document.createElement('br'));
                            }
                            container.appendChild(div_blurb);
                        }

                        div_upperText.appendChild(
                            document.createTextNode('This experiment is about bags with shapes in them:'));
                        
                        container.appendChild(div_upperText);
                        container.appendChild(div_upper);
                        container.appendChild(div_lower);
                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML
                    },
                    choices: [' ']
                }
                
            case 'draw':
                /* 
                    0   Condition intro
                    1-4 Show the 2 bags, and write more stuff
                        // Do sample trials (inside of exec_task.js)
                    END Ending message
                */
                const introDrawTextArr = [
                    [`Here is how you play the `, `DRAWING`, ` game.`], // 3 elements
                    `For each series, you will be presented with two bags of shapes (e.g. circles and crosses):`,
                    `You don't know yet what their dominant colour is...`,
                    [`For example, here, your goal is to draw as much `, `orange`, ` as possible!`,
                            `You make points towards your bonus by drawing as much orange as possible.`], // 4 elements
                    `Use your keyboard to draw shapes from the bags.`,
                    `That was one series of the DRAWING game. Congratulations!`
                ];

                const textDrawVis = Array.from([...Array(introDrawTextArr.length-1).keys()].map(i => {
                    return (i <= type_index ? 1 : 0) 
                }));

                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();

                        const div_upperText = document.createElement('div');
                              div_upperText.style.position = 'absolute';
                              div_upperText.style.width = '100%';
                              div_upperText.style.top = '5%';
                              div_upperText.style.left = '50%';
                              div_upperText.style.transform = "translate(-50%, -5%)";
                        
                        // text placement
                        for (let i = 0; i < introDrawTextArr.length-1; i++) {
                            const span = document.createElement('span');
                            span.style.visibility = visibilityHandle[textDrawVis[i]];
                            if (i == 0 | i == 3) {
                                for (let j = 0; j < introDrawTextArr[i].length; j++) {
                                    if (j == 1) {
                                        const boldSpan = document.createElement('span');
                                        boldSpan.style.fontWeight = "bold";
                                        if (i == 3) {
                                            boldSpan.style.color = colorMap.slice(-1);
                                        }
                                        boldSpan.appendChild(document.createTextNode(introDrawTextArr[i][j]))
                                        span.appendChild(boldSpan);
                                    } else {
                                        span.appendChild(document.createTextNode(introDrawTextArr[i][j]));
                                    }
                                    if (i == 3 & j == 2) {
                                        span.appendChild(document.createElement('br'));
                                    }
                                }
                                div_upperText.appendChild(span);
                                div_upperText.appendChild(document.createElement('br'));
                            } else {
                                span.appendChild(document.createTextNode(introDrawTextArr[i]));
                                div_upperText.appendChild(span);
                                div_upperText.appendChild(document.createElement('br'));
                            }
                            if (i != 1) {
                                div_upperText.appendChild(document.createElement('br'));
                            }
                        }

                        // bags placement
                        const div_bags = document.createElement('div');
                              div_bags.style.position = 'absolute';
                              div_bags.style.width = '100%';
                              div_bags.style.top = '65%';
                              div_bags.style.left = '50%';
                              div_bags.style.transform = "translate(-50%, -65%)";
                        // bag shapes specification
                        const bagInputs = [[1,constants.shapesTutDraw[0],undefined,0], 
                                           [1,constants.shapesTutDraw[1],undefined,0]];
                        // options placement
                        const optionDivs = new Array(2);
                        for (let i = 0; i < optionDivs.length; i++) {
                            optionDivs[i] = document.createElement('div');
                            optionDivs[i].style.display = "inline-flex";
                            optionDivs[i].style.padding = "0px 40px";

                            const div_option = document.createElement('div');
                            div_option.appendChild(bag(bagInputs[i]));
                            // add text
                            const div_optionText = document.createElement('div');
                                  div_optionText.appendChild(document.createTextNode('press '));
                            const keySpan = document.createElement('span');
                                  keySpan.style.fontWeight = "bold";
                                  keySpan.appendChild(document.createTextNode(`[${choiceSet[i]}]`));
                            div_optionText.appendChild(keySpan);
                            div_optionText.appendChild(document.createTextNode(' to draw a'));
                            div_optionText.appendChild(document.createElement('br'));
                            div_optionText.appendChild(document.createTextNode('shape from this bag'));
                            // change visibility when it matters
                            if (type_index == 4) {
                                div_optionText.style.visibility = "visible";
                            } else {
                                div_optionText.style.visibility = "hidden";
                            }
                            div_option.appendChild(div_optionText);
                            optionDivs[i].appendChild(div_option);
                            div_bags.appendChild(optionDivs[i]);
                        }
                        if (type_index == introDrawTextArr.length-1) {
                            const div_text = document.createElement('div');
                            div_text.appendChild(document.createTextNode(introDrawTextArr.slice(-1)));
                            container.appendChild(div_text);
                        } else {
                            container.appendChild(div_upperText);
                            container.appendChild(div_bags);
                        }
                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML
                    },
                    choices: [' '],
                }

            case 'disc':
                const introDiscTextArr = [
                    [`Here is how you play the `, `DISCOVERING`, ` game.`], // 3 elements
                    // `For each series, you will be presented with two bags of shapes (e.g. moons and stars):`, //DEBUG 
                    // `You don't know yet what their dominant colour is...`,
                    [`For this series, your job is to `, `discover`, ` the dominant colour of each bag!`, // 4 elements
                        `You make points towards your bonus if you manage to discover the correct colours at the end of the series.`],
                    `Use your keyboard to draw shapes from the bags.`,
                    [`As you just saw, the series can stop `, `at any time`, ` to ask you about one of the bags!`],
                    `That was one series of the DISCOVERING game. Congratulations!`
                ];

                const textDiscVis = Array.from([...Array(introDiscTextArr.length-2).keys()].map(i => {
                    return (i <= type_index ? 1 : 0) 
                }));

                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();
                        const div_upperText = document.createElement('div');
                              div_upperText.style.position = 'absolute';
                              div_upperText.style.width = '100%';
                              div_upperText.style.top = '5%';
                              div_upperText.style.left = '50%';
                              div_upperText.style.transform = "translate(-50%, -5%)";
                        if (type_index < 4) {
                            for (let i = 0; i < introDiscTextArr.length-2; i++) {
                                const span = document.createElement('span');
                                span.style.visibility = visibilityHandle[textDiscVis[i]];
                                if (i < 2) {
                                    for (let j = 0; j < introDiscTextArr[i].length; j++) {
                                        if (j == 1) {
                                            const boldSpan = document.createElement('span');
                                            boldSpan.style.fontWeight = "bold";
                                            boldSpan.appendChild(document.createTextNode(introDiscTextArr[i][j]))
                                            span.appendChild(boldSpan);
                                        } else {
                                            span.appendChild(document.createTextNode(introDiscTextArr[i][j]));
                                        }
                                        if (i == 1 & j == 2) {
                                            span.appendChild(document.createElement('br'));
                                        }
                                    }
                                } else {
                                    span.appendChild(document.createTextNode(introDiscTextArr[i]));
                                }
                                div_upperText.appendChild(span);
                                div_upperText.appendChild(document.createElement('br'));
                                div_upperText.appendChild(document.createElement('br'));
                            }
                        }

                        // bags placement
                        const div_bags = document.createElement('div');
                              div_bags.style.position = 'absolute';
                              div_bags.style.width = '100%';
                              div_bags.style.top = '65%';
                              div_bags.style.left = '50%';
                              div_bags.style.transform = "translate(-50%, -65%)";
                        // bag shapes specification
                        const bagInputs = [[1,constants.shapesTutDisc[0],undefined,0], 
                                           [1,constants.shapesTutDisc[1],undefined,0]];
                        // options placement
                        const optionDivs = new Array(2);
                        for (let i = 0; i < optionDivs.length; i++) {
                            optionDivs[i] = document.createElement('div');
                            optionDivs[i].style.display = "inline-flex";
                            optionDivs[i].style.padding = "0px 40px";
                            const div_option = document.createElement('div');
                                  div_option.appendChild(bag(bagInputs[i]));
                            // add text
                            const div_optionText = document.createElement('div');
                                  div_optionText.appendChild(document.createTextNode('press '));
                            const keySpan = document.createElement('span');
                                  keySpan.style.fontWeight = "bold";
                                  keySpan.appendChild(document.createTextNode(`[${choiceSet[i]}]`));
                            div_optionText.appendChild(keySpan);
                            div_optionText.appendChild(document.createTextNode(' to draw a'));
                            div_optionText.appendChild(document.createElement('br'));
                            div_optionText.appendChild(document.createTextNode('shape from this bag'));
                            // change option text visibility when it matters
                            if (type_index == 2 | type_index == 3) {
                                div_optionText.style.visibility = "visible";
                            } else {
                                div_optionText.style.visibility = "hidden";
                            }
                            div_option.appendChild(div_optionText);
                            optionDivs[i].appendChild(div_option);
                            div_bags.appendChild(optionDivs[i]);
                        }

                        // different format text stimuli
                        if (type_index >= 4) {
                            const div_text = document.createElement('div');
                            if (type_index == 4) {
                                for (let i = 0; i < introDiscTextArr[3].length; i++) {
                                    const span_text = document.createElement('span');
                                    span_text.appendChild(document.createTextNode(introDiscTextArr[3][i]));
                                    if (i == 1) {
                                        span_text.style.fontWeight = "bold";
                                        span_text.style.fontStyle = "italic";
                                    }
                                    div_text.appendChild(span_text);
                                }
                            } else {
                                div_text.appendChild(document.createTextNode(introDiscTextArr.slice(-1)));
                            }
                            container.appendChild(div_text);
                        } else {
                            container.appendChild(div_upperText);
                            container.appendChild(div_bags);
                        }
                        
                        // for the red text box on 4th stimulus
                        if (type_index == 3) {
                            const div_textBox = document.createElement('div');
                                  div_textBox.style.width = "20%";
                                  div_textBox.style.backgroundColor = '#F7E8E8';
                                  div_textBox.style.border = "3px solid #A60000";
                                  div_textBox.style.padding = "0px 10px";
                                  div_textBox.style.color = '#A60000';

                            div_textBox.appendChild(document.createTextNode(`
                                        Be careful: if the bag of moons is mainly orange, 
                                        it does not mean that the bag of stars is necessarily blue!`));
                            div_textBox.appendChild(document.createElement('br'));
                            const boldSpan = document.createElement('span');
                                  boldSpan.style.color = '#A60000';
                                  boldSpan.style.fontWeight = "bold";
                                  boldSpan.style.fontStyle = "italic";
                                  boldSpan.appendChild(document.createTextNode(`
                                        It is possible that both bags are blue, or both bags are orange!
                                    `));
                            div_textBox.appendChild(boldSpan);
                            container.appendChild(div_textBox);
                        }
                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML
                    },
                    choices: [' ']
                }

            case 'overview':
                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();
                        const div_upper = document.createElement('div');
                              div_upper.style.position = 'absolute';
                              div_upper.style.width = '100%';
                              div_upper.style.top = '5%';
                              div_upper.style.left = '50%';
                              div_upper.style.transform = "translate(-50%, -5%)";

                        const upperText = `That's it, these are the two possible games you will have to play!`;
                        div_upper.appendChild(document.createTextNode(upperText));
                        container.appendChild(div_upper);
                        
                        // put the screenshots in the stimulus
                        for (let i = 0; i < type_index + 1; i++) {
                            const div_content = document.createElement('div');
                            div_content.style.position = "absolute";
                            div_content.style.width = '80%';
                            div_content.style.top = '25%';
                            div_content.style.left = '50%';
                            div_content.style.transform = "translate(-50%, -25%)";
                            
                            const img = document.createElement('img');
                            img.src = inst_imgs[10+i];
                            img.style.width = '100%';
                            div_content.appendChild(img);
                            container.appendChild(div_content);
                        }

                        // place lower text
                        const div_lower = document.createElement('div');
                              div_lower.style.position = 'absolute';
                              div_lower.style.width = '80%';
                              div_lower.style.top = '80%';
                              div_lower.style.left = '50%';
                              div_lower.style.transform = "translate(-50%, -80%)";
                            //   div_lower.style.textAlign = "left";
                        const lowerText = [
                            [`In the experiment, you will play many series of the `, `drawing`, ` and `, `discovering`, ` games:`],
                            `- The game changes randomly for each series`,
                            `- The bags and their dominant colours change randomly at each series`,
                            `- The duration of the series is random: the computer can stop the series after a few or many draws`
                        ];
                        for (let i = 0; i < lowerText.length; i++) {
                            const span_line = document.createElement('span');
                            if (i == 0) {
                                for (let j = 0; j < lowerText[i].length; j++) {
                                    const span = document.createElement('span');
                                    if (j % 2 == 1) {
                                        span.style.fontWeight = "bold";
                                    }
                                    span.appendChild(document.createTextNode(lowerText[i][j]));
                                    span_line.appendChild(span);
                                }
                            } else {
                                span_line.appendChild(document.createTextNode(lowerText[i]));
                            }
                            div_lower.appendChild(span_line);
                            div_lower.appendChild(document.createElement('br'));
                        }
                        container.appendChild(div_lower);
                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML
                    },
                    choices: [' '],
                }

            case 'keepinmind':
                const textDivVis_keep = () => {
                    switch (type_index) {
                        case 0: 
                            return [0,0,0]
                        case 1:
                            return [1,0,0]
                        case 2:
                            return [1,0,0]
                        case 3:
                            return [1,1,0]
                        case 4:
                            return [1,1,0]
                        case 5:
                            return [1,1,1]
                    }
                };

                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();
                        // div positioning
                        const div_upperText = document.createElement('div');
                            div_upperText.style.position = 'absolute';
                            div_upperText.style.width = '100%';
                            div_upperText.style.top = '5%';
                            div_upperText.style.left = '-35%';
                            div_upperText.style.transform = "translate(0%, -5%)";

                        const div_textBox = Array.from({length: 3}, () => {
                            return document.createElement('div')
                        });
                        const box_text = [
                            [`The bags are not perfectly sorted by`,
                                `colour: there will always be a mixture of`,
                                `both colours in the bag, but one is`,
                                `dominant...`],
                            [`...so the intensity of the shades is informative:`,
                                `it’s not enough to just count the number of blue`,
                                `vs. orange triangles, you have to also consider`,
                                `how intensely blue or orange they are...`],
                            [`...and finally, you cannot guess the dominant`,
                                `colour of the second bag from the colour of the`,
                                `first bag: it is not the case that because one of`,
                                `the bags is mainly blue, the other one is mainly`,
                                `orange!`,
                                `Both bags can be blue or both bags can be orange!`]
                        ];
                        const textBoxStyles = {
                            top: ['25%','30%','55%'],
                            left: ['10%','65%','50%']
                        }

                        for (let i = 0; i < div_textBox.length; i++) {
                            div_textBox[i].style.position = 'absolute';
                            div_textBox[i].style.width = 'max-content';
                            div_textBox[i].style.backgroundColor = '#F7E8E8';
                            div_textBox[i].style.border = "3px solid #A60000";
                            div_textBox[i].style.padding = "0px 10px";
                            div_textBox[i].style.top = textBoxStyles.top[i];
                            div_textBox[i].style.left = textBoxStyles.left[i];
                            div_textBox[i].style.transform = `translate(-${textBoxStyles.top[i]}, -${textBoxStyles.left[i]})`;

                            for (let j = 0; j < box_text[i].length; j++) {
                                const span = document.createElement('span');
                                span.style.color = '#A60000';
                                if ((i == 1 & j == 0) | (i % 2 == 0 & j == box_text[i].length-1)) {
                                    span.style.fontWeight = "bold";
                                    span.style.fontStyle = "italic";
                                }
                                span.appendChild(document.createTextNode(box_text[i][j]));
                                div_textBox[i].appendChild(span);
                                div_textBox[i].appendChild(document.createElement('br'));
                            }
                            div_textBox[i].style.visibility = visibilityHandle[textDivVis_keep()[i]];
                            container.appendChild(div_textBox[i]);
                        }
                        // show preloaded images here (indices 8 and 9)
                        if (type_index == 2 | type_index == 4) {
                            const div_img = document.createElement('div');
                            const img = () => {
                                const img = document.createElement('img');
                                if (type_index == 2) {
                                        img.src =  inst_imgs[8];
                                } else if (type_index == 4) {
                                        img.src =  inst_imgs[9];
                                }
                                img.style.width = '70%';
                                return img
                            };
                            div_img.style.position = 'absolute';
                            div_img.style.width = '100%';
                            div_img.style.top = '80%';
                            div_img.style.left = '50%';
                            div_img.style.transform = 'translate(-50%, -80%)';
                            div_img.appendChild(img());
                            container.appendChild(div_img);
                        }
                        
                        div_upperText.appendChild(
                            document.createTextNode('There are three things to keep in mind:'));
                        container.appendChild(div_upperText);
                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML
                    },
                    choices: [' '],
                }

            case 'questions':


        }
    }

    return stimObject()
}

export function training_stim(stimType) {
    // spacebar continue text 
    const div_continueSpacebar = document.createElement('div');
          div_continueSpacebar.style.width = '100%';
          div_continueSpacebar.style.position = 'absolute';
          div_continueSpacebar.style.top = '92%';
          div_continueSpacebar.style.left = '50%';
          div_continueSpacebar.style.transform = "translate(-50%, -92%)";
    div_continueSpacebar.appendChild(document.createTextNode('Press [spacebar] to continue'));


    const textArray = () => {
        switch (stimType) {
            case 'prompt':
                return ['You will now play a short training block',
                        'to familiarize yourself with the flow of the task.']
            case 'medals':
                return ['At the end of each block, you will receive some feedback on your performance.',
                        'br',
                        'Depending on your performance, you can get a medal for each block,',
                        'either bronze, silver, or gold.',
                        'br',
                        'However, you may also receive no medals if you did not perform well during the block.',
                        `Let's see if you got a medal during the training.`]
        }
    };
    
    const stimObject = () => {
        return {
            type: 'html-keyboard-response',
            stimulus: () => {
                const container = containerElement();
                const text = textArray();
                const div_text = document.createElement('div');
                for (let i = 0; i < text.length; i++) {
                    if (text[i] == 'br') {
                        div_text.appendChild(document.createElement('br'));
                    } else {
                        div_text.appendChild(document.createTextNode(text[i]));
                        div_text.appendChild(document.createElement('br'));
                    }
                }
                container.appendChild(div_text);
                container.appendChild(div_continueSpacebar);

                return container.innerHTML
            },
            choices: [' ']
        }
    }

    return stimObject()
}

export function check_instructions() {
    
}