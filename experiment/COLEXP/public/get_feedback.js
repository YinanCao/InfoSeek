export default function get_feedback(uid) {

  window.part_fb_str = '';

  const part_feedback_instructions = {
    type: 'html-slider-response',
    stimulus: '<p>How well did you understand the instructions?</p>',
    labels: ['Did not understand at all', 'Understood fully'],
    min: 0,
    max: 10,
    require_movement: true,
    on_finish: (data) => {
      var data_str = 'I0:"' + data.response + '"; ';
      window.part_fb_str = window.part_fb_str.concat(data_str);
    }
  };

  const part_feedback_enjoy = {
    type: 'html-slider-response',
    stimulus: '<p>How much did you enjoy doing the experiment?</p>',
    labels: ['Not at all', 'Very much'],
    min: 0,
    max: 10,
    require_movement: true,
    on_finish: (data) => {
      const data_str = 'E0:"' + data.response + '"; ';
      window.part_fb_str = window.part_fb_str.concat(data_str);
    }
  };

  const part_feedback_general = {
    type: 'survey-text',
    questions: [{
      prompt: 'Please provide us with any other comments or critiques you have about the task.<br>' +
        'They are greatly appreciated and will help us build better experiments moving forward.<br><br>' +
        '<span style = font-style:italic">If you have no comments, you may leave this blank.</span>',
      rows: 10
    }],
    on_finish: (data) => {
      //data.response.Q0 is string
      const part_fb_gen_str = data.response.Q0;
      const post_data = {
        entry1: window.part_fb_str,
        entry2: part_fb_gen_str,
        uid: uid,
      };

      // send AJAX call to server
      $.ajax({
          url: '/post_fb',
          type: 'POST',
          data: post_data,
          //    success: function(response){console.log('SUCCESS response POST request!');},  //debug use
          error: function (error) {
            console.log(error);
          }
        })
        //  .done((successFlag) => { console.log('response POST successFlag: '+ successFlag); }) //debug use
        .fail((xhr, txt, err) => {
          console.log('FAIL post_resp POST');
          console.log(err);
        });
    }
  };

  return [part_feedback_instructions, part_feedback_enjoy, part_feedback_general]
}
