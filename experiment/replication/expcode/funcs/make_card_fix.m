function [img, rgb_val] = make_card_fix(cfg)
    %  MAKE_CARD  Make card
    %
    %  Usage: [img] = MAKE_CARD(cfg)
    %
    %  This worker function should not be called directly unless you know what you
    %  are doing. It is used by the run_expe() function.
    %
    %  Valentin Wyart <valentin.wyart@ens.fr> - 09/2015
    %  Yinan Cao - 11/2024 added annulus functionality
    
    if nargin < 1
        error('Missing configuration structure!');
    end
    
    % check configuration structure
    if ~all(isfield(cfg,{'ppd','cardtype'}))
        error('Invalid configuration structure!');
    end
    if ~isfield(cfg,'angl')
        cfg.angl = [];
    end
    if ~isfield(cfg,'axis')
        cfg.axis = [];
    end
    % get required configuration parameters
    ppd       = cfg.ppd;
    cardtype  = cfg.cardtype;
    angl      = cfg.angl;
    axis      = cfg.axis;
    % set internal configuration parameters
    x         = cfg.disc_outerDim;
    innerdmtr = deg2pix(cfg.disc_innerDim,2);
    carddmtr  = deg2pix(x,2);
    cardwdth  = deg2pix(x/200,1);
    anglwdth  = deg2pix(x/60,1);
    lumibg    = cfg.lbgd;
    lumifg    = 128/255;
    opctfg    = 2/3;
    
    % showaxis = 0;
    % axiswdth = deg2pix(x/2/60,1);
    % set type-dependent configuration parameters
    switch cardtype
        case 0 % empty card
            axis     = 0;
            angl     = 0;
            opctfg   = 0;
            opctangl = 0;
        case 1 % mapping/response card
            if isempty(axis)
                error('Invalid configuration structure!');
            end
            angl     = 0;
            opctangl = 0;
        case 2 % flashing/blinking card
            if isempty(axis)
                error('Invalid configuration structure!');
            end
            angl     = 0;
            opctangl = 0;
        case 3 % angle card
            if isempty(axis) || isempty(angl)
                error('Invalid configuration structure!');
            end
            opctangl = 1;
        otherwise
            error('undefined card type!');
    end
    
    % define function handles
    fsmooth = @(x,r)r(1)+diff(r)./(1+99.^(-x)); % smoothing function
    % modzero = @(x,m)mod(x+m/2,m)-m/2; % zero-centered modulus
    
    % set outer diameter
    outrdmtr = carddmtr+4*cardwdth;
    % Blend two colors or patterns in a circular gradient:
    % set polar coordinates
    [x,y] = meshgrid((1:outrdmtr)-(outrdmtr+1)/2);
    r = sqrt(x.^2+y.^2);
    t = -atan2(y,x); % angle (in radians) for each point in the Cartesian grid
    % % relative to the origin
    % draw card foreground
    colrfg = COLdisc_cielab;
    p = 0.5*(1+sin(2*(t-axis)));
    patchfg = ...
        bsxfun(@times,  p,reshape(colrfg(1,:),1,1,[]))+ ...
        bsxfun(@times,1-p,reshape(colrfg(2,:),1,1,[]));
    patchfg = opctfg*patchfg+(1-opctfg)*lumifg;
    
    patchtp = ones(outrdmtr,outrdmtr);
    patchtp = min(patchtp,fsmooth(r-carddmtr/2+2,[1,0]));
    patchfg = bsxfun(@plus,bsxfun(@times,patchfg,patchtp),lumibg*(1-patchtp));
    
    % if showaxis % draw category boundaries?
    %     % primary boundary
    %     u = sin(axis)*x+cos(axis)*y;
    %     patchtp = ones(outrdmtr,outrdmtr);
    %     patchtp = min(patchtp,fsmooth(u+axiswdth/2,[0,1]));
    %     patchtp = min(patchtp,fsmooth(u-axiswdth/2,[1,0]));
    %     patchtp = min(patchtp,fsmooth(r-carddmtr/2+2,[1,0]));
    %     patchtp = patchtp*opctfg;
    %     patchfg = bsxfun(@plus,bsxfun(@times,patchfg,1-patchtp),lumibg*patchtp);
    %     % secondary boundary
    %     u = cos(axis)*x-sin(axis)*y;
    %     patchtp = ones(outrdmtr,outrdmtr);
    %     patchtp = min(patchtp,fsmooth(u+axiswdth/2,[0,1]));
    %     patchtp = min(patchtp,fsmooth(u-axiswdth/2,[1,0]));
    %     patchtp = min(patchtp,fsmooth(r-carddmtr/2+2,[1,0]));
    %     patchtp = patchtp*opctfg;
    %     patchfg = bsxfun(@plus,bsxfun(@times,patchfg,1-patchtp),lumibg*patchtp);
    % end
    
    % draw card angle
    u = sin(angl)*x+cos(angl)*y;
    patchtp = ones(outrdmtr,outrdmtr);
    patchtp = min(patchtp,fsmooth(u+anglwdth/2,[0,1]));
    patchtp = min(patchtp,fsmooth(u-anglwdth/2,[1,0]));
    patchtp = min(patchtp,fsmooth(r-carddmtr/2+2,[1,0]));
    patchtp = patchtp*opctangl;
    patchfg = bsxfun(@times,patchfg,1-patchtp);
    
    % draw card border
    patchtp = ones(outrdmtr,outrdmtr);
    patchtp = min(patchtp,fsmooth(r-carddmtr/2+cardwdth+2,[0,1]));
    patchtp = min(patchtp,fsmooth(r-carddmtr/2+2,[1,0]));
    patchfg = bsxfun(@times,patchfg,1-patchtp);
    
    outer_mask = fsmooth(r - carddmtr / 2 + 2, [1, 0]);  % Outer edge of the annulus
    inner_mask = fsmooth(innerdmtr / 2 - r, [1, 0]);     % Inner edge of the annulus
    patchtp = outer_mask .* inner_mask;
    patchfg = bsxfun(@plus,bsxfun(@times,patchfg,patchtp),lumibg*(1-patchtp));
    
    % return image
    img = patchfg;
 
    rgb_val = [];
    if ~isempty(axis) && ~isempty(angl) && cardtype==3
        p       = 0.5*(1+sin(2*(cfg.angl-cfg.axis))); % Proportion of the first color
        rgb_fg  = p*colrfg(1,:) + (1-p)*colrfg(2,:);
        rgb_val = opctfg*rgb_fg + (1-opctfg)*lumifg;
    end
    
    function [p] = deg2pix(d,b)
        p = d*ppd;
        if nargin > 1 && b > 0
            % Ensures p is at least 1 pixel, preventing p from becoming zero.
            % Rounds the size p to the nearest multiple of b
            p = max(round(p/b),1)*b;
        end
    end

end
