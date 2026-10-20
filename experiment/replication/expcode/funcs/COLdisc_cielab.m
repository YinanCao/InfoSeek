function colrfg = COLdisc_cielab()

cielab = [65   54   53; 65   -6.6  -54]; % [orange; blue]
colrfg = applycform(cielab,makecform('lab2srgb'));

end