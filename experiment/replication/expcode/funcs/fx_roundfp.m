function [t] = fx_roundfp(t,dt,videoifi)
% apply duration rounding policy for video flips
% where t  - desired (input)/rounded (output) duration (Cle:in secs??)
%       dt - desired uniform jitter on duration (default: none)
%       videoifi - Cle: interframeinterval
n = round(t/videoifi); % nb of frames in t duration
% apply uniform jitter
if nargin > 1 && dt > 0
    m = round(dt/videoifi);
    n = n+ceil((m*2+1)*rand)-(m+1);
end
% convert frames to duration
t = (n-0.5)*videoifi; % convert back to frames, but 0.5 frames before total duration
end