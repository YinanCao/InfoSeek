% draw fixation cross
Rotated_fixation(video.window,video.fix_rect,video.xCenter,video.yCenter,[0,0,0],[0,90]);
Screen('FillOval',video.window,[1,1,1],CenterRectOnPointd([0 0 lineWidthPix lineWidthPix],video.xCenter,video.yCenter));