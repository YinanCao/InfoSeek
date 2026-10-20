// import the question arrays
import questionnaires from './questionnaires.js'

const response_scale = (ques_type) => {
  if (ques_type ==="q_nfcs") {
      return ['Strongly disagree', 'Moderately disagree', 'Slightly disagree', 'Slightly agree', 'Moderately agree', 'Strongly agree']
  } else if (ques_type === "q_bfi") {
      return ['Disagree strongly', 'Disagree a little', 'Neutral; no opinion', 'Agree a little', 'Agree strongly']
  } else if (ques_type === "q_icar") {
      return {
        s1: ["2", "3", "4", "5", "6","7"],
        s2: ["Richard is taller than Matt", "Richard is shorter than Matt",  "Richard is as tall as Matt" ,"It is impossible to tell"],
        s3: ["25" ,"39", "44", "47" ,"53", "57"],
        s4 : ["Friday" ,"Monday", "Wednesday",  "Saturday" ,"Tuesday", "Sunday"],
        s5 : ["S" ,"T", "U",  "V" ,"W", "X"],
        s6 : ["E" ,"F", "G", "H" ,"I", "J"],
        s7 : ["T" ,"U", "V",  "X" ,"Y", "Z"],
        s8 : ["J" ,"H", "I", "N" ,"M", "L"],
        s9 : ["A" ,"B", "C", "D" ,"E", "F"],
        s10 : ["A" ,"B", "C", "D" , "E", "F","G","H"],
    }
  }
}

const q_start_indices = {
  q_nfcs: [0,42], // the second entry in array should be the number of items in the questionnaire (with catch included)
  q_bfi:  [0,61], // the second entry in array should be the number of items in the questionnaire (with catch included)
  q_icar: [0, 8, 12, 16],
};

export default function ques_stim(ques_type, subj, UID) {
  const questions = questionnaires()[ques_type];
  const jsPsychQuesType = () => {
    return (ques_type === 'q_icar' ? 'survey-multi-choice' : 'survey-likert')
  };
  const isHorizontal = () => {
    return (ques_type === 'q_icar' ? false : true)
  }
  const icarOptions = (i) => {
    // icar stuff
    if (i < 8) {
      return response_scale('q_icar')[`s${i+1}`]
    } if (i > 7 && i < 12) {
      return response_scale('q_icar').s9
    } else {
      return response_scale('q_icar').s10
    }
  }
  const labelExtras = (ques_type, i) => {
    if (ques_type === 'q_icar') {
      if (i < 8) {
        return '1'
      } if (i > 7 && i < 12) {
        return '2'
      } else {
        return '3'
      }
    } else {
      return ''
    }
  }

  const preamble = () => {
    if (ques_type === 'q_nfcs') {
      return '<strong>Read each of the following statements and decide how much you agree with each according to your beliefs and experiences.</strong>'
    } else if (ques_type === 'q_bfi') {
      return `<strong>Here are a number of characteristics that may or may not apply to you. <br>
      For example, do you agree that you are someone who likes to spend time with others? <br>
      Please rate each statement to indicate the extent to which you agree or disagree with that statement. </strong>`
    } else {
      return '<strong>Please read each question carefully and answer as best as you can.</strong>'
    }
  }

  let q_stims = [];
  let q_arr = [];
  for (let i = 0; i < questions.length+1; i++) {
    if (q_start_indices[ques_type].includes(i)) {
      if (i != 0) {
        q_stims.push({
          type: jsPsychQuesType(),
          questions: q_arr,
          horizontal: isHorizontal(),
          preamble: preamble(),
          data: { label: ques_type.slice(2)+labelExtras(ques_type, i-1) },
          on_finish: (data) => {
            push_respToServer(data.label, data.response, subj, UID);
          }
        })
      }
      q_arr = [];
    }

    // push individual questions items into array
    if (i != questions.length) {
      q_arr.push(
        {
          prompt: `${i+1}) ${questions[i]}`,
          options: icarOptions(i),
          labels: response_scale(ques_type),
          required: true
        }
      );
    }
  }
  
  return q_stims
}

function push_respToServer(label, resp, subj, UID) {
  return new Promise((resolve, reject) => {
    const dataPacket = {
      subj: subj,
      uid: UID,
      resps: JSON.stringify(resp),
      label: label,
    };
    // send to server
    $.ajax({
        url: '/post_questionnaire',
        type: 'POST',
        data: dataPacket
    }).done((successFlag) => {
        resolve(successFlag);
    }).fail((xhr, txt, err) => {
        console.log('FAIL post_questionnaire POST');
        console.log(err);
        resolve(false);
    });
  })
}