function bounds = SmallestTextBounds(w,text)
%  SMALLESTTEXTBOUNDS  Compute smallest bounding box around text
%
%  Usage: bounds = SmallestTextBounds(w,text)
%
%  w      - scratch window (preferably offscreen)
%  text   - text string
%  bounds - smallest bounding box around text
%
%  Font name, size and style need to be defined for scratch window w before
%  calling this function (otherwise default values will be used).
%
%  Valentin Wyart <valentin.wyart@ens.fr>

% clear scratch window to background color black
Screen('FillRect',w,0);

% draw text string in white, with the top-left corner in top-left corner of window
Screen('DrawText',w,text,0,0,1,[],0);

% read back only one-color channel for efficiency reasons
img = Screen('GetImage',w,[],'backBuffer',0,1);

% search non-background pixels
[y,x] = find(img(:,:));

% compute their bounding rectangle and return it
if isempty(y) || isempty(x)
    bounds = [0,0,0,0];
else
    bounds = [min(x)-1,min(y)-1,max(x),max(y)];
end

end