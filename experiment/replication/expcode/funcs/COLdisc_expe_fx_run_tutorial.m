function COLdisc_expe_fx_run_tutorial(debugging, french)

    isubuntu = 0;
    if isunix && ~ismac % detect if linux computer
        isubuntu = 1;
    elseif ismac
        addpath(genpath('/Applications/Psychtoolbox'))
    end
    %% Video settings
    video.synchflip            = true;
    video.mouseON              = false;
    video.eyelink.inputphys_mm = [531 299]; % BenQXL2420T (1920*1080,531mm*299mm)
    video.eyelink.inputdist_mm = 600;
    D_cm                       = video.eyelink.inputdist_mm/10;
    video.screenwdth_cm        = video.eyelink.inputphys_mm(1)/10;
    video.screenwdth_px        = 1920;
    video.ppd                  = round(tand(1)*(D_cm)/video.screenwdth_cm*video.screenwdth_px);
    %% Stimulus parameters: 
    shape_sz_deg            = 2;
    video.shape_sz          = shape_sz_deg*video.ppd;
    video.shape_offset      = 1.5*video.ppd; % shape offset
    video.respbutton_offset = shape_sz_deg*1.5*video.ppd; % response button offset
    video.rep_sz            = shape_sz_deg*video.ppd * 5/6;
    video.bag_sz            = shape_sz_deg*video.ppd * 6;
    video.bag_offset        = video.bag_sz * 0.5;
    video.fb_sz             = shape_sz_deg*video.ppd; % selection square size
    video.cup_sz            = shape_sz_deg*video.ppd;
    % Color parameters:
    black                   = [0,0,0];
    video.lbgd              = 0.3950; %128/255; % background color (Clemence used 0.3950)
    colrfg                  = COLdisc_cielab(); % cielab orange and blue
    orange                  = colrfg(1,:); % [1,0.5,0];
    blue                    = colrfg(2,:); % [0,0.5,1];
    grayfixt                = applycform([65,0,0],makecform('lab2srgb'));
    % photodiodeSq            = [0,0,50,50];
    %% Stimulus timing:
    highlightDur = 0.1;
    outcomeDur   = 0.5;
    itiDur       = 1.0;
    delay_ul     = [0.5,1.0];
    baselineDur  = 5;
    %%
    video.highlightDur = highlightDur;
    video.outcomeDur   = outcomeDur;
    video.itiDur       = itiDur;
    video.baselineDur  = baselineDur;
    %% Create PTB screen
    Screen('CloseAll')
    PsychDefaultSetup(1);
    video.screen = max(Screen('Screens'));
    %%% set synch properties:
    if video.synchflip && isubuntu
        % set screen synchronization properties -- workaround Valentin for PC
        % see 'help SyncTrouble',
        %     'help BeampositionQueries' or
        %     'help ConserveVRAMSettings' for more information
        Screen('Preference','VisualDebuglevel',3); % no PTB purple screen
        Screen('Preference','SyncTestSettings',[],[],0.2,10); % soften synchronization test requirements
        Screen('Preference','ConserveVRAM',bitor(4096,Screen('Preference','ConserveVRAM'))); 
        % enforce beamposition workaround for missing VBL interval
        fprintf('Synching flips with softer requirements...\n');
    elseif ~video.synchflip || ismac
        % skip synchronization tests altogether
        % //!\\ force skipping tests, PTB wont work = timing inaccurate
        Screen('Preference','SkipSyncTests',2); % assumes 60Hz etc..
        Screen('Preference','VisualDebuglevel',0);
        Screen('Preference','SuppressAllWarnings',1);
        fprintf('||| SYNCHFLIP OFF or running on OSX => TIMINGS WILL BE INACCURATE ! |||\n')
    end
    
    %%% open main window:
    PsychImaging('PrepareConfiguration');
    PsychImaging('AddTask','General','UseFastOffscreenWindows');
    PsychImaging('AddTask','General','NormalizedHighresColorRange');
    video.res = Screen('Resolution',video.screen);
    if debugging
        smallWindow4Debug = [0 0 1920 1080] / 1.2;
    else
        smallWindow4Debug = [];
    end
    [video.window, video.windowRect] = PsychImaging('OpenWindow', video.screen, video.lbgd, smallWindow4Debug);
    fprintf('passed OpenWindow !\n')
    
    [video.screenXpixels, video.screenYpixels] = Screen('WindowSize', video.window);
    [video.xCenter, video.yCenter] = RectCenter(video.windowRect);
    Screen('BlendFunction', video.window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');%smooth blending/antialiasing
    video.blend = '''GL_SRC_ALPHA'', ''GL_ONE_MINUS_SRC_ALPHA''';
    video.colorrange = 1;
    Screen('ColorRange', video.window, video.colorrange);
    % 1 = to pass color values in OpenGL's native floating point color range of 0.0 to
    % 1.0: This has two advantages: First, your color values are independent of
    % display device depth, i.e. no need to rewrite your code when running it on
    % higher resolution hardware. Second, PTB can skip any color range remapping
    % operations - this can speed up drawing significantly in some cases.   ...???
    video.textsize = 50;
    Screen('TextSize', video.window, video.textsize);
    video.ifi = Screen('GetFlipInterval', video.window);
    video.priority = Priority(MaxPriority(video.window));
    vbl = Screen('Flip', video.window); % first flip
    nextfliptime = vbl+fx_roundfp(0.01,0,video.ifi); % wait 10ms
    
    %% Make textures:
    floatprecision = 1;
    % symbols textures
    shape_tex = zeros(2,8); % shape_tex(1,i)=black (contour) shape_tex(2,i)=grey (inside)
    for sh = 1:8
        outline         = double(imread(sprintf('./img/shape%dc.png',sh)))/255;
        outline         = imresize(outline,video.shape_sz/size(outline,1));
        shape_tex(1,sh) = Screen('MakeTexture',video.window,cat(3,ones(size(outline)),outline),[],[],floatprecision);
        inside          = double(imread(sprintf('./img/shape%d.png',sh)))/255;
        inside          = imresize(inside,video.shape_sz/size(inside,1));
        shape_tex(2,sh) = Screen('MakeTexture',video.window,cat(3,ones(size(inside)),inside),[],[],floatprecision);
    end
    positions(1,:)  = CenterRectOnPoint(Screen('Rect',shape_tex(1)),video.xCenter-video.shape_offset,video.yCenter);
    positions(2,:)  = CenterRectOnPoint(Screen('Rect',shape_tex(1)),video.xCenter+video.shape_offset,video.yCenter);
    centerpos       = CenterRectOnPoint(Screen('Rect',shape_tex(1)),video.xCenter,video.yCenter);
    % resp buttons textures:
    outrep = double(imread('./img/bagout.png'))/255;
    outrep = imresize(outrep,video.rep_sz/size(outrep,1));
    inrep  = double(imread('./img/bagin.png'))/255;
    inrep  = imresize(inrep,video.rep_sz/size(inrep,1));
    rep_tex(1,1) = Screen('MakeTexture',video.window,cat(3,ones(size(outrep)),outrep),[],[],floatprecision);
    rep_tex(2,1) = Screen('MakeTexture',video.window,cat(3,ones(size(inrep)),inrep),[],[],floatprecision);
    rep_tex(1,2) = Screen('MakeTexture',video.window,cat(3,ones(size(outrep)),flip(outrep,2)),[],[],floatprecision);
    rep_tex(2,2) = Screen('MakeTexture',video.window,cat(3,ones(size(inrep)),flip(inrep,2)),[],[],floatprecision);
    rep_pos(1,:) = CenterRectOnPoint(Screen('Rect',rep_tex(1)),video.xCenter-video.respbutton_offset,video.screenYpixels*0.50);
    rep_pos(2,:) = CenterRectOnPoint(Screen('Rect',rep_tex(1)),video.xCenter+video.respbutton_offset,video.screenYpixels*0.50);

    outbag = double(imread('./img/bagout.png'))/255;
    outbag = imresize(outbag,video.bag_sz/size(outbag,1));
    inbag  = double(imread('./img/bagin.png'))/255;
    inbag  = imresize(inbag,video.bag_sz/size(inbag,1));
    bag_tex(1,1) = Screen('MakeTexture',video.window,cat(3,ones(size(outbag)),outbag),[],[],floatprecision);
    bag_tex(2,1) = Screen('MakeTexture',video.window,cat(3,ones(size(inbag)),inbag),[],[],floatprecision);
    bag_tex(1,2) = Screen('MakeTexture',video.window,cat(3,ones(size(outbag)),flip(outbag,2)),[],[],floatprecision);
    bag_tex(2,2) = Screen('MakeTexture',video.window,cat(3,ones(size(inbag)),flip(inbag,2)),[],[],floatprecision);
    bag_pos(1,:) = CenterRectOnPoint(Screen('Rect',bag_tex(1)),video.xCenter-video.bag_offset,video.yCenter);
    bag_pos(2,:) = CenterRectOnPoint(Screen('Rect',bag_tex(1)),video.xCenter+video.bag_offset,video.yCenter);

    buttonbuffer        = 0.3*size(outrep,1);
    selsize             = [0 0 1.25*size(outrep,2)+buttonbuffer size(outrep,1)+buttonbuffer];
    selection_rect(1,:) = CenterRectOnPoint(selsize,video.xCenter-video.respbutton_offset,video.screenYpixels*0.50);
    selection_rect(2,:) = CenterRectOnPoint(selsize,video.xCenter+video.respbutton_offset,video.screenYpixels*0.50);
    % score feedback: cup textures
    cupi          = imread('./img/cupimg.png');
    cupi          = imresize(cupi,video.shape_sz/size(cupi,1));
    cuptext       = Screen('MakeTexture',video.window,cupi);
    cuppos(1,:)   = CenterRectOnPoint(Screen('Rect',cuptext),video.xCenter-(video.shape_sz),video.yCenter);
    cuppos(2,:)   = CenterRectOnPoint(Screen('Rect',cuptext),video.xCenter,video.yCenter);
    cuppos(3,:)   = CenterRectOnPoint(Screen('Rect',cuptext),video.xCenter+(video.shape_sz),video.yCenter);
    buffer        = 0.3*size(cupi,2);
    cupframe      = [0 0 3*size(cupi,2)+buffer size(cupi,1)+buffer];
    cupframe_rect = CenterRectOnPoint(cupframe, video.xCenter,video.yCenter); 
    %% fixation
    video.Fixation_dot_deg     = 0.15;
    video.Fixation_cross_h_deg = video.Fixation_dot_deg;
    video.Fixation_cross_w_deg = video.Fixation_dot_deg*3.5;
    video.Fixation_dot_pix     = round(video.ppd*video.Fixation_dot_deg);
    video.Fixation_cross_h_pix = round(video.ppd*video.Fixation_cross_h_deg);
    video.Fixation_cross_w_pix = round(video.ppd*video.Fixation_cross_w_deg);
    fixCrossDimPix             = round(video.ppd*(video.Fixation_cross_w_deg/2));%12 pix
    lineWidthPix               = round(video.ppd*video.Fixation_dot_deg);%6 pix
    video.fix_rect             = [-fixCrossDimPix -lineWidthPix./2 fixCrossDimPix lineWidthPix./2];
    %%
    disc_innerDim              = video.Fixation_cross_w_deg * 1.5;
    disc_outerDim              = 5.5;
    video.disc_outerDim        = disc_outerDim;
    video.disc_innerDim        = disc_innerDim;
    %% create card frame texture
    cfg               = [];
    cfg.ppd           = video.ppd;
    cfg.disc_outerDim = disc_outerDim;
    cfg.disc_innerDim = disc_innerDim;
    cfg.lbgd          = video.lbgd;
    cfg.cardtype      = 0; % empty frame
    img               = make_card_fix(cfg);
    framtex           = Screen('MakeTexture',video.window,img,[],[],floatprecision);
    cardrec           = CenterRectOnPoint(Screen('Rect',framtex),video.xCenter,video.yCenter);
    % get cardrect for later use
    %%
    if ~debugging
        HideCursor;
        FlushEvents;
        ListenChar(2);
    end
    %% Init keys:
    clear PsychHID; % Force new enumeration of devices.
    clear KbCheck;
    KbName('UnifyKeyNames'); % across OSs
    GetKeyboardIndices();
    escapeKey   = KbName('ESCAPE'); %experimenter keys (native Kb)
    continueKey = KbName('y');
    spaceKey    = KbName('space'); %participant keys (numpad)
    if isubuntu,  leftKey = KbName('a');
    elseif ismac, leftKey = KbName('q');
    end
    rightKey    = KbName('p');
    respKeys    = [leftKey, rightKey];% left=1 right=2
    expeKeys    = [escapeKey, continueKey, leftKey, rightKey, spaceKey];
    allKeys     = [];
    RestrictKeysForKbCheck(allKeys);
    %% generate tutorial squences
    nsamples = 7;
    kappa = 5;
    theta = get_theta(kappa, nsamples);
    tutorialsqc(1).symbols = [5, 6];
    tutorialsqc(1).targetsymbol = 5; %star
    tutorialsqc(1).othersymbol = 6; %cross
    tutorialsqc(1).symbolsides = [1 1 1 1 2 2 2];
    tutorialsqc(1).theta.target = mod(theta,pi);
    tutorialsqc(1).theta.other = mod(theta+pi/2, pi);
    tutorialsqc(1).targetcolor = 1;
    tutorialsqc(1).condition = 2;

    % kappa = 1.5
    theta = [0.0057, 0.1257, 2.1917, 2.8992, 0.3018, 2.9378, 0.8426];
    tutorialsqc(2).symbols = [8, 7];
    tutorialsqc(2).targetsymbol = 8; %moon
    tutorialsqc(2).othersymbol = 7; %square
    tutorialsqc(2).symbolsides = [1 2 1 1 1 2 2];
    tutorialsqc(2).theta.target = mod(theta+pi/2, pi);
    tutorialsqc(2).theta.other = mod(theta, pi);
    tutorialsqc(2).targetcolor = 1;
    tutorialsqc(2).condition = 1;

    theta = [0.1257, 0.0057, 2.1917, 0.8426, 0.3018, 2.9378, 2.8992];
    tutorialsqc(3).symbols = [1, 6];
    tutorialsqc(3).targetsymbol = 1; %circle
    tutorialsqc(3).othersymbol = 6; %cross
    tutorialsqc(3).symbolsides = [1 1 1 2 2 1 2];
    tutorialsqc(3).theta.target = mod(theta,pi);
    tutorialsqc(3).theta.other = mod(theta+pi/2, pi);
    tutorialsqc(3).targetcolor = 1;
    tutorialsqc(3).condition = 2;

    theta = [0.1954, 2.2717, 0.1086, 3.0954, 2.8639, 1.0007, 0.0149];
    tutorialsqc(4).symbols = [4, 2];
    tutorialsqc(4).targetsymbol = 4; %penta
    tutorialsqc(4).othersymbol = 2; %triangle
    tutorialsqc(4).symbolsides = [2 2 1 1 2 1 1];
    tutorialsqc(4).theta.target = mod(theta,pi);
    tutorialsqc(4).theta.other = mod(theta+pi/2, pi);
    tutorialsqc(4).targetcolor = 2;
    tutorialsqc(4).condition = 1;
    %% instruction page lines

    line = 'In each sequence, you will be playing with a pair of symbols,\nfor example here the cross and the star: \n\n';
    line_start{1} = line;

    top1 = 'At the beginning of each sequence, the computer decides on one of two rules.\n';
    top2 = 'The first rule: choose the symbol that most likely comes from a specific bag:\n (e.g., the *blue* bag in this sequence).';
    line_start{2} = [top1, top2];

    top1 = 'The second rule: guess the color of the bag each symbol comes from.\n';
    top2 = [char(34) 'Blue or Orange?' char(34), '\n\n'];
    top3 = 'You can freely choose, and will be tested at the end of the sequence.';
    line_start{3} = [top1, top2, top3];

    top1 = 'In the last sequence of this tutorial,\n';
    top2 = 'choose the symbol most likely drawn from the *orange* bag.';
    line_start{4} = [top1, top2];

    if french
    line = sprintf('Pour chaque s%cquence, vous allez jouer avec une paire de symboles,\npar exemple ici la croix et l''%ctoile: \n\n',233,233);
    line_start{1} = line;

    top1 = sprintf('Au d%cbut de chaque s%cquence, l''ordinateur choisi une r%cgle parmi deux.\n\n',233,233,232);
    top2 = sprintf('La premi%cre r%cgle: Choisi le symbol qui a le plus de probabilit%c \nde provenir d''un sac sp%ccifique (e.g., le sac *bleu* dans cette s%cquence).',232,232,233,233,233);
    line_start{2} = [top1, top2];

    top1 = sprintf('La deuxi%cme r%cgle: devine la couleur du sac dont provient chaque symbol.\n',232,232);
    top2 = [char(34) 'Bleu ou Orange ?' char(34), '\n\n'];
    top3 = sprintf('Tu peux choisir librement, et tu seras test%c %c la fin de la s%cquence.',233,224,233);
    line_start{3} = [top1, top2, top3];

    top1 = sprintf('Dans la derni%cre s%cquence de ce tutorial,\n',232,233);
    top2 = sprintf('choisi le symbol qui a la probabilit%c la plus %clev%ce de provenir du sac *orange*.',233,233,233);
    line_start{4} = [top1, top2];
    end

    %%
    for iseq = 1:4
    %% START of sequence
    % make card textures
    shift             = pi/4;
    cfg               = [];
    cfg.ppd           = video.ppd;
    cfg.disc_outerDim = disc_outerDim;
    cfg.disc_innerDim = disc_innerDim;
    cfg.lbgd          = video.lbgd;
    cfg.axis          = -pi/4 + shift; % orange=0,blue=pi/2,if shift=0

    cardtex           = cell(1,2);
    rgb               = cell(0);
    cfg.cardtype      = 1;
    img               = make_card_fix(cfg);
    cardtex{1}        = Screen('MakeTexture',video.window,img,[],[],floatprecision);
    cardtex{2}        = zeros(nsamples,1);
    for i = 1:nsamples
        cfg.cardtype    = 3;
        cfg.angl        = tutorialsqc(iseq).theta.target(i) + shift;
        [img,rgbval]    = make_card_fix(cfg);
        cardtex{2}(i,1) = Screen('MakeTexture',video.window,img,[],[],floatprecision); % target
        rgb{1}(i,:)     = rgbval;

        cfg.angl        = tutorialsqc(iseq).theta.other(i) + shift;
        [img,rgbval]    = make_card_fix(cfg);
        cardtex{2}(i,2) = Screen('MakeTexture',video.window,img,[],[],floatprecision); % other
        rgb{2}(i,:)     = rgbval;
    end
    targetsymbol = tutorialsqc(iseq).targetsymbol; % = 5 = star
    othersymbol = tutorialsqc(iseq).othersymbol; % = 6 = cross
    %% openning word for seq 4: orange target
    if iseq==4
        top1 = 'During the real experiment, color is only indicated by the black line,\n';
        top2 = 'In addition, we will be recording your pupil size, so:\n';
        top3 = '(1) please do not move your head: rest it on the chinrest,\n';
        top4 = '(2) please do not move your eyes: stay on the central fixation,\n';
        top5 = '    symbols are close enough to see everything while fixating the center,\n';
        top6 = '(3) please do not blink too much:\n  if necessary, do so after each trial when the visual stimuli are gone.\n';
        spaceline = 'Press [space] to start.';
        if french
        top1 = sprintf('Lors de l''exp%crience r%celle, la couleur n''est indiqu%ce que par la barre noire.,\n',233,233,233);
        top2 = 'De plus, nous enregistrerons la taille de vos pupilles., donc:\n';
        top3 = sprintf('(1) ne bougez pas la t%cte : posez-la sur la mentonnière,\n',234);
        top4 = '(2) ne bougez pas les yeux : restez sur la fixation centrale,\n';
        top5 = '    les symboles sont suffisamment proches pour tout voir tout en fixant le centre,\n';
        top6 = sprintf('(3) ne pas trop cligner des yeux:\nsi n%ccessaire, le faire une fois les stimuli enlev%cs\n',233,233);
        spaceline = 'Appuie sur [espace] pour commencer.';
        end
        line = [top1, top2, top3, top4, top5, top6];
        DrawFormattedText(video.window, line, 'center', video.screenYpixels * 0.20, black);
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
        Screen('Flip', video.window);
        WaitKeyPress(spaceKey);
        Screen('Flip', video.window);
        WaitSecs(0.5);
    end
    %% general instruction per sequence
    DrawFormattedText(video.window, line_start{iseq}, 'center', video.screenYpixels * 0.20, black);
    spaceline = 'Press [space] to start.';
    if french
        spaceline = 'Appuie sur [espace] pour commencer.';
    end
    DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
    Screen('DrawTexture',video.window,cardtex{1},[],cardrec);
    show_fix;
    % Draw sampling alternatives: draw "target" on "symbolside"
    targetside = tutorialsqc(iseq).symbolsides(1);
    otherside  = 3 - targetside;
    Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
    Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], positions(targetside,:), 0, [], [], video.lbgd);
    Screen('DrawTexture', video.window, shape_tex(1,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
    Screen('DrawTexture', video.window, shape_tex(2,othersymbol), [], positions(otherside,:) , 0, [], [], video.lbgd);
    Screen('DrawingFinished', video.window);
    Screen('Flip', video.window);
    WaitKeyPress(spaceKey);
    Screen('Flip', video.window);
    WaitSecs(1);
    %% Reminder for seq 2: draw blue
    if iseq==2
        %%% warning screen:
        top = '/ WATCH OUT \\n\n\nEven if a bag contains mostly blue, it can sometimes have orange…\n';
        if french
        top = sprintf('ATTENTION ! \n\n\nM%cme si un sac contient du bleu majoritairement,\nil peut parfois contenir du orange...\n',234);
        end
        DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.15, black);
        spaceline = 'Press [space] to start.';
        if french
            spaceline = 'Appuie sur [espace] pour commencer.';
        end
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
        Screen('Flip', video.window);
        WaitKeyPress(spaceKey);
    end
    %% Reminder for seq 3: guess (free sampling)
    if iseq==3
        attention = '/ WATCH OUT \ \n\n';
        l1 = '(1) Two symbols in a given sequence:\n';
        opt1 = ' - can both come from blue bags,\n';
        opt2 = ' - can both come from orange bags,\n';
        opt3 = ' - or one blue and the other orange !\n';
        l2 = 'It is not possible to guess the color of one from the other:)\n\n\n\n';
        l3 = '(2) Symbols can also change colors *between* sequences:\n';
        l4 = 'so the moon can come from orange bag in one sequence, \nthen from blue bag in another sequence.\n';
        l5 = 'Every sequence is new:)';
        if french
        attention = 'ATTENTION ! \n\n';
        l1 = sprintf('(1) Deux symbols dans une s%cquence donn%cee:\n',233,233);
        opt1 = ' - peuvent provenir tous les deux de sacs bleus,\n';
        opt2 = ' - peuvent provenir tous les deux de sacs oranges,\n';
        opt3 = ' - ou un bleu et l''autre orange !\n';
        l2 = sprintf('Ce n''est pas possible de deviner la couleur de l''un %c partir de l''autre:)\n\n\n\n',224);
        l3 = sprintf('(2) Les symbols peuvent aussi changer de couleur entre les s%cquences:\n',233);
        l4 = sprintf('donc la lune peut venir du sac orange dans une s%cquence, \net ensuite du bleu dans une autre.\n',233);
        l5 = sprintf('Chaque s%cquence est nouvelle :)',233);
        end
        DrawFormattedText(video.window, [attention l1 opt1 opt2 opt3 l2], 'center', video.screenYpixels * 0.20, black);
        DrawFormattedText(video.window, [l3 l4 l5], 'center', video.screenYpixels * 0.7, black);
        spaceline = 'Press [space] to start.';
        if french
        spaceline = 'Appuie sur [espace] pour commencer.';
        end
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
        Screen('Flip', video.window);
        WaitKeyPress(spaceKey);
    end
    %% Two bags, illustrating colored symbols
    if iseq == 1

        line = 'Each symbol may come from an orange bag with mostly orange symbols,\nor a blue bag with mostly blue symbols.';
        if french
        line = 'Chaque symbol peut provenir d''un sac orange avec principalement \ndes symbols oranges, ou d''un sac bleu avec principalement des symbols bleus.';
        end
        DrawFormattedText(video.window, line, 'center', video.screenYpixels * 0.15, black);
        spaceline = 'Press [space] to continue.';
        if french
            spaceline = 'Appuie sur [espace] pour continuer.';
        end
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
        
        Screen('DrawTexture', video.window, bag_tex(1,1), [], bag_pos(1,:), 0, [], [], orange);
        Screen('DrawTexture', video.window, bag_tex(1,2), [], bag_pos(2,:), 0, [], [], blue);
        texty = video.screenYpixels*0.35;
        DrawFormattedText(video.window, '?', video.xCenter-50-video.textsize/4, texty, orange);
        DrawFormattedText(video.window, '?', video.xCenter+50-video.textsize/4, texty, blue);
        dstRect = CenterRectOnPoint(Screen('Rect',shape_tex(2,targetsymbol)),video.xCenter,texty);
        Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], dstRect, 0, [], [], [0,0,0]);
        Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], dstRect, 0, [], [], video.lbgd);
        grayImg = im2gray(inbag);
        bwImg = imbinarize(grayImg); % Binarize the image
        % Detect connected clusters
        cc = bwconncomp(bwImg);
        stats = regionprops(cc, 'PixelList');
        coords = stats(1).PixelList;
        center(1) = round(size(bwImg,2)/2);
        center(2) = round(size(bwImg,1)/2);
        coords(:,1) = coords(:,1) - center(1);
        coords(:,2) = coords(:,2) - center(2);
        % Extract boundary points
        X_boundary = coords(:,1);
        Y_boundary = coords(:,2);
        d = round(video.shape_sz/1.5);
        x_minmax = prctile(coords(:,1),[0,100]);
        y_minmax = prctile(coords(:,2),[0,100]);
        [X,Y] = meshgrid(x_minmax(1):d:x_minmax(2),y_minmax(1):d:y_minmax(2));
        X_flat = X(:) + round(randn(size(X(:)))*5); % jitter a bit
        Y_flat = Y(:) + round(randn(size(Y(:)))*5);
        % Use inpolygon to check if points are inside the boundary
        inside_idx = inpolygon(X_flat, Y_flat, X_boundary, Y_boundary);
        N = length(inside_idx);
        theta             = get_theta(0.5, N);
        shift             = 0;
        cfg               = [];
        cfg.ppd           = video.ppd;
        cfg.disc_outerDim = disc_outerDim;
        cfg.disc_innerDim = disc_innerDim;
        cfg.lbgd          = video.lbgd;
        cfg.axis          = -pi/4 + shift; % orange=0,blue=pi/2,if shift=0
        cfg.cardtype      = 3;
        rgbval = cell(0);
        for i = 1:N
            cfg.angl = theta(i) + shift;
            [~,rgbval{1}(i,:)] = make_card_fix(cfg);
            cfg.angl = theta(i) + shift + pi/2;
            [~,rgbval{2}(i,:)] = make_card_fix(cfg);
        end
        off_sign = [-1, 1];
        for side = 1:2
            xy = [X_flat(inside_idx)+video.bag_offset*off_sign(side)+video.xCenter, Y_flat(inside_idx)+video.yCenter];
            for i = 1:size(xy,1)
                dstRect = CenterRectOnPoint(Screen('Rect',shape_tex(2,targetsymbol)),xy(i,1),xy(i,2));
                Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], dstRect, 0, [], [], [0,0,0]);
                Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], dstRect, 0, [], [], rgbval{side}(i,:));
            end
        end
        Screen('Flip', video.window);
        WaitKeyPress(spaceKey);
    end
    %%
    choices = nan(1,nsamples);
    rt      = nan(1,nsamples);
    condition = tutorialsqc(iseq).condition;
    targetcolor = tutorialsqc(iseq).targetcolor;
    if      targetcolor == 1; colorrgb = blue;
    elseif  targetcolor == 2; colorrgb = orange;
    end

    for ismp = 1:nsamples
        RestrictKeysForKbCheck(expeKeys);
        %% fixation only
        show_fix;
        fixcolor = {colorrgb; grayfixt};
        if iseq == 4
        Screen('FillOval',video.window,fixcolor{condition},CenterRectOnPointd([0 0 lineWidthPix lineWidthPix],video.xCenter,video.yCenter));
        end
        vbl = Screen('Flip', video.window, nextfliptime);
        nextfliptime = vbl + fx_roundfp(0.25,0,video.ifi);
        %% fixation + empty disc
        Screen('DrawTexture',video.window,cardtex{1},[],cardrec);
        show_fix;
        vbl_fixON = Screen('Flip', video.window, nextfliptime);
        %% fixation delay
        delay = delay_ul(1) + diff(delay_ul)*rand;
        nextfliptime = vbl_fixON + fx_roundfp(delay,0,video.ifi);
        %%
        Screen('DrawTexture',video.window,cardtex{1},[],cardrec);
        show_fix;
        targetside = tutorialsqc(iseq).symbolsides(ismp);
        otherside  = 3 - targetside;
        Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
        Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], positions(targetside,:), 0, [], [], video.lbgd);
        Screen('DrawTexture', video.window, shape_tex(1,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
        Screen('DrawTexture', video.window, shape_tex(2,othersymbol), [], positions(otherside,:) , 0, [], [], video.lbgd);
        if iseq==1 && ismp==1
            top = 'On each trial, choose a symbol with the [a] and [p] keys:';
            if french
            top = 'A chaque essai, choisi un symbol avec les touches [a] et [p]:';
            end
        else
            top = 'Choose a symbol with the [a] and [p] keys:';
            if french
            top = 'Choisi un symbol avec les touches [a] et [p]:';
            end
        end
        if iseq<4
            DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.3, black);
            DrawFormattedText(video.window, '[a]               [p]', 'center', video.screenYpixels * 0.55, [1,1,1]);
        end
        if iseq==1 && ismp==5
            warning = '/ WATCH OUT \: the symbols can switch sides !';
            if french
                warning = sprintf('ATTENTION !: les symbols peuvent changer de c%ctés !',244);
            end
            DrawFormattedText(video.window, warning, 'center', video.screenYpixels * 0.2, [1,1,1]);
        end
        vbl_shapes = Screen('Flip', video.window, nextfliptime);
        %% Get sampling choice:
        while true
            % Manual mode: wait for actual user input
            [keyIsDown, secs, keylist] = KbCheck();
            if keyIsDown && sum(keylist) == 1 && (keylist(leftKey) == 1 || keylist(rightKey) == 1)
                choice = find(respKeys == (find(keylist==1)));
                rt(ismp) = secs - vbl_shapes;
                break
            end
        end % while awaiting for resp
        nextfliptime = secs + fx_roundfp(0,0,video.ifi);
        %% Choice highlight:
        Screen('DrawTexture',video.window,cardtex{1},[],cardrec);
        show_fix;
        if choice == targetside
            Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(1,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(2,othersymbol), [], positions(otherside,:) , 0, [], [], video.lbgd);
            choices(ismp) = 1; % choice of shape
        elseif choice == otherside
            Screen('DrawTexture', video.window, shape_tex(1,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(2,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], positions(targetside,:), 0, [], [], video.lbgd);
            choices(ismp) = 2;
        end
        vbl_highlight = Screen('Flip', video.window, nextfliptime);
        nextfliptime = vbl_highlight + fx_roundfp(highlightDur,0,video.ifi);
        %% Choice highlight off (only fix + empty disc)
        Screen('DrawTexture',video.window,cardtex{1},[],cardrec);
        show_fix;
        vbl_highlightOFF = Screen('Flip', video.window, nextfliptime);
        %% Outcome delay: delay_ul = [0.5, 1]
        delay = delay_ul(1) + diff(delay_ul)*rand;
        nextfliptime = vbl_highlightOFF + fx_roundfp(delay,0,video.ifi);
        %% Outcome on:
        Screen('DrawTexture',video.window,cardtex{2}(ismp,choices(ismp)),[],cardrec);
        show_fix;
        if iseq<4
            if choice == targetside
                samplecolor = rgb{1}(ismp,:);
                Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
                Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], positions(targetside,:), 0, [], [], samplecolor);
            elseif choice == otherside
                samplecolor = rgb{2}(ismp,:);
                Screen('DrawTexture', video.window, shape_tex(1,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
                Screen('DrawTexture', video.window, shape_tex(2,othersymbol), [], positions(otherside,:) , 0, [], [], samplecolor);
            end
            if iseq==1 && ismp==1
            top = 'The computer reveals the color of chosen symbol:';
            if french
            top = sprintf('L''ordinateur r%cv%cle la couleur du symbol choisi:',233,232);
            end
            DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.3, black);
            end
        end
        if iseq==1 && ismp==1
            top = 'The symbol color is indicated by the angle of the black line\n relative to the colored background.\n';
            if french
            top = sprintf ('La couleur des symbols est indiquée par l''angle de la barre noire\nrelativement %c la couleur du fond.\n',224);
            end
            DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.75, [1,1,1]);
            spaceline = 'Press [space] to continue.';
            if french
            spaceline = 'Appuie sur [espace] pour continuer.';
            end
            DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
        end
        vbl_outcome = Screen('Flip', video.window, nextfliptime);
        if iseq==1
            outcomeDur = 1;
        else
            outcomeDur = 0.5;
        end
        nextfliptime = vbl_outcome + fx_roundfp(outcomeDur,0,video.ifi);
        if iseq==1 && ismp==1
            WaitKeyPress(spaceKey);
        end
        %% Outcome off:
        show_fix;
        vbl = Screen('Flip', video.window, nextfliptime);
        nextfliptime = vbl + fx_roundfp(itiDur,0,video.ifi); % for next trial
    end % END of sequence
    %% Guess condition: seq==3
    % looping over 2 shapes probe questions:
    if iseq==3

        respprobe_2q = nan(1,2);
        rtprobe_2q   = nan(1,2);
        bagcolor     = nan(1,2);
        bagcolor_2q  = cell(0);
        respprobe_chosencolor_2q = nan(1,2);

        tutorialsqc(3).probeside_shape1 = 1;
        tutorialsqc(3).probeside_shape2 = 2;
        tutorialsqc(3).counterfness = 3;
        tutorialsqc(3).targetcolor = 2;
        tutorialsqc(3).probe_target_1st = 1;

        probeside = [tutorialsqc(iseq).probeside_shape1
                     tutorialsqc(iseq).probeside_shape2];
        switch tutorialsqc(iseq).counterfness
            case 1
             target_latent_color = tutorialsqc(iseq).targetcolor;
             other_latent_color  = tutorialsqc(iseq).targetcolor;
            case 2
             target_latent_color = 3-tutorialsqc(iseq).targetcolor;
             other_latent_color  = 3-tutorialsqc(iseq).targetcolor;
            case 3
             target_latent_color = tutorialsqc(iseq).targetcolor;
             other_latent_color  = 3-tutorialsqc(iseq).targetcolor;
        end
        if tutorialsqc(iseq).probe_target_1st
            probesymbol = [targetsymbol,othersymbol];
            probecolor  = [target_latent_color,other_latent_color]; % true answer
        else
            probesymbol = [othersymbol,targetsymbol];
            probecolor  = [other_latent_color,target_latent_color];
        end

        for probe_q = 1:2 % probe both shapes

            % order random, pre-determined when generating seq
            % color buttons
            bluebuttonside = probeside(probe_q);% this is the side of the blue bag
            redbuttonside  = 3-bluebuttonside;

            if bluebuttonside==1
                bagcolor = [1,2]; % 1:blue, 2:orange
            elseif bluebuttonside==2
                bagcolor = [2,1];
            end
            % bagcolor: on the screen, the left-right bag color
            bagcolor_2q{probe_q} = bagcolor;
            curr_probesymbol = probesymbol(probe_q);
            % draw probe:
            line = 'In this sequence,which bag did this symbol come from ?';
            if french
            line = sprintf('Dans cette s%cquence, de quel sac ce symbol provient-il ?',233);
            end
            DrawFormattedText(video.window,  line, 'center', video.screenYpixels*0.20, black);
            Screen('DrawTexture', video.window, shape_tex(1,curr_probesymbol), [], centerpos, 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(2,curr_probesymbol), [], centerpos, 0, [], [], video.lbgd);
            Screen('DrawTexture', video.window, rep_tex(1,redbuttonside), [], rep_pos(redbuttonside,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, rep_tex(2,redbuttonside), [], rep_pos(redbuttonside,:), 0, [], [], orange);
            Screen('DrawTexture', video.window, rep_tex(1,bluebuttonside),[], rep_pos(bluebuttonside,:),0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, rep_tex(2,bluebuttonside),[], rep_pos(bluebuttonside,:),0, [], [], blue);
            Screen('DrawingFinished', video.window);

            vbl = Screen('Flip', video.window, nextfliptime);
            % wait for final response:
            while true
                % Manual mode: wait for actual user input
                [keyIsDown, secs, keylist] = KbCheck();
                if keyIsDown && (keylist(leftKey) == 1 || keylist(rightKey) == 1) && sum(keylist) == 1
                    respprobe = find(respKeys == (find(keylist==1))); % left or right
                    rtprobe   = secs - vbl;
                    break
                end
            end
            % redraw probe with selection square: 0.4secs:
            Screen('DrawTexture', video.window, shape_tex(1,curr_probesymbol), [], centerpos, 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(2,curr_probesymbol), [], centerpos, 0, [], [], video.lbgd);
            DrawFormattedText(video.window,  line, 'center', video.screenYpixels*0.20, black);
            Screen('DrawTexture', video.window, rep_tex(1,redbuttonside), [], rep_pos(redbuttonside,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, rep_tex(2,redbuttonside), [], rep_pos(redbuttonside,:), 0, [], [], orange);
            Screen('DrawTexture', video.window, rep_tex(1,bluebuttonside), [], rep_pos(bluebuttonside,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, rep_tex(2,bluebuttonside), [], rep_pos(bluebuttonside,:), 0, [], [], blue);
            Screen('FrameRect', video.window, black, selection_rect(respprobe,:), 6);
            Screen('DrawingFinished', video.window);
            nextfliptime = secs + fx_roundfp(0,0,video.ifi);
            vbl = Screen('Flip', video.window, nextfliptime);
            nextfliptime = vbl + fx_roundfp(highlightDur*3,0,video.ifi); % show selection square
            % color feedback on final probe
            tcol = probecolor(probe_q);
            if tcol == 1; tcol = blue; elseif tcol == 2; tcol = orange; end
            Screen('DrawTexture', video.window, shape_tex(1,curr_probesymbol), [], centerpos, 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(2,curr_probesymbol), [], centerpos, 0, [], [], tcol);
            DrawFormattedText(video.window,  line, 'center', video.screenYpixels*0.20, black);
            Screen('DrawTexture', video.window, rep_tex(1,redbuttonside), [], rep_pos(redbuttonside,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, rep_tex(2,redbuttonside), [], rep_pos(redbuttonside,:), 0, [], [], orange);
            Screen('DrawTexture', video.window, rep_tex(1,bluebuttonside), [], rep_pos(bluebuttonside,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, rep_tex(2,bluebuttonside), [], rep_pos(bluebuttonside,:), 0, [], [], blue);
            Screen('FrameRect', video.window, black, selection_rect(respprobe,:), 6);
            guessfinalcorr = bagcolor(respprobe) == probecolor(probe_q);
            if guessfinalcorr
                DrawFormattedText(video.window,'correct','center',video.screenYpixels*0.75,[0,1,0]);
            else
                if french
                    DrawFormattedText(video.window,'faux','center',video.screenYpixels*0.75,[1,0,0]);
                else
                    DrawFormattedText(video.window,'wrong','center',video.screenYpixels*0.75,[1,0,0]);
                end
            end

            Screen('DrawingFinished', video.window);
            vbl = Screen('Flip', video.window, nextfliptime);
            nextfliptime = vbl + fx_roundfp(outcomeDur,0,video.ifi); % show feedback

            vbl = Screen('Flip', video.window, nextfliptime);
            nextfliptime = vbl + fx_roundfp(itiDur,0,video.ifi); % show feedback

            respprobe_2q(probe_q) = respprobe;
            rtprobe_2q(probe_q)   = rtprobe;

            respprobe_chosencolor_2q(probe_q) = bagcolor(respprobe); % chosen bag color;
        end % end of 2 questions.
    end
    %% end of sequence:
    if iseq < 4
        if iseq == 1
            top = 'Well done, you have completed one sequence !\n\n';
            spaceline = 'Press [space] to move on to the next sequence.';
            if french
            top = sprintf('Bien jou%c, tu as fini une s%cquence !\n\n',233,233);
            spaceline = sprintf('Appuie sur [espace] pour aller %c la prochaine s%cquence.',224,233);
            end
        elseif iseq == 2
            top = 'Well done !\n\n';
            spaceline = 'Press [space] to learn the second rule.';
            if french
            top = sprintf('Bien jou%c !\n\n',233);
            spaceline = sprintf('Appuie sur [espace] pour apprendre la deuxi%cme r%cgle.',232,232);
            end
        elseif iseq == 3
            top = 'Well done, now you know both rules !\n\n';
            spaceline = 'Press [space] to continue.';
            if french
            top = sprintf('Bien jou%c, maintenant tu connais les deux r%cgles !\n\n',233,232);
            spaceline = 'Appuie sur [espace] pour continuer.';
            end
        end
        DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.25, black);
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
        Screen('Flip', video.window, vbl+fx_roundfp(0.1,0,video.ifi));
        WaitKeyPress(spaceKey);
        Screen('Flip', video.window);
        WaitSecs(0.5);
    else
        %%% show score cups progressively
        top = 'Well done !\n\nScore:\n';
        spaceline = 'Press [space] to continue.';
        if french
            top = sprintf('Bien jou%c !\n\nScore:\n',233);
            spaceline ='Appuie sur [espace] pour continuer.';
        end
        DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.25, black);
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.80, black);
        Screen('FrameRect', video.window, black, cupframe_rect, 4);
        Screen('Flip', video.window);
        WaitSecs(0.3);
        DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.25, black);
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.80, black);
        Screen('FrameRect', video.window, black, cupframe_rect, 4);
        Screen('DrawTexture', video.window, cuptext, [], cuppos(1,:));
        Screen('Flip', video.window);
        WaitSecs(0.3);
        DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.25, black);
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.80, black);
        Screen('FrameRect', video.window, black, cupframe_rect, 4);
        Screen('DrawTexture', video.window, cuptext, [], cuppos(1,:));
        Screen('DrawTexture', video.window, cuptext, [], cuppos(2,:));
        Screen('Flip', video.window);
        WaitSecs(0.3);
        DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.25, black);
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.80, black);
        Screen('FrameRect', video.window, black, cupframe_rect, 4);
        Screen('DrawTexture', video.window, cuptext, [], cuppos(1,:));
        Screen('DrawTexture', video.window, cuptext, [], cuppos(2,:));
        Screen('DrawTexture', video.window, cuptext, [], cuppos(3,:));
        Screen('Flip', video.window);
        WaitSecs(1);
        WaitKeyPress(spaceKey);
        WaitSecs(0.5);
    end
    
    %% close card textures
    for i = 1:nsamples
        for j = 1:2
            if ~isempty(cardtex{2}(i,j))
                Screen('Close', cardtex{2}(i,j));
            end
        end
    end
    if ~isempty(cardtex{1})
        Screen('Close', cardtex{1});
    end
    %%
    end % END of all sequences
    %% Final reminders:

    correct_count = 0;
    while correct_count < 10 % 10 correct responses

        cardtex_ex = cell(0);
        delta = rand*(40-25)+25;
        deg = [0,delta]+rand*90;
        deg = deg(randperm(2));
        theta_ex = deg2rad(deg);
        LLR = cos(2*theta_ex);
    
        if sum(LLR<0)==2
            target = 'blue';
            if french
            target = 'bleue';
            end
            [~,correctanswer] = min(LLR);
        else
            target = 'orange';
            if french
            target = 'orange';
            end
            [~,correctanswer] = max(LLR);
        end

        shift = rand(1,2)*pi;
        for i = 1:2
            cfg.cardtype  = 3;
            cfg.angl      = theta_ex(i) + shift(i);
            cfg.axis      = -pi/4 + shift(i);
            [img,~]       = make_card_fix(cfg);
            cardtex_ex{i} = Screen('MakeTexture',video.window,img,[],[],floatprecision); % target
        end

        l1 = 'Please keep in mind that the symbol color is indicated by\n';
        l2 = 'the relative angle between the black line and the color background.\n';
        l3 = ['Which one indicates a more *', target,'*-like color?'];
        if french
        l1 = sprintf('Garde en t%cte que la couleur des symbols est indiqu%ce par\n',234,233);
        l2 = 'l''angle relatif entre la barre noire et la couleur du fond.\n';
        l3 = ['Lequel indique une couleur plus *', target,'* ?'];
        end
        DrawFormattedText(video.window, [l1,l2,l3], 'center', video.screenYpixels * 0.25, black);
        cardrec           = CenterRectOnPoint(Screen('Rect',framtex),video.xCenter - disc_outerDim*video.ppd,video.yCenter);
        Screen('DrawTexture',video.window,cardtex_ex{1},[],cardrec);
        cardrec           = CenterRectOnPoint(Screen('Rect',framtex),video.xCenter + disc_outerDim*video.ppd,video.yCenter);
        Screen('DrawTexture',video.window,cardtex_ex{2},[],cardrec);
        Screen('Flip', video.window);
        WaitSecs(1);

        while true
            % Manual mode: wait for actual user input
            [keyIsDown, ~, keylist] = KbCheck();
            if keyIsDown && sum(keylist) == 1 && (keylist(leftKey) == 1 || keylist(rightKey) == 1)
                choice = find(respKeys == (find(keylist==1)));
                break
            end
        end % while awaiting for resp
    
        if choice == correctanswer
            DrawFormattedText(video.window,'correct','center',video.screenYpixels*0.75,[0,1,0]);
            correct_count = correct_count + 1;
        else
            if french
                DrawFormattedText(video.window,'faux','center',video.screenYpixels*0.75,[1,0,0]);
            else
                DrawFormattedText(video.window,'wrong','center',video.screenYpixels*0.75,[1,0,0]);
            end
            correct_count = correct_count - 1;
        end
        Screen('Flip', video.window);
        WaitSecs(0.5);
    end

    top = 'Well done, you have completed the tutorial !\n\n';
    spaceline = 'Press [space] to exit.';
    if french
    top = sprintf('Bien jou%c, tu as fini le tutorial !\n\n',233);
    spaceline = 'Appuie sur [espace] pour quitter.';
    end
    DrawFormattedText(video.window, top, 'center', video.screenYpixels * 0.25, black);
    DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
    Screen('Flip', video.window, vbl+fx_roundfp(0.1,0,video.ifi));
    WaitKeyPress(spaceKey);
    Screen('Flip', video.window);
    WaitSecs(0.5);

    % Close screen
    Priority(0); FlushEvents; ListenChar(0); ShowCursor; Screen('CloseAll');
    Screen('Preference', 'SkipSyncTests', 0);%restore synch testing
    Screen('Preference','VisualDebuglevel',4);%restore warning verbosity
    Screen('Preference','SuppressAllWarnings',0);%=1 == warning verbosity=0
    RestrictKeysForKbCheck([]);

end
%%
function [theta, LLR] = get_theta(kappa, nsamples)
    tprec   = 0.05; % precision on theta (%)
    kprec   = 0.05; % precision on kappa (%)
    % customized functions:
    rndvm   = @(n,t,k)mod(randraw('vonmises',[t*2,k],n)/2,pi);
    pdfvm   = @(x,t,k)exp(k.*cos(2*(x-t)))./(pi*besseli(0,k));
    while true
        % generate samples for the von Mises;
        % make sure the empirically estimated mean and kappa are accurate:
        xt   = rndvm([1,nsamples],0,kappa); % [0, pi]
        phat = fminsearch(@(p)-sum(log(pdfvm(xt(:),p(1),p(2)))),[0,kappa], ...
                 optimset('Display','off','MaxFunEvals',1e4,'TolX',1e-6));
        that = phat(1);
        khat = phat(2);
        LLR  = 2 * kappa * cos(2*xt);
        if abs(that)/pi < tprec/2 && abs(khat-kappa)/kappa < kprec/2 && mean(LLR<0)<1/3
            theta = xt; % if accurate enough, save to theta_match
            break
        end
    end
    LLR = 2 * kappa * cos(2*theta); % log-odds
end