function Rotated_fixation(window, fix_rect, center_x, center_y, Color, Angle)
Screen('glPushMatrix', window);
Screen('glTranslate',  window, center_x, center_y);
Screen('glRotate',     window, Angle(1), 0, 0);
Screen('glTranslate',  window, -center_x, -center_y);
Screen('FillRect',     window, Color, CenterRectOnPoint(fix_rect, center_x, center_y));
Screen('glPopMatrix',  window);
Screen('glPushMatrix', window);
Screen('glTranslate',  window, center_x, center_y);
Screen('glRotate',     window, Angle(2), 0, 0);
Screen('glTranslate',  window, -center_x, -center_y);
Screen('FillRect',     window, Color, CenterRectOnPoint(fix_rect, center_x, center_y));
Screen('glPopMatrix',  window);
end