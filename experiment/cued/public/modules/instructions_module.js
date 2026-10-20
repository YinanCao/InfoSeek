// import constants
import { constants } from './global_constants.js'
import { bag } from './task_modules.js'

const { containerElement, inst_imgs, choiceSet, colorMap, stimSize} = constants;

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
                textArray.push('Please read the instructions carefully, you will need to answer questions about them later!');

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
                                            `mainly blue.`];
                                    case 7:
                                        return [`Again, some`,
                                            `mismatched`,
                                            `draws, but overall`,
                                            `you see mainly`,
                                            `orange.`];
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

        case 'choice_intro':
            const choiceIntroTextArr = [
                `In this task, you will see two bags on the screen, each containing a different shape.`,
                `On each trial, you will draw one shape from one of the two bags.`,
                `You will draw repeatedly from the bags, one trial after another, in a sequence, so that you can learn what each bag usually contains.`,
                `Each bag has a dominant colour. This means that one colour is more intense in that bag.`,
                `At the beginning of each sequence, you do not know the dominant colour of either bag. But you learn over time.`,
                [`There are two kinds of games: `, `FREE CHOICE`, ` and `, `CUED CHOICE`, `.`],
            ];

            return {
                type: 'html-keyboard-response',
                stimulus: () => {
                    const container = containerElement();

                    const div_text = document.createElement('div');
                    div_text.style.position = 'absolute';
                    div_text.style.width = '80%';
                    div_text.style.top = '35%';
                    div_text.style.left = '50%';
                    div_text.style.transform = 'translate(-50%, -35%)';
                    div_text.style.fontSize = '22px';
                    div_text.style.lineHeight = '1.6';

                    const thisText = choiceIntroTextArr[type_index];

                    if (Array.isArray(thisText)) {
                        for (let i = 0; i < thisText.length; i++) {
                            const span = document.createElement('span');
                            span.appendChild(document.createTextNode(thisText[i]));
                            if (i === 1 || i === 3) {
                                span.style.fontWeight = 'bold';
                            }
                            div_text.appendChild(span);
                        }
                    } else {
                        div_text.appendChild(document.createTextNode(thisText));
                    }

                    container.appendChild(div_text);
                    if (type_index === 0) {
                            const div_img = document.createElement('div');
                            div_img.style.position = 'absolute';
                            div_img.style.width = '100%';
                            div_img.style.top = '40%';
                            div_img.style.left = '50%';
                            div_img.style.transform = 'translate(-50%, 0%)';
                            div_img.style.textAlign = 'center';
                            const img = document.createElement('img');
                            img.src = inst_imgs[16];
                            img.style.maxWidth = '20%';
                            img.style.maxHeight = '38vh';
                            img.style.display = 'inline-block';
                            div_img.appendChild(img);
                            container.appendChild(div_img);
                        }
                    container.appendChild(div_continueSpacebar);

                    return container.innerHTML;
                },
                choices: [' ']
            };
                
            case 'free':
                const freeTextArr = [
                    [`Here is how `, `FREE CHOICE`, ` game works.`],
                    `On a FREE CHOICE trial, both bags are available.`,
                    `You can choose either the left bag or the right bag.`,
                    `You will use the left and right arrow keys to choose the bag you want to sample.`,
                    `In short: FREE CHOICE means you decide.`
                ];

                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();
                        const div_text = document.createElement('div');
                        div_text.style.position = 'absolute';
                        div_text.style.width = '80%';
                        div_text.style.top = '35%';
                        div_text.style.left = '50%';
                        div_text.style.transform = 'translate(-50%, -35%)';
                        div_text.style.fontSize = '22px';
                        div_text.style.lineHeight = '1.6';

                        const thisText = freeTextArr[type_index];

                        if (Array.isArray(thisText)) {
                            for (let i = 0; i < thisText.length; i++) {
                                const span = document.createElement('span');
                                span.appendChild(document.createTextNode(thisText[i]));
                                if (i === 1) {
                                    span.style.fontWeight = 'bold';
                                }
                                div_text.appendChild(span);
                            }
                        } else {
                            div_text.appendChild(document.createTextNode(thisText));
                        }

                        container.appendChild(div_text);
                        if (type_index === 3) {
                            const div_img = document.createElement('div');
                            div_img.style.position = 'absolute';
                            div_img.style.width = '100%';
                            div_img.style.top = '48%';
                            div_img.style.left = '50%';
                            div_img.style.transform = 'translate(-50%, 0%)';
                            div_img.style.textAlign = 'center';
                            const img = document.createElement('img');
                            img.src = inst_imgs[15];
                            img.style.maxWidth = '60%';
                            img.style.maxHeight = '38vh';
                            img.style.display = 'inline-block';
                            div_img.appendChild(img);
                            container.appendChild(div_img);
                        }

                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML;
                    },
                    choices: [' ']
                };

            case 'forced':
                const forcedTextArr = [
                    // [`Alternatively you will also encounter forced-choice game. Here is how `, `CUED CHOICE`, ` game works.`],
                    [`Next, let's look at `, `CUED CHOICE`, `.`],
                    `On a CUED CHOICE trial, only one bag is available for sampling.`,
                    `The available bag is highlighted by a black frame.`,
                    `You will need to press the left or right arrow key corresponding to the highlighted bag.`,
                    `In short: CUED CHOICE means follow the black frame.`
                ];

                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();

                        const div_text = document.createElement('div');
                        div_text.style.position = 'absolute';
                        div_text.style.width = '80%';
                        div_text.style.top = '35%';
                        div_text.style.left = '50%';
                        div_text.style.transform = 'translate(-50%, -35%)';
                        div_text.style.fontSize = '22px';
                        div_text.style.lineHeight = '1.6';

                        const thisText = forcedTextArr[type_index];

                        if (Array.isArray(thisText)) {
                            for (let i = 0; i < thisText.length; i++) {
                                const span = document.createElement('span');
                                span.appendChild(document.createTextNode(thisText[i]));
                                if (i === 1) {
                                    span.style.fontWeight = 'bold';
                                }
                                div_text.appendChild(span);
                            }
                        } else {
                            div_text.appendChild(document.createTextNode(thisText));
                        }

                        container.appendChild(div_text);
                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML;
                    },
                    choices: [' ']
                };


            case 'probe_explain_free':
                const probeFreeTextArr = [
                    `As you just saw, a sequence can stop and ask you about the bags' dominant colours.`,
                    `Your job is to choose which colour you think was dominant in each bag, based on all the outcomes you saw.`
                ];

                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();

                        const div_text = document.createElement('div');
                        div_text.style.position = 'absolute';
                        div_text.style.width = '80%';
                        div_text.style.top = '35%';
                        div_text.style.left = '50%';
                        div_text.style.transform = 'translate(-50%, -35%)';
                        div_text.style.fontSize = '22px';
                        div_text.style.lineHeight = '1.6';

                        div_text.appendChild(document.createTextNode(probeFreeTextArr[type_index]));

                        container.appendChild(div_text);
                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML;
                    },
                    choices: [' ']
                };

            case 'probe_explain_forced':
                const probeForcedTextArr = [
                    `As you just saw, a cued-choice game can also stop and ask you about the dominant colours of both bags.`,
                    `Pay close attention to the colour outcomes, as accuracy on these questions contributes to your bonus.`
                ];

                return {
                    type: 'html-keyboard-response',
                    stimulus: () => {
                        const container = containerElement();

                        const div_text = document.createElement('div');
                        div_text.style.position = 'absolute';
                        div_text.style.width = '80%';
                        div_text.style.top = '35%';
                        div_text.style.left = '50%';
                        div_text.style.transform = 'translate(-50%, -35%)';
                        div_text.style.fontSize = '22px';
                        div_text.style.lineHeight = '1.6';

                        div_text.appendChild(document.createTextNode(probeForcedTextArr[type_index]));

                        container.appendChild(div_text);
                        container.appendChild(div_continueSpacebar);

                        return container.innerHTML;
                    },
                    choices: [' ']
                };

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


                        const upperText = `That's it, these are the two possible games you will see during the task.`;
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
                              
                        const lowerText = [
                            [`In the experiment, you will see both `, `free-choice`, ` and `, `cued-choice`, ` games.`],
                            `On free-choice trials, you decide which bag to sample.`,
                            `On cued-choice trials, you choose the bag highlighted by the black frame.`,
                            `The bags and their dominant colours are newly generated for each game.`,
                            `The experiment is divided into 5 blocks, with a short self-paced break between blocks.`
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
                                `both colours in the bag, but one colour is`,
                                `dominant...`],
                            [`...so the intensity of the shades is informative:`,
                                `it's not enough to just count the number of blue`,
                                `vs. orange outcomes, you also have to consider`,
                                `how intensely blue or orange they are...`],
                            [`...and finally, an important rule:`,
                                ``,
                                `You cannot infer a bag's dominant colour`,
                                `from the colour of the other bag.`,
                                ``,
                                `Each bag is independent.`,
                                `Information about one bag does not tell you`,
                                `anything about the other bag.`]
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
                            document.createTextNode('There are a few things to keep in mind:'));
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
                        'to familiarise yourself with the flow of the task.']
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