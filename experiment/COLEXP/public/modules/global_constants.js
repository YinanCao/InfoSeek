// global constants
export const constants = {
    nb_total        : 4,
    ns_total        : 16,
    minBreakDuration: 2000,
    outcomeDuration : 500,
    probeSelDuration: 300,
    probeFBDuration : 500,
    ITIDuration     : () => {
        // return 250
        return Math.floor(250*Math.random()) + 250   //DEBUG (between 250 and 500)
    },
    introDuration   : 1000,
    postInstDuration: 500,
    choiceSet       : ['f','j'],
    containerElement: () => { return document.getElementById('jspsych-content') }, 
    bagElement      : () => { return document.getElementById('bag') }, // reference to bag svg
    medalElement    : () => { return document.getElementById('medal') }, // reference to medal svg
    shapeElement    : (num) => { return document.getElementById(`shape${num}`) }, // references to shape svgs
    bagPixelSize    : '200px',
    medalPixelSize  : '250px',
    shapePixelSize  : '144px',
    colorMap        : ['#0080FF', '#2480DB', '#4980B6', '#6D8092','#92806D','#B68049','#DB8024','#FF8000'],
    colorDefault    : '#FFFFFF',
    medalColors     : [['#7E4F45','#CDA37E'],['#5E5E66','#C2C2C8'],['#9D8D5D','#EDDC7F']], // outer, inner (bronze,silver,gold)
    get reverseIndex() { 
        return Array.from(Array(this.colorMap.length).keys()).map(x => x + 1).reverse()
    },
    get isBlue() { // index of pure orange, pure blue
        return [this.colorMap.length, 1]
    }, 
    // images used in the tutorials stimuli
    inst_imgs       : Array.from([...Array(13).keys()].map(x => `img/instructions/picture${x+1}.png`)),
    // gifs to replace the SVG image presentation
    bag_gif         : Array.from([...Array(2).keys()].map(x => `img/shapes/bag_${x+1}.gif`)),
    blankShape_gif  : Array.from([...Array(8).keys()].map(x => `img/shapes/shape_0${x+1}_blank.gif`)),
    blueShape_gif   : Array.from([...Array(8).keys()].map(x => `img/shapes/shape_0${x+1}_blue.gif`)),
    orangeShape_gif : Array.from([...Array(8).keys()].map(x => `img/shapes/shape_0${x+1}_orange.gif`)),
    shape_gif       : Array.from([...(Array(8).keys())].map( // 8 shapes
                        x => Array.from([...Array(8).keys()].map(y => `img/shapes/shape_0${x+1}_0${y+1}.gif`)) // colors
                    )),
    blank_gif       : 'img/shapes/shape_00.gif',
    medal_gif       : Array.from([...Array(3).keys()].map(x => `img/medal_${x+1}.gif`)),
    // tutorial indices
    shapesTutDraw   : [1,6],
    sidesTutDraw    : [0,0,1,0,0,1,1,1,0,1],
    colorsTutDraw   : [[8,5,6,4,7,5,6,7,8,3],[1,4,3,5,2,4,3,2,1,6]],
    shapesTutDisc   : [5,8],
    sidesTutDisc    : [0,0,1,1,1,0,0,1,1,0],
    colorsTutDisc   : [[1,3,6,1,3,5,2,3,4,1],[8,6,3,8,6,4,7,6,5,8]],
}