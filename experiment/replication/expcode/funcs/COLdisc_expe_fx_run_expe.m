%%% run experiment
%%% NB: native KB keys are not inhibited: don't press a | p keys!

% requires PTB-3
% requires Valentins IO Toolbox in the Experiment dir
% requires an sqc structure

% sqc         = the experiment structure
% subj        = participant nb
% debugging   = debug (1) | real expe (O)
% eyeinputpar = whether or not to record eyelink: 0 | 1 

% iblock    = block idx in nb of blocks
% iseq      = run idx in nb of run in this block == blkseq
% isqc      = sqc idx out of total nb of sqc in the sqc struct
% ismp      = sample idx in nb of samples in this run
% isamples  = sample idx out of total nb of samples

function expout = COLdisc_expe_fx_run_expe(sqc, subj, block_id, debugging, eyeinputpar, eeginputpar, photodiode, autopilot, istraining, french)

    %% Add toolbox, init subj & set running parameters
    isubuntu = 0;
    if isunix && ~ismac % detect if linux computer
        isubuntu = 1;
    elseif ismac
        addpath(genpath('/Applications/Psychtoolbox'))
    end
    subjdir = sprintf('../Data/S%02d', subj);
    if ~exist(subjdir, 'dir')
        mkdir(subjdir);
    end
    filename = sprintf('expout_S%02d_b%02d_', subj, block_id);
    % Get the list of files in the directory
    fileList = dir(fullfile(subjdir, [filename,'*'])); % any file starting with 'filename'
    % Check if any files match
    if ~isempty(fileList)
        % Display a warning to the user
        warning('A file matching the pattern has been found in the directory:');
        for k = 1:length(fileList)
            fprintf('  %s\n', fileList(k).name);
        end
        % Ask the user if they want to run the block again or quit
        choice = input('Do you want to run this block again? (y/n): ', 's');
        if strcmpi(choice, 'n')
            disp('Exiting the function.');
            return; % Exit the function
        elseif strcmpi(choice, 'y')
            disp('Continuing to run the block...');
            % Continue running the function
        else
            warning('Invalid input. Assuming user wants to quit.');
            return; % Exit the function on invalid input
        end
    end
    % Continue with the rest of the function
    disp('No matching files found or user chose to proceed.');
    time_str = strrep(mat2str(fix(datevec(datetime("now")))),' ','_');
    if istraining
        trainstr = 'train_'; 
    else 
        trainstr = ''; 
    end
    %% Create output structures
    header.subj      = subj;
    header.start     = char(datetime('now', 'Format', 'yyyyMMdd-HHmm'));
    header.aborted   = 1; % Changed to 0 if completes
    header.istrain   = istraining;
    sampling         = struct();
    final            = struct();
    ME               = struct();
    %% Video settings
    video.synchflip            = true;
    video.eyelink.eyeON        = eyeinputpar;
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
    video.fb_sz             = shape_sz_deg*video.ppd; % selection square size
    video.cup_sz            = shape_sz_deg*video.ppd;
    % Color parameters:
    black                   = [0,0,0];
    video.lbgd              = 0.3950; %128/255; % background color (Clemence used 0.3950)
    colrfg                  = COLdisc_cielab(); % cielab orange and blue
    orange                  = colrfg(1,:); % [1,0.5,0];
    blue                    = colrfg(2,:); % [0,0.5,1];
    grayfixt                = applycform([65,0,0],makecform('lab2srgb'));
    photodiodeSq            = [0,0,50,50];
    %% Stimulus timing:
    highlightDur = 0.05;
    outcomeDur   = 0.5;
    itiDur_ul    = [0.75, 1.25];
    delay_ul     = [0.5, 1.0];
    baselineDur  = 5;
    cueDur_ul    = [0.15, 0.25];
    if autopilot==1, outcomeDur = 0.1; itiDur_ul = [0.1,0.1]; delay_ul = [0.1,0.1]; baselineDur = 1; end
    %%
    video.highlightDur = highlightDur;
    video.outcomeDur   = outcomeDur;
    video.itiDur       = itiDur_ul;
    video.baselineDur  = baselineDur;
    video.rtdeadline   = 3;
    video.delay        = delay_ul;
    video.cueDur       = cueDur_ul;
    %%
    RTwarning = 'Too slow!';
    if french
       RTwarning = 'Trop lent !';
    end
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
        fprintf('||| SYNCHFLIP OFF or running on OSX => TIMINGS WILL BE INACCURATE! |||\n')
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
    fprintf('passed OpenWindow!\n')
    
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
    %% Init EYELINK:
    if video.eyelink.eyeON
        % Check the connection is up and running:
        ip = '100.1.1.2';
        system(sprintf('ping %s -c 5', ip));
        % Initialize Eyelink computer:
        status = Eyelink('Initialize', 'PsychEyelinkDispatchCallback'); % ZERO IF OK
        if status ~= 0; error('could not initialize eye-tracker connection!'); end
        [~,ev] = Eyelink('GetTrackerVersion');
        connected = Eyelink('IsConnected'); %1=ok, 2=broadcast, -1=dummy, 0=none
        fprintf('Connection to %s eye-tracker initialized = %d.\n',ev, connected);
        el = EyelinkInitDefaults(video.window); % initialize a PTB el structure
        
        % UPDATE SET OPTIONS SCREEN:
        % calibration & validation options:
        Eyelink('Command', 'automatic_calibration_pacing = 1000');
        Eyelink('Command', 'randomize_calibration_order = YES');
        Eyelink('Command', 'enable_automatic_calibration = NO'); % force manual accept
        Eyelink('Command', 'select_eye_after_validation = NO');
        Eyelink('Command', 'cal_repeat_first_target = YES');
        Eyelink('Command', 'val_repeat_first_target = YES');
        video.eyelink.eyeused = 1; % right eye
        Eyelink('Command','active_eye = RIGHT');
        % tracking options:
        Eyelink('Command', 'search_limits = YES');
        Eyelink('Command', 'move_limits = YES');
        if video.mouseON; Eyelink('Command', 'aux_mouse_simulation = YES');
        elseif video.mouseON == false; Eyelink('Command', 'aux_mouse_simulation = NO');
        end
        % events & data processing options:
        Eyelink('Command','select_parser_configuration = 0'); %this is the cognitive configuration
        % Tracking mode:
        Eyelink('Command', 'pupil_size_diameter = YES'); % = Valentin does diameters
        Eyelink('Command', 'use_ellipse_fitter = NO'); % = centroid
        Eyelink('Command', 'sample_rate = 1000'); 
        Eyelink('Command', 'elcl_tt_power = 2'); % = 75% = default
        Eyelink('Command', 'binocular_enabled = NO'); % monoc
        Eyelink('Command', 'corneal_mode = YES'); % pupilCR
        Eyelink('Command', 'use_high_speed = YES'); % defines sampling rate... -> redundant
        Eyelink('Command', 'simulation_screen_distance = %d', video.eyelink.inputdist_mm);
        video.eyelink.pixelcoords = {video.windowRect(1),...
                                     video.windowRect(2),...
                                     video.windowRect(3)-1,...
                                     video.windowRect(4)-1}';
        Eyelink('Command', 'screen_pixel_coords = %d, %d, %d, %d', video.eyelink.pixelcoords{:});
        video.eyelink.physicalscreensize = ...
                {-round(video.eyelink.inputphys_mm(1)/2),...
                  round(video.eyelink.inputphys_mm(2)/2),...
                  round(video.eyelink.inputphys_mm(1)/2),...
                 -round(video.eyelink.inputphys_mm(2)/2)}';
        Eyelink('Command', 'screen_phys_coords = %d, %d, %d, %d', video.eyelink.physicalscreensize{:});
        % % set the calibration positions to span the full BenQXL2420T screen
        % Eyelink('Command','calibration_area_proportion = 0.88 0.83'); 
        % Eyelink('Command','validation_area_proportion = 0.88 0.83');
        % or shrink calibration positions to the trackable part of the screen
        Eyelink('Command','calibration_area_proportion = 0.67 0.80'); 
        Eyelink('Command','validation_area_proportion = 0.67 0.80'); 
        el.backgroundcolour = video.lbgd;
        Eyelink('Command','calibration_type = HV5'); % HV5 or HV9
        Eyelink('Command','generate_default_targets = NO'); % YES:default or NO:custom
        cnt = [video.screenXpixels/2,video.screenYpixels/2];
        off = video.ppd*9;
        pnt = zeros(5,2);
        pnt(1,:) = cnt;
        pnt(2,:) = cnt-[0,off];
        pnt(3,:) = cnt+[0,off];
        pnt(4,:) = cnt-[off,0];
        pnt(5,:) = cnt+[off,0];
        pnt      = num2cell(reshape(pnt',[],1));
        % calibration
        Eyelink('Command','calibration_samples = 6');
        Eyelink('Command','calibration_sequence = 0,1,2,3,4,5');
        Eyelink('Command','calibration_targets = %d,%d %d,%d %d,%d %d,%d %d,%d',pnt{:});
        % validation
        Eyelink('Command','validation_samples = 5');
        Eyelink('Command','validation_sequence = 0,1,2,3,4,5');
        Eyelink('Command','validation_targets = %d,%d %d,%d %d,%d %d,%d %d,%d',pnt{:});
        Eyelink('Command','calibration_type = HV5'); % HV5 or HV9
        el.displayCalResults = 1;
        EyelinkUpdateDefaults(el); % pass the values back to the Eyelink
        % make sure we get the right data from eyelink:
        Eyelink('command', 'link_sample_data = LEFT,RIGHT,GAZE,DIAMETER,GAZERES,HREF,PUPIL,INPUT,STATUS,BUTTON');
        Eyelink('command', 'link_event_data = GAZE,GAZERES,HREF,DIAMETER,VELOCITY,STATUS');
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK, MESSAGE, INPUT,BUTTON');
        Eyelink('command', 'file_sample_data = LEFT,RIGHT,GAZE,DIAMETER,GAZERES,HREF,PUPIL,STATUS,BUTTON,INPUT,HTARGET');
        Eyelink('command', 'file_event_data = GAZE,GAZERES,HREF,DIAMETER,VELOCITY');
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        % Add structs for missed and outoffix samples: 1 per block:
        video.eyelink.nmiss = zeros(1,numel(unique([sqc.blk])));
        video.eyelink.nout  = zeros(1,numel(unique([sqc.blk])));
        video.eyelink.nevt  = zeros(1,numel(unique([sqc.blk])));
        % Compute limits for fixation tolerance :
        video.eyelink.xtolerance   = video.shape_offset;
        video.eyelink.ytolerance   = video.shape_sz/2;
        video.eyelink.tolerancebox = [0, 0, (video.eyelink.xtolerance*2), video.eyelink.ytolerance*2];
        video.eyelink.tolerancebox = CenterRectOnPoint(video.eyelink.tolerancebox,video.xCenter,video.yCenter);
    end
    %% Triggers setup: Initialize Neurospec for BioSemi Trigger box
    video.eeg.eegON = eeginputpar;
    if video.eeg.eegON
        IOPort('CloseAll')
        com1 = IOPort('OpenSerialPort', FindSerialPort(), 'DTR=1');
        if com1 < 0
            error('Unable to open the serial port.');
        end
        IOPort('Write', com1, uint8(2)); % sending a first trigger
        fprintf('Trigger sent successfully.\n');
        fprintf('\r\nNeurospec Trigger Box initialized successfully \r\n');
   end
    %% Start display:
    % test kb, hide cursor, stop spilling keys
    if ~debugging
        HideCursor;
        FlushEvents;
        ListenChar(2);
    end
    % welcome screen:
    blocks  = unique([sqc.blk]);
    nblocks = numel(blocks);
    nseqs   = numel(sqc([sqc.blk]==block_id));
    if ~istraining
        line1 = 'Beginning of the experiment:\n\n\n';
        line2 = sprintf('    - There will be %d blocks of %d sequences (around 10 min per block),\n',nblocks,nseqs);
        line3 = '    - Short breaks are scheduled between sequences.\n';
        line4 = '    - Some sequences last 20 trials, but others are shorter and\n      may stop unpredictably: Every choice matters:)';
        spaceline = 'Press [space] to start';
        if french
        line1 = sprintf('D%cbut de l''exp%crience :\n\n\n', 233, 233);
        line2 = sprintf('    - Il y aura %d blocs de %d s%cquences (environ 10 min par bloc),\n', nblocks, nseqs, 233);
        line3 = sprintf('    - Des pauses courtes sont pr%cvues entre les s%cquences.\n', 233, 233);
        line4a = sprintf('    - Certaines s%cquences durent 20 essais, mais d''autres sont plus\n', 233);
        line4b = sprintf('      courtes et peuvent s''arr%cter de mani%cre impr%cvisible :\n      Chaque choix compte :)', 234, 232, 233);
        line4 = [line4a line4b];
        spaceline = 'Appuyez sur [espace] pour commencer.';
        end
        DrawFormattedText(video.window, [line1 line2 line3 line4], video.screenYpixels * 0.25, video.screenYpixels * 0.25, black);
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
        vbl = Screen('Flip', video.window, nextfliptime);
        nextfliptime = vbl+fx_roundfp(0.01,0,video.ifi); % wait 10ms
        if ~autopilot
            WaitKeyPress(spaceKey);
        end
    end

    if istraining
        line1 = 'Beginning of training phase:\n\n\n';
        line2 = sprintf('    - There will be %d sequences,\n',nseqs);
        line3 = '    - To help you remember which task you are in, we use a *color* cue \n';
        line4 = '      (see next page).\n';
        spaceline = 'Press [space] to start';
        if french 
            line1 = sprintf('D%cbut de la phase d''entrainement :\n\n\n', 233);
            line2 = sprintf('    - Il y aura %d s%cquences,\n', nseqs, 233);
            line3 = sprintf('    - Pour vous aider %c vous rappeler dans quelle t%cche vous %ctes,\n', 224, 226, 234);
            line4 = '      nous utilisons un indice *couleur* (voir page suivante).\n';
            spaceline = 'Appuyez sur [espace] pour commencer';
        end
        DrawFormattedText(video.window, [line1 line2 line3 line4], video.screenYpixels * 0.25, video.screenYpixels * 0.25, black);
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
        vbl = Screen('Flip', video.window, nextfliptime);
        nextfliptime = vbl+fx_roundfp(0.01,0,video.ifi); % wait 10ms
        if ~autopilot
            WaitKeyPress(spaceKey);
        end
        training_fixcolor = {orange; blue; grayfixt};
        l1 = 'If you see orange: choose the symbol that most likely comes from the orange bag.';
        l2 = 'If you see blue: choose the symbol that most likely comes from the blue bag.';
        l3 = 'If you see gray: guess the color of the bags the symbols come from.';
        spaceline = 'Press [space] to continue.';
        if french
            l1 = sprintf('Si vous voyez orange : choisissez le symbol qui semble %ctre associ%c au sac %s !', 234, 233, 'orange');
            l2 = sprintf('Si vous voyez bleu : choisissez le symbol qui semble %ctre associ%c au sac %s !', 234, 233, 'bleu');
            l3 = 'Si vous voyez gris : devinez la couleur des sacs dont les symboles proviennent !';
            spaceline = 'Appuyez sur [espace] pour continuer.';
        end
        training_text = {l1,l2,l3};
        for whichtask = 1:3
            show_fix;
            Screen('FillOval',video.window,training_fixcolor{whichtask},CenterRectOnPointd([0 0 lineWidthPix lineWidthPix],video.xCenter,video.yCenter));
            DrawFormattedText(video.window, training_text{whichtask}, 'center', video.screenYpixels * 0.30, training_fixcolor{whichtask});
            DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
            r = disc_innerDim*video.ppd/2;
            xc = video.screenXpixels/2;
            yc = video.screenYpixels/2;
            xy2 = [xc - r*cosd(45), yc - r*cosd(45)];
            xy1 = xy2 - 100;
            Screen('DrawLine', video.window, black, xy1(1), xy1(2), xy2(1), xy2(2), 5); % 5 is the line width
            
            % Define triangle size and center
            baseSize = 20; % Triangle base size
            halfBase = baseSize / 2;
            height = baseSize * sqrt(3) / 2; % Equilateral triangle height
            centerX = xy2(1);
            centerY = xy2(2);
            % Define triangle vertices (upright triangle)
            vertices = [-halfBase, height / 2;
                        halfBase, height / 2;
                        0, -height / 2];
            % Rotate the triangle by 45 degrees
            theta = pi / 4 + pi/2; % 45 degrees in radians
            rotationMatrix = [cos(theta), -sin(theta); sin(theta), cos(theta)];
            rotatedVertices = (rotationMatrix * vertices')';
            % Translate the triangle
            triangleX = rotatedVertices(:, 1) + centerX;
            triangleY = rotatedVertices(:, 2) + centerY;
            triangleVertices = [triangleX, triangleY];
            % Draw the filled black triangle
            Screen('FillPoly', video.window, black, triangleVertices);
            
            vbl = Screen('Flip', video.window, nextfliptime);
            nextfliptime = vbl+fx_roundfp(0.01,0,video.ifi); % wait 10ms
            if ~autopilot
                WaitKeyPress(spaceKey);
            end
        end
    end

    %% loop over blocks
    fprintf('Starting looping over blocks \n\n');
    isamples = 0;
    for iblock = block_id
        thisblock = sqc([sqc.blk]==iblock);
        nseq = numel(thisblock);
        choicesgrades = NaN(1,nseq);
        % EYELINK: Calibrate & lock eye after calibration
        % EYELINK: Open EDF file, write header
        % EYELINK: Send SYNCHTIME trigger   
        if video.eyelink.eyeON
            RestrictKeysForKbCheck(allKeys);
            %%% warn calibration
            fprintf('Calibrate eyetracker for block %d\n', iblock);
            calibtxt = sprintf('CALIBRATION BLOC %d / %d...', iblock, nblocks);
            DrawFormattedText(video.window, calibtxt, 'center', video.screenYpixels * 0.50, black);
            spaceline = 'Appuyez sur [espace] pour commencer.';
            DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
            Screen('Flip', video.window, nextfliptime);
            WaitKeyPress(spaceKey);
            
            %%% calibrate:
            EyelinkDoTrackerSetup(el, el.ENTER_KEY); %el.ENTER_KEY shows the eye image on display screen
            [~, calmessage] = Eyelink('CalMessage');
            fprintf('\nCalibration resulted in %s \n', calmessage); %TODO what's this?
            
            %%% start file:
            edfname = sprintf('COX%02d_%d', subj, iblock); % name is >1:8<chars
            status = Eyelink('OpenFile', edfname);
            if status ~= 0, error('... clemence: couldnt open EDF\n'); end
            fprintf('\nOpening EDF for block %d returns: %d (zero is ok!) \n', iblock, status);
            Eyelink('Command', 'set_idle_mode');
            Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld', video.eyelink.pixelcoords{:});
            Eyelink('Message', 'PHY_SCREEN_SIZE %ld %ld %ld %ld', video.eyelink.physicalscreensize{:});
            Eyelink('Message', 'PHY_SCREEN_DISTANCE = %d', video.eyelink.inputdist_mm);
            Eyelink('Message',calmessage);
            Eyelink('command', 'draw_cross %d %d 1', video.xCenter, video.yCenter); % will stay as long as not changed...
            WaitSecs(0.1);
            Eyelink('StartRecording');
            WaitSecs(1); % record 1sec -> preproc Valentin removes 1'' before & after block
            recording = Eyelink('CheckRecording');
            if recording ~= 0 ; error('... clemence: EL cannot record...\n'); end
        end
        RestrictKeysForKbCheck(expeKeys);
        % Begin block screen:
        fprintf('................\n ');
        fprintf('>>>Start block %d/%d----- %s<<<\n', iblock, nblocks, datetime('now', 'Format', 'HH:mm:ss'));
        line = sprintf('START OF BLOCK %.f/%.f!\n', iblock, nblocks);
        spaceline = 'Press [space] to start.';
        if french
        line = sprintf('DEBUT DU BLOC %.f/%.f !\n', iblock, nblocks);
        spaceline = 'Appuyez sur [espace] pour commencer.';
        end
        DrawFormattedText(video.window, line, 'center', video.screenYpixels * 0.30, black);
        DrawFormattedText(video.window, spaceline, 'center', video.screenYpixels * 0.90, black);
        Screen('Flip',video.window);
        if ~autopilot
            WaitKeyPress(spaceKey);
        end
        WaitSecs(1);
        startblk = GetSecs;
        % EYELINK: send synchtime message
        if video.eyelink.eyeON
            Eyelink('Message', 'SYNCHTIME'); %TODO IS THAT NECESSARY???
        end
        if video.mouseON
            warning('mouseON break');
            break
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        fprintf('...Starting looping over sequences\n');
        final = cell(0);
        % block start:
        if video.eyelink.eyeON
            msg = sprintf('BLOCK_start_%03d', iblock);
            Eyelink('Message', msg);
        end
        if video.eeg.eegON
           IOPort('Write', com1, uint8(250));
        end
        WaitSecs(0.2);

        % loop over sequences:
        for iseq = 1:nseq
            % Get current seq index in full sqc str
            isqc = find([sqc.blk] == iblock & [sqc.blkseq] == iseq);
            %% baseline pupil recording
            show_fix;
            line = 'Baseline pupil recording:\n please fixate well!';
            if french
            line = sprintf('Enregistrement de la pupille de base :\n veuillez bien fixer le centre de l''%ccran',233);
            end
            DrawFormattedText(video.window, line, 'center', video.screenYpixels * 0.30, black);
            % Draw run progress at the bottom
            progressline = sprintf('Sequence %.f/%.f of this block\n',iseq,nseq);
            if french
            progressline = sprintf('S%cquence %.f/%.f de ce bloc\n',233,iseq,nseq);
            end
            DrawFormattedText(video.window, progressline, 'center', video.screenYpixels * 0.90, black);
            Screen('Flip', video.window);
            % RestrictKeysForKbCheck(spaceKey);
            if ~autopilot
                % WaitKeyPress(spaceKey);
                WaitSecs(2);
            end
            Screen('Flip', video.window);
            WaitSecs(0.25);
            show_fix;
            Screen('Flip', video.window);
            if video.eyelink.eyeON
                msg = sprintf('ISQC_baselineStart_%03d', isqc);
                Eyelink('Message', msg);
            end
            if video.eeg.eegON
               IOPort('Write', com1, uint8(140));
            end
            WaitSecs(video.baselineDur);
            Screen('Flip', video.window);
            if video.eyelink.eyeON
                msg = sprintf('ISQC_baselineEnd_%03d', isqc);
                Eyelink('Message', msg);
            end
            if video.eeg.eegON
               IOPort('Write', com1, uint8(142));
            end
            WaitSecs(0.5);
            %% task instruction
            % Get current seq index in full sqc str
            % isqc = find([sqc.blk] == iblock & [sqc.blkseq] == iseq);
            if mod(isqc,3) == 0, fprintf('Seq # %d/%d...\n', iseq, nseq); end
            % Draw instructions for current seq
            targetsymbol = sqc(isqc).targetsymbol;
            othersymbol  = sqc(isqc).othersymbol;
            condition    = sqc(isqc).condition;
            counterfness = sqc(isqc).counterfness;
            targetcolor  = sqc(isqc).targetcolor;
            sidea        = sqc(isqc).instrside; % get side of target at the instructions
            sideb        = 3 - sidea;
            if      targetcolor == 1; colorstr = 'blue'; if french, colorstr = 'bleu'; end; colorrgb = blue;
            elseif  targetcolor == 2; colorstr = 'orange'; colorrgb = orange;
            end
            
            if french
                if condition == 1 % get instructions string
                    line = sprintf('Voici les symboles : choisissez celui qui semble %ctre associ%c au sac %s !', 234, 233, colorstr);
                    DrawFormattedText(video.window, line, 'center', video.screenYpixels * 0.30, colorrgb);
                elseif condition == 2
                    line = 'Voici les symboles; devinez la couleur des sacs dont ils proviennent !';
                    DrawFormattedText(video.window, line, 'center', video.screenYpixels * 0.30, grayfixt);
                end
            else
                if condition == 1
                    line = sprintf('These are the symbols; choose the one that most likely comes from the %s bag.', colorstr);
                    DrawFormattedText(video.window, line, 'center', video.screenYpixels * 0.30, colorrgb);
                elseif condition == 2
                    line = 'These are the symbols; guess the color of the bags they come from.';
                    DrawFormattedText(video.window, line, 'center', video.screenYpixels * 0.30, grayfixt);
                end
            end

            % Draw symbols of this sequence (instruction)
            % show_fix;
            Screen('DrawTexture', video.window, shape_tex(1,targetsymbol), [], positions(sidea,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(2,targetsymbol), [], positions(sidea,:), 0, [], [], video.lbgd);
            Screen('DrawTexture', video.window, shape_tex(1,othersymbol),  [], positions(sideb,:), 0, [], [], [0,0,0]);
            Screen('DrawTexture', video.window, shape_tex(2,othersymbol),  [], positions(sideb,:), 0, [], [], video.lbgd);
            
            % Draw run progress at the bottom
            spaceline = 'Press [space] to start.';
            progressline = sprintf('Sequence %.f/%.f of this block, continue!\n', iseq, nseq);
            if french
                spaceline = 'Appuyez sur [espace] pour commencer.';
                progressline = sprintf('S%cquence %.f/%.f de ce bloc, continuez !\n',233,iseq,nseq);
            end
            nextline = [progressline spaceline];
            DrawFormattedText(video.window, nextline, 'center', video.screenYpixels * 0.90, black);
            
            % Flip, wait for spacebar press, wait 1''
            Screen('DrawingFinished', video.window);
            vbl = Screen('Flip', video.window);
            % EYELINK: check recording
            % EYELINK: send begin runx message
            if video.eyelink.eyeON
                err = Eyelink('CheckRecording');
                if(err~=0); error('CheckRecording problem'); end
                msg = sprintf('ISQC_instr_%03d', isqc);
                Eyelink('Message', msg);
            end
            nextfliptime = vbl+fx_roundfp(1,0,video.ifi); % wait 1sec showing the instructions
            RestrictKeysForKbCheck(spaceKey);
            if ~autopilot
                WaitKeyPress(spaceKey);
            end
            show_fix;
            Screen('Flip', video.window);
            WaitSecs(2);
            % EYELINK: send start message
            if video.eyelink.eyeON
                msg = sprintf('ISQC_start_%03d', isqc);
                Eyelink('Message', msg);
            end
            if video.eeg.eegON
               IOPort('Write', com1, uint8(150));
            end
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

            % make card textures
            shift             = sqc(isqc).discRotation;
            ncards            = sqc(isqc).nsamples;
            cfg               = [];
            cfg.ppd           = video.ppd;
            cfg.disc_outerDim = disc_outerDim;
            cfg.disc_innerDim = disc_innerDim;
            cfg.lbgd          = video.lbgd;
            cfg.axis          = -pi/4 + shift; % orange=0,blue=pi/2,if shift=0

            cardtex           = cell(1,2);
            cfg.cardtype      = 1;
            img               = make_card_fix(cfg);
            cardtex{1}        = Screen('MakeTexture',video.window,img,[],[],floatprecision);
            cardtex{2}        = zeros(ncards,1);
            for i = 1:ncards
                cfg.cardtype    = 3;
                cfg.angl        = sqc(isqc).theta.target(i) + shift;
                img             = make_card_fix(cfg);
                cardtex{2}(i,1) = Screen('MakeTexture',video.window,img,[],[],floatprecision); % target
                cfg.angl        = sqc(isqc).theta.other(i) + shift;
                img             = make_card_fix(cfg);
                cardtex{2}(i,2) = Screen('MakeTexture',video.window,img,[],[],floatprecision); % other
            end
            %% gather visual and decision-value information
            vis = []; llr = [];
            for i = ncards:-1:1
                vis(1,i) = sqc(isqc).theta.target(i) + shift; % presented bar orientation
                vis(2,i) = sqc(isqc).theta.other(i) + shift;
                llr(1,i) = sqc(isqc).colorslin.target(i); % decision value
                llr(2,i) = sqc(isqc).colorslin.other(i);
            end
            %%
            rad2deg([sqc(isqc).theta.target, sqc(isqc).theta.other])
            latent = sum([sqc(isqc).colorslin.target, sqc(isqc).colorslin.other]);
            if sidea==2, latent = latent([2,1]); end % if target at instruction is on the rightside
            fprintf('\n >>> Nsamp = %d || latent: %.3f, %.3f (cond: %d) || discrot(deg) = %.3f \n',...
                sqc(isqc).nsamples,latent(1),latent(2),sqc(isqc).condition,rad2deg(shift));

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% loop over samples
            nsamples       = sqc(isqc).nsamples;
            choices        = nan(1,nsamples);
            choiceRTs      = nan(1,nsamples);
            choices_LR     = nan(1,nsamples);
            chosen_vis     = nan(1,nsamples);
            chosen_llr     = nan(1,nsamples);
            unchosen_vis   = nan(1,nsamples);
            unchosen_llr   = nan(1,nsamples);
            vis_NaN        = vis*NaN;
            llr_NaN        = llr*NaN;
            simulatechoice = sqc(isqc).optchoices; % autopilot
            
            for ismp = 1:nsamples
                RestrictKeysForKbCheck(expeKeys);
                %% fixation only
                show_fix;
                fixcolor = {colorrgb; grayfixt};
                Screen('FillOval',video.window,fixcolor{condition},CenterRectOnPointd([0 0 lineWidthPix lineWidthPix],video.xCenter,video.yCenter));
                if photodiode, Screen('FillRect', video.window, [0,0,0], photodiodeSq); end
                vbl = Screen('Flip', video.window, nextfliptime);
                % triggers:
                if video.eyelink.eyeON
                    msg = sprintf('ISMP_fixcue_run%03d_smp%02d', isqc, ismp);
                    Eyelink('Message', msg);
                end
                if video.eeg.eegON
                   IOPort('Write', com1, uint8(98));
                end
                cueDur = cueDur_ul(1) + diff(cueDur_ul)*rand;
                nextfliptime = vbl + fx_roundfp(cueDur,0,video.ifi);
                %% fixation + empty disc
                Screen('DrawTexture',video.window,cardtex{1},[],cardrec);
                show_fix;
                if photodiode, Screen('FillRect', video.window, [0,0,0], photodiodeSq); end
                vbl_fixON = Screen('Flip', video.window, nextfliptime);
                % triggers:
                if video.eyelink.eyeON
                    msg = sprintf('ISMP_fixdisc_run%03d_smp%02d', isqc, ismp);
                    Eyelink('Message', msg);
                end
                if video.eeg.eegON
                   IOPort('Write', com1, uint8(100));
                end
                %% fixation delay
                % delay = delay_ul(1) + diff(delay_ul)*rand;
                delay = truncated_exponential(delay_ul(1), delay_ul(2), 0.7, 1);
                if ismp == 1 % longer fixation at first trial
                    delay = 1.0 + (2.0-1.0)*rand;
                end
                nextfliptime = vbl_fixON + fx_roundfp(delay,0,video.ifi);
                if video.eyelink.eyeON == 1
                    while GetSecs < nextfliptime; video = COLdisc_expe_fx_check_missing_pupil(video, iblock); end
                end
                %% fixation + empty disc + 2 shapes
                Screen('DrawTexture',video.window,cardtex{1},[],cardrec);
                show_fix; 
                if photodiode, Screen('FillRect', video.window, [1,1,1], photodiodeSq); end
                % Draw sampling alternatives: draw "target" on "symbolside"
                targetside = sqc(isqc).symbolsides(ismp);
                otherside  = 3 - targetside;
                Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
                Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], positions(targetside,:), 0, [], [], video.lbgd);
                Screen('DrawTexture', video.window, shape_tex(1,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
                Screen('DrawTexture', video.window, shape_tex(2,othersymbol), [], positions(otherside,:) , 0, [], [], video.lbgd);
                Screen('DrawingFinished', video.window);
                % Before next flip, check for pupil status and abort key:
                while GetSecs < nextfliptime
                    if CheckKeyPress(escapeKey)
                        Priority(0); FlushEvents; ListenChar(0); ShowCursor;
                        WaitSecs(1); Eyelink('Command', 'set_idle_mode'); Eyelink('StopRecording'); Eyelink('CloseFile');
                        edfpath = fullfile(pwd, '/', subjdir);
                        Eyelink('ReceiveFile', edfname, edfpath, 1);
                        error('aborted by ESCAPE');
                    end
                    if video.eyelink.eyeON == 1; video = COLdisc_expe_fx_check_missing_pupil(video, iblock); end
                end
                vbl_shapes = Screen('Flip', video.window, nextfliptime);
                % triggers:
                if video.eyelink.eyeON
                    msg = sprintf('ISMP_smpprobe_run%03d_smp%02d', isqc, ismp);
                    Eyelink('Message', msg);
                end
                if video.eeg.eegON
                   IOPort('Write', com1, uint8(66));
                end
                %% Get sampling choice:
                while true
                    if autopilot == 1
                        % Autopilot mode: simulate user input
                        pause(0.25); % Wait for 0.25 seconds
                        keyIsDown = 1; % Simulate key press
                        secs = GetSecs(); % Simulate time of key press
                        % choose left or right key by optimal simulation
                        if ismp==1
                            simulatedKey = randi([1 2]);
                        else % from 2nd trial
                            choice_shape = simulatechoice(choices(1),ismp);
                            % where is this shape?
                            if choice_shape==1 % choose target shape
                                simulatedKey = targetside;
                            elseif choice_shape==2 % choose other shape
                                simulatedKey = otherside;
                            end
                        end
                        keylist = zeros(1, 256); % Initialize keylist
                        if simulatedKey == 1
                            keylist(leftKey) = 1; % Simulate left key press
                        else
                            keylist(rightKey) = 1; % Simulate right key press
                        end
                    else
                        % Manual mode: wait for actual user input
                        [keyIsDown, secs, keylist] = KbCheck();
                    end
                    if video.eyelink.eyeON == 1; video = COLdisc_expe_fx_check_missing_pupil(video, iblock); end
                    if keyIsDown && sum(keylist) == 1 && (keylist(leftKey) == 1 || keylist(rightKey) == 1)
                        % triggers:
                        if video.eyelink.eyeON
                            if keylist(leftKey) == 1
                               msg = sprintf('ISMP_respL_run%03d_smp%02d', isqc, ismp);
                            elseif keylist(rightKey) == 1
                               msg = sprintf('ISMP_respR_run%03d_smp%02d', isqc, ismp);
                            end
                            Eyelink('Message', msg);
                        end
                        if video.eeg.eegON
                            if keylist(leftKey) == 1
                               IOPort('Write', com1, uint8(77));
                            elseif keylist(rightKey) == 1
                               IOPort('Write', com1, uint8(88));
                            end
                        end
                        rt = secs - vbl_shapes; 
                        choice = find(respKeys == (find(keylist==1)));
                        choices_LR(ismp) = choice;
                        choiceRTs(ismp) = rt;
                        break
                    end
                end % while awaiting for resp
                if rt > video.rtdeadline && ismp > 2, istooslow = 1; else, istooslow = 0; end
                nextfliptime = secs + fx_roundfp(0,0,video.ifi);
                %% Choice highlight:
                Screen('DrawTexture',video.window,cardtex{1},[],cardrec);
                show_fix;
                if photodiode, Screen('FillRect', video.window, [0,0,0], photodiodeSq); end
                if choice == targetside
                    samplecolor = sqc(isqc).colorslin.target(ismp,:);
                    Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
                    Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
                    Screen('DrawTexture', video.window, shape_tex(1,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
                    Screen('DrawTexture', video.window, shape_tex(2,othersymbol), [], positions(otherside,:) , 0, [], [], video.lbgd);
                    choices(ismp) = 1; % choice of shape
                elseif choice == otherside
                    samplecolor = sqc(isqc).colorslin.other(ismp,:);
                    Screen('DrawTexture', video.window, shape_tex(1,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
                    Screen('DrawTexture', video.window, shape_tex(2,othersymbol), [], positions(otherside,:) , 0, [], [], [0,0,0]);
                    Screen('DrawTexture', video.window, shape_tex(1,targetsymbol),[], positions(targetside,:), 0, [], [], [0,0,0]);
                    Screen('DrawTexture', video.window, shape_tex(2,targetsymbol),[], positions(targetside,:), 0, [], [], video.lbgd);
                    choices(ismp) = 2;
                end
                % check pupil status before flipping highlight:
                if video.eyelink.eyeON == 1
                    while GetSecs < nextfliptime; video = COLdisc_expe_fx_check_missing_pupil(video, iblock); end
                end
                vbl_highlight = Screen('Flip', video.window, nextfliptime);
                nextfliptime = vbl_highlight + fx_roundfp(highlightDur,0,video.ifi);
                %% Choice highlight off (only fix + empty disc)
                Screen('DrawTexture',video.window,cardtex{1},[],cardrec);
                show_fix;
                if photodiode, Screen('FillRect', video.window, [0,0,0], photodiodeSq); end
                % check pupil status before next flip (showingoutcome):
                if video.eyelink.eyeON == 1
                    while GetSecs < nextfliptime; video = COLdisc_expe_fx_check_missing_pupil(video, iblock); end
                end
                vbl_highlightOFF = Screen('Flip', video.window, nextfliptime);
                % triggers:
                if video.eyelink.eyeON
                    msg = sprintf('ISMP_highlightOFF_run%03d_smp%02d', isqc, ismp);
                    Eyelink('Message', msg);
                end
                if video.eeg.eegON
                   IOPort('Write', com1, uint8(90));
                end
                %% Outcome delay: delay_ul = [0.5, 1]
                % delay = delay_ul(1) + diff(delay_ul)*rand;
                delay = truncated_exponential(delay_ul(1), delay_ul(2), 0.7, 1);
                nextfliptime = vbl_highlightOFF + fx_roundfp(delay,0,video.ifi);
                if video.eyelink.eyeON == 1
                    while GetSecs < nextfliptime; video = COLdisc_expe_fx_check_missing_pupil(video, iblock); end
                end
                %% Outcome on:
                Screen('DrawTexture',video.window,cardtex{2}(ismp,choices(ismp)),[],cardrec);
                show_fix;
                if photodiode, Screen('FillRect', video.window, [1,1,1], photodiodeSq); end
                vbl_outcome = Screen('Flip', video.window, nextfliptime);
                if video.eyelink.eyeON
                    msg = sprintf('ISMP_outcomeON_run%03d_smp%02d', isqc, ismp);
                    Eyelink('Message', msg);
                end
                if video.eeg.eegON
                   IOPort('Write', com1, uint8(10));
                end
                nextfliptime = vbl_outcome + fx_roundfp(outcomeDur,0,video.ifi);
                %% Outcome off:
                if photodiode, Screen('FillRect', video.window, [0,0,0], photodiodeSq); end
                if video.eyelink.eyeON == 1
                    while GetSecs < nextfliptime; video = COLdisc_expe_fx_check_missing_pupil(video, iblock); end
                end
                itiDur = itiDur_ul(1) + diff(itiDur_ul)*rand; % jitter iti
                if ~istooslow % normal
                    show_fix;
                    vbl = Screen('Flip', video.window, nextfliptime);
                    nextfliptime = vbl + fx_roundfp(itiDur,0,video.ifi); % for next trial
                    if video.eyelink.eyeON
                        msg = sprintf('ISMP_outcomeOFF_run%03d_smp%02d', isqc, ismp);
                        Eyelink('Message', msg);
                    end
                    if video.eeg.eegON
                       IOPort('Write', com1, uint8(20));
                    end
                else % slow RT warning
                    DrawFormattedText(video.window, RTwarning, 'center', 'center', [1,1,1]);
                    Screen('Flip', video.window, nextfliptime);
                    if video.eyelink.eyeON
                        msg = sprintf('ISMP_outcomeOFFslow_run%03d_smp%02d', isqc, ismp);
                        Eyelink('Message', msg);
                    end
                    if video.eeg.eegON
                       IOPort('Write', com1, uint8(22));
                    end
                    WaitSecs(0.5); 
                    show_fix;
                    vbl = Screen('Flip', video.window); % remove after .5 s
                    nextfliptime = vbl + fx_roundfp(itiDur,0,video.ifi); % for next trial
                end

                %% Store choice feedback, visual orientationd and decision value
                chosen_vis(ismp)   = vis(choices(ismp),ismp);
                chosen_llr(ismp)   = llr(choices(ismp),ismp);
                unchosen_vis(ismp) = vis(3-choices(ismp),ismp);
                unchosen_llr(ismp) = llr(3-choices(ismp),ismp);

                vis_NaN(choices(ismp),ismp) = vis(choices(ismp),ismp);
                llr_NaN(choices(ismp),ismp) = llr(choices(ismp),ismp);
                %% Store sampling:
                isamples = isamples + 1;
                sampling(isamples).subj = subj;
                sampling(isamples).condition = condition;
                sampling(isamples).mirroring = sqc(isqc).mirroring;
                sampling(isamples).blk = sqc(isqc).blk;
                sampling(isamples).blkseq = iseq;
                sampling(isamples).isqc = isqc;    
                sampling(isamples).samplenb = ismp;
                sampling(isamples).nsamples = sqc(isqc).nsamples;
                sampling(isamples).symbolpair = sqc(isqc).symbolpair;
                sampling(isamples).targetsym = targetsymbol;
                sampling(isamples).counterfness = sqc(isqc).counterfness;
                sampling(isamples).targetcolor = targetcolor;
                sampling(isamples).targetside = targetside;
                sampling(isamples).samplingchoice = choice;
                sampling(isamples).samplingcolor = samplecolor;
                sampling(isamples).samplingrt = rt; 
                save(sprintf('%s/%sexpout_S%02d_b%02d_%s.mat', subjdir, trainstr, subj, iblock, time_str),...
                    'header', 'sampling', 'final', 'sqc', 'video', 'ME');
            end % FOR each sample
            % close card textures
            for i = 1:ncards
                for j = 1:2
                    if ~isempty(cardtex{2}(i,j))
                        Screen('Close', cardtex{2}(i,j));
                    end
                end
            end
            if ~isempty(cardtex{1})
                Screen('Close', cardtex{1});
            end
            WaitSecs(0.5);
            RestrictKeysForKbCheck(expeKeys);
            %% Final probe text; depending on condition
            respprobe_2q = nan(1,2);
            rtprobe_2q   = nan(1,2);
            bagcolor     = nan(1,2);
            bagcolor_2q  = cell(0);
            probesymbol  = nan(1,2);
            probecolor   = nan(1,2);
            respprobe_chosencolor_2q = nan(1,2);
           
            switch condition
                case 1 % bandit: no final probe
                    guessfinalcorr = nan(1,2);
                case 2 % guess task: show final probe:
                    probeside = [sqc(isqc).probeside_shape1
                                 sqc(isqc).probeside_shape2];
                    switch sqc(isqc).counterfness
                        case 1
                         target_latent_color = sqc(isqc).targetcolor;
                         other_latent_color  = sqc(isqc).targetcolor;
                        case 2
                         target_latent_color = 3-sqc(isqc).targetcolor;
                         other_latent_color  = 3-sqc(isqc).targetcolor;
                        case 3
                         target_latent_color = sqc(isqc).targetcolor;
                         other_latent_color  = 3-sqc(isqc).targetcolor;
                    end
                    if sqc(isqc).probe_target_1st
                        probesymbol = [targetsymbol,othersymbol];
                        probecolor  = [target_latent_color,other_latent_color]; % true answer
                    else
                        probesymbol = [othersymbol,targetsymbol];
                        probecolor  = [other_latent_color,target_latent_color];
                    end
                    %% looping over 2 shapes probe questions:
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
                        line = sprintf('In this sequence, which bag did this symbol come from?');
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
                    
                        % check pupil status before showing final probe:
                        if video.eyelink.eyeON == 1
                            while GetSecs < nextfliptime; video = COLdisc_expe_fx_check_missing_pupil(video, iblock); end
                        end
                        vbl = Screen('Flip', video.window, nextfliptime);

                        % EYELINK: final probe run x
                        if video.eyelink.eyeON
                            msg = sprintf('ISQC_finalprobe_%03d', isqc);
                            Eyelink('Message', msg);
                        end
                        if video.eeg.eegON
                            IOPort('Write', com1, uint8(166));
                        end
                    
                        % wait for final response:
                        optimalFinalChoice = find(bagcolor==probecolor(probe_q));
                        while true
                            if autopilot == 1
                                % Autopilot mode: simulate user input
                                pause(0.25); % Wait for 0.25 seconds
                                keyIsDown = 1; % Simulate key press
                                secs = GetSecs(); % Simulate time of key press
                                % Randomly choose left or right key
                                simulatedKey = optimalFinalChoice; % 1 for left, 2 for right
                                keylist = zeros(1, 256); % Initialize keylist
                                if simulatedKey == 1
                                    keylist(leftKey) = 1; % Simulate left key press
                                else
                                    keylist(rightKey) = 1; % Simulate right key press
                                end
                            else
                                % Manual mode: wait for actual user input
                                [keyIsDown, secs, keylist] = KbCheck();
                            end
                            if keyIsDown && (keylist(leftKey) == 1 || keylist(rightKey) == 1) && sum(keylist) == 1
                                % EYELINK: final resp run x
                                if video.eyelink.eyeON
                                    if keylist(leftKey) == 1
                                       msg = sprintf('ISQC_finrespL_%03d', isqc);
                                    elseif keylist(rightKey) == 1
                                       msg = sprintf('ISQC_finrespR_%03d', isqc);
                                    end
                                    Eyelink('Message', msg);
                                end
                                if video.eeg.eegON
                                    if keylist(leftKey) == 1
                                       IOPort('Write', com1, uint8(177));
                                    elseif keylist(rightKey) == 1
                                       IOPort('Write', com1, uint8(188));
                                    end
                                end
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
                        
                        % EYELINK: show selection run x
                        if video.eyelink.eyeON
                            msg = sprintf('ISQC_finsel_%03d', isqc);
                            Eyelink('Message', msg);
                        end
                        if video.eeg.eegON
                            IOPort('Write', com1, uint8(190));
                        end
                    
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
                        guesscorr = bagcolor(respprobe) == probecolor(probe_q);
                        if guesscorr
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

                        % EYELINK: show feedback final probe run x
                        if video.eyelink.eyeON
                            msg = sprintf('ISQC_finfb_%03d', isqc);
                            Eyelink('Message', msg);
                        end
                        if video.eeg.eegON
                            IOPort('Write', com1, uint8(110));
                        end

                        respprobe_2q(probe_q)             = respprobe;
                        rtprobe_2q(probe_q)               = rtprobe;
                        respprobe_chosencolor_2q(probe_q) = bagcolor(respprobe); % chosen bag color;
                        
                    end % end of 2 questions.
                    guessfinalcorr = respprobe_chosencolor_2q == probecolor;
            end %CASE condition open, show final probe
            %% End of seq, triggers
            WaitSecs(0.5);
            if video.eyelink.eyeON
                msg = sprintf('ISQC_end_%03d', isqc);
                Eyelink('Message', msg);
            end
            if video.eeg.eegON
                IOPort('Write', com1, uint8(152));
            end
            % End of seq
            Screen('FillRect', video.window, video.lbgd);
            % Draw end progress screen at the bottom
            spaceline = 'Press [space] to continue, or take a short break.';
            progressline = sprintf('Thank you! Sequence %.f/%.f of this block done.\n', iseq, nseq);
            if french
                spaceline = 'Appuyez sur [espace] pour continuer, ou prenez une courte pause.';
                progressline = sprintf('Merci ! S%cquence %.f/%.f de ce bloc termin%c.\n', 233, iseq, nseq, 233);
            end
            endline = [progressline spaceline];
            DrawFormattedText(video.window, endline, 'center', video.screenYpixels * 0.90, black);
            vbl = Screen('Flip', video.window, nextfliptime);
            nextfliptime = vbl + fx_roundfp(0.3,0,video.ifi); % 0.3 before nextrun
            if ~autopilot
                WaitKeyPress(spaceKey);
            end
            %% Scoring for this seq
            if condition==1 % bandit task
                if counterfness>=3 % counterfactual squences
                    choicesgrades(iseq) = sum(choices==1)/nsamples;
                else % score based on optimal solution; contingent on 1st choice:
                    choicesgrades(iseq) = sum(choices == sqc(isqc).optchoices(choices(1),:))/nsamples;
                end
            elseif condition==2 % guess task
                choicesgrades(iseq) = mean(guessfinalcorr,'omitmissing');
            end
            
            % Store final response: cuisine pour remettre info dans tous les samples:
            for i = (isamples-(nsamples-1)):isamples
                sampling(i).finalresponse             = respprobe_2q;
                sampling(i).finalrt                   = rtprobe_2q;
                sampling(i).probecolor                = probecolor;
                sampling(i).probesymbol               = probesymbol;
                sampling(i).bagcolor                  = bagcolor;
                sampling(i).respprobe_chosencolor_2q  = respprobe_chosencolor_2q;
            end
            final(isqc).subj                        = subj;
            final(isqc).condition                   = condition;
            final(isqc).mirroring                   = sqc(isqc).mirroring;
            final(isqc).blk                         = sqc(isqc).blk;
            final(isqc).blkseq                      = sqc(isqc).blkseq;
            final(isqc).isqc                        = isqc;
            final(isqc).nsamples                    = sqc(isqc).nsamples;
            final(isqc).symbolpair                  = sqc(isqc).symbolpair;
            final(isqc).targetsymbol                = targetsymbol;
            final(isqc).counterfness                = sqc(isqc).counterfness;
            final(isqc).targetcolor                 = sqc(isqc).targetcolor;
            final(isqc).finalresponseside           = respprobe_2q;
            final(isqc).finalrt                     = rtprobe_2q;
            final(isqc).guessfinalcorr              = guessfinalcorr;
            final(isqc).respprobe_chosencolor_2q    = respprobe_chosencolor_2q;
            final(isqc).bagcolor_2q                 = bagcolor_2q;
            final(isqc).probecolor                  = probecolor; % true answer
            final(isqc).probesymbol                 = probesymbol;
            final(isqc).choices                     = choices;
            final(isqc).choices_LR                  = choices_LR;
            final(isqc).choiceRTs                   = choiceRTs;
            final(isqc).chosen_vis                  = chosen_vis;
            final(isqc).unchosen_vis                = unchosen_vis;
            final(isqc).chosen_llr                  = chosen_llr;
            final(isqc).unchosen_llr                = unchosen_llr;
            final(isqc).vis_NaN                     = vis_NaN;
            final(isqc).llr_NaN                     = llr_NaN;
            final(isqc).choicesgrades               = choicesgrades; 
            save(sprintf('%s/%sexpout_S%02d_b%02d_%s.mat', subjdir, trainstr, subj, iblock, time_str),...
                'header', 'sampling', 'final', 'sqc', 'video', 'ME');
        end % FOR each run of samples in this block
        
        % EYELINK: close EDF and transfer
        if video.eyelink.eyeON
            WaitSecs(1); Eyelink('Command', 'set_idle_mode'); Eyelink('StopRecording'); Eyelink('CloseFile');
            % flip to participant to wait:
            line = '... please wait while your data is transferred for this block ...';
            if french
                line = sprintf('... veuillez patienter pendant le transfert de vos donn%ces pour ce bloc ...',233);
            end
            DrawFormattedText(video.window, line, 'center', video.screenYpixels * 0.5, black);
            vbl = Screen('Flip', video.window, nextfliptime);
            nextfliptime = vbl+fx_roundfp(0.01,0,video.ifi); %wait 10ms
            edfpath = subjdir;
            eyefilename = fullfile([edfpath, '/', edfname, '_', time_str, '.edf']);
            gotit = Eyelink('ReceiveFile', edfname, eyefilename);
            fprintf('\nData transfered = %d Mo, file >>>%s.edf can be found in >>>%s. \n', gotit, edfname, edfpath);
        end

        save(sprintf('%s/%sexpout_S%02d_b%02d_%s.mat', subjdir, trainstr, subj, iblock, time_str),...
            'header', 'sampling', 'final', 'sqc', 'video', 'ME');

        %%% End of each block, insert pause & flip score
        endblk = GetSecs;
        avgscore = mean(choicesgrades,'omitmissing');
        blkkeypresses = [sampling([sampling.blk] == iblock).samplingchoice]; % get samples from this block & check key presses:
        keypresses = sum(blkkeypresses==1)/numel(blkkeypresses)*100;
        if french
            fprintf('\n...******************************\n...BLOC FINI %d !\n', iblock);
            fprintf('...Bloc a dur%c %.f:%02.f min\n', 233,(endblk - startblk)/60, mod((endblk - startblk),60))
            fprintf('...Mean prop of optimal responses is %2.f%%\n', avgscore*100);
            fprintf('...Participant pressed [a] %.f %%\n', keypresses);
        end
        fprintf('\n...******************************\n...DONE WITH BLOCK %d!\n', iblock);
        fprintf('...Block lasted %.f:%02.f min\n', (endblk - startblk)/60, mod((endblk - startblk),60))
        fprintf('...Mean prop of optimal responses is %2.f%%\n', avgscore*100);
        fprintf('...Participant pressed [a] %.f %%\n', keypresses);
        if video.eyelink.eyeON == 1
            fprintf('...total BADPUPIL (miss =%.01f%%, out =%.01f%%) =  %f\n',video.eyelink.nmiss/video.eyelink.nevt*100,...
                video.eyelink.nout/video.eyelink.nevt*100, (video.eyelink.nmiss+video.eyelink.nout)/(video.eyelink.nevt)*100);
        end
        fprintf('...*****Participant is on BREAK!\n...*****Press [t] and [y] to continue.\n...******************************\n')
        %%% show block score feedback
        if avgscore < 0.5
            pscr = 0;
        elseif avgscore >= 0.5 && avgscore <= 0.65
            pscr = 1;
        elseif avgscore > 0.65 && avgscore <= 0.70
            pscr = 2;
        elseif avgscore > 0.70
            pscr = 3;
        end
        %%%% show score for 0.8 seconds
        switch pscr
            case 0
                Screen('FrameRect', video.window, black, cupframe_rect, 4);
            case 1
                Screen('FrameRect', video.window, black, cupframe_rect, 4);
                Screen('DrawTexture', video.window, cuptext, [], cuppos(1,:));
            case 2
                Screen('FrameRect', video.window, black, cupframe_rect, 4);
                Screen('DrawTexture', video.window, cuptext, [], cuppos(1,:));
                Screen('DrawTexture', video.window, cuptext, [], cuppos(2,:));
            case 3
                Screen('FrameRect', video.window, black, cupframe_rect, 4);
                Screen('DrawTexture', video.window, cuptext, [], cuppos(1,:));
                Screen('DrawTexture', video.window, cuptext, [], cuppos(2,:));
                Screen('DrawTexture', video.window, cuptext, [], cuppos(3,:));
        end
        vbl = Screen('Flip', video.window, nextfliptime);
        nextfliptime = vbl+fx_roundfp(0.8,0,video.ifi); % schow score for 0.8
        %%%% show break until pressed space
        switch pscr
            case 0
                Screen('FrameRect', video.window, black, cupframe_rect, 4);
            case 1
                Screen('FrameRect', video.window, black, cupframe_rect, 4);
                Screen('DrawTexture', video.window, cuptext, [], cuppos(1,:));
            case 2
                Screen('FrameRect', video.window, black, cupframe_rect, 4);
                Screen('DrawTexture', video.window, cuptext, [], cuppos(1,:));
                Screen('DrawTexture', video.window, cuptext, [], cuppos(2,:));
            case 3
                Screen('FrameRect', video.window, black, cupframe_rect, 4);
                Screen('DrawTexture', video.window, cuptext, [], cuppos(1,:));
                Screen('DrawTexture', video.window, cuptext, [], cuppos(2,:));
                Screen('DrawTexture', video.window, cuptext, [], cuppos(3,:));
        end
        line1 = sprintf('This is the end of this block, thanks!\n');
        line2 = sprintf(['TAKE A BREAK !\n When...' ...
            ' you are ready to continue,\n call the experimenter.\n']);
        if french
            line1 = sprintf('C''est la fin de ce bloc, bravo !\n');
            % line2 = sprintf(['PRENEZ UNE PAUSE !\n Quand vous...' ...
            %     ' \0352tes pr\0352t-e \0340 continuer,\nallez chercher l''exp\0351rimentateur.\n']);
            line2 = sprintf(['PRENEZ UNE PAUSE !\n Quand vous...' ...
                ' %ctes pr%c-t%c %c continuer,\nallez chercher l''exp%crimentateur.\n'], ...
                234, 234, 224, 224, 233);
        end
        DrawFormattedText(video.window, line1, 'center', video.screenYpixels * 0.25, black);
        DrawFormattedText(video.window, line2, 'center', video.screenYpixels * 0.75, black);
        Screen('DrawingFinished', video.window);
        vbl = Screen('Flip', video.window, nextfliptime);
        nextfliptime = vbl+fx_roundfp(0.3,0,video.ifi);
        pause(0.5)
        if video.eyelink.eyeON
            msg = sprintf('BLOCK_end_%03d', iblock);
            Eyelink('Message', msg);
        end
        if video.eeg.eegON
           IOPort('Write', com1, uint8(252));
        end

        if ~autopilot
            WaitKeyPress(spaceKey);
        end
        
    end %FOR EACH BLOCK IN EXPRUN STRUCTURE
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %% DRAW FINAL THANK YOU SCREEN
    % line = sprintf('Merci d''avoir particip\0351, l''exp\0351rience est finie !\n\n\n');    
    line = sprintf('END OF THE BLOCK %.f/%.f!\n', iblock, nblocks);
    endline = 'FINISH -- [space] -- FINISH';
    if french
        line = sprintf('FIN DU BLOC %.f/%.f !\n', iblock, nblocks);
        endline = 'TERMINER -- [espace] -- TERMINER';
    end
    DrawFormattedText(video.window, [line endline], 'center', video.yCenter, black);
    Screen('DrawingFinished', video.window);
    Screen('Flip', video.window, nextfliptime);
    RestrictKeysForKbCheck(spaceKey);
    if ~autopilot
        WaitKeyPress(spaceKey);
    end
    sca;
    
    % save PTB data
    header.end = char(datetime('now', 'Format', 'yyyyMMdd-HHmm'));
    header.aborted = 0;
    expout.header = header;
    expout.sampling = sampling;
    expout.final = final;
    expout.sqc = sqc;
    expout.video = video;
    save(sprintf('%s/%sexpout_S%02d_b%02d_%s.mat', subjdir, trainstr, subj, iblock, time_str),...
                'header', 'sampling', 'final', 'sqc', 'video', 'ME', 'pscr', 'avgscore');
    
    % close PTB
    Priority(0); FlushEvents; ListenChar(0); ShowCursor; Screen('CloseAll');
    Screen('Preference', 'SkipSyncTests', 0);%restore synch testing
    Screen('Preference','VisualDebuglevel',4);%restore warning verbosity
    Screen('Preference','SuppressAllWarnings',0);%=1 == warning verbosity=0
    RestrictKeysForKbCheck([]);
    if video.eeg.eegON
        IOPort('CloseAll')
    end
    fprintf('\n...fx_run_expe OVER AND OUT...\n');
    % diary off;
end % function end
