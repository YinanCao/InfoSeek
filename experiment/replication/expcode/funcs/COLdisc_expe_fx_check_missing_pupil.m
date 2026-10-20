function [video] = COLdisc_expe_fx_check_missing_pupil(video, iblock)
% CHECK_MISSING_PUPIL  Check for missing pupil online during experiment
%
% Requires initiating the eyelink w listening to the link:
%       Eyelink('Command','link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK');
%       Eyelink('Command','link_sample_data = GAZE,AREA');
% Requires the video.eyelink structure to have a tolerancebox field around fixation pt
%
% NB: the link has a 3ms lag: samples are available to stim
% computer 3ms after physical event.
% fsample structure has fields with time, gaze positions, pupil
% size or area (pa), pupil positions etc...
% pa is pupile size/area field in arbitrary units (area or diameter),
% depending on pre-specification => should be positive, else
% no pupil detected.
%
% gy and gx = gaze x and y, corrected by EL for distance to display
% they're in display coordinates (so in px) = (0,0) top left by default.
%
% (eye_used+1 is "bc accesses matlab array" - from the Eyelink manual...)

if Eyelink('NewFloatSampleAvailable') > 0 % 1 if new sample is available from EL
    evt = Eyelink('NewestFloatSample'); % -1 if no sample or error
    
    % check pupil status:
    if evt.pa(video.eyelink.eyeused+1) <= 0 % if no pupil detected, count as missing pupil:
        video.eyelink.nmiss(iblock) = video.eyelink.nmiss(iblock)+(evt.pa(video.eyelink.eyeused+1) <= 0);
    elseif evt.pa(video.eyelink.eyeused+1) > 0 % if pupil, check fixation:
        % get gaze pos:
        gx = evt.gx(video.eyelink.eyeused+1);
        gy = evt.gy(video.eyelink.eyeused+1);
        % check if gaze is within tolerable rectangle around fixpt:
        video.eyelink.nout(iblock)  = video.eyelink.nout(iblock) + ~(IsInRect(gx, gy, video.eyelink.tolerancebox));
        % adds the "not in rect" samples = counts samples out of tolerance window
    end
    
    % count overall nb of samples checked:
    video.eyelink.nevt(iblock)  = video.eyelink.nevt(iblock)+1;
    
end% if newsample

end% function definition


