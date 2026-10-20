function [mch,mfc,mfq,mvopt,mcopt,mxc,xc_out] = sim_modelbound_noisyleaky_3bags(betav,betac,betar,theta,omega,gamma,delta_c,delta_u,sigma,cfg)
    
    if ~isfield(cfg,'leakrule')
        cfg.leakrule = 'post';
    end

    if ~isfield(cfg,'shuffle')
        cfg.shuffle = false;
    end

    if ~isfield(cfg,'same1st')
        cfg.same1st = false;
    end

    if ~isfield(cfg,'fix1st')
        cfg.fix1st = false;
    end

    if cfg.same1st
        cfg.fix1st = false;
    end

    if cfg.fix1st
        cfg.same1st = false;
    end

    nseq = length(cfg.choices);
    cfac = cfg.cfac;
    % simulate model choices
    mch = cell(nseq,1);
    mfc = nan(nseq,1);
    mfq = nan(nseq,1);
    mxc = cell(nseq,1);
    mvopt = cell(nseq,1);
    mcopt = cell(nseq,1);
    xc_out = cell(nseq,1);

    nopt = 3;
    
    for iseq = 1:nseq
        nsmp = numel(cfg.choices{iseq});
        mch{iseq} = nan(1,nsmp);
        xc = nan(nsmp,nopt);
        bc = true(1,nopt);
        xc(1,:) = 0;
        if theta == 0
            bc(:) = false;
        end
        if cfg.same1st
            mch{iseq}(1) = cfg.choices{iseq}(1);
        elseif cfg.fix1st
            mch{iseq}(1) = cfg.fix1st;
        else
            mch{iseq}(1) = randi(nopt);
        end
        
        % randomize sample order
        colorv = cfg.colorop{iseq};
        if cfg.shuffle
            colorv = colorv(:,randsample(nsmp,nsmp));
        end

        for ismp = 2:nsmp
            % update beliefs
            ch = mch{iseq}(ismp-1);
            un = 1:nopt; un(ch) = []; % unchosen

            switch cfg.leakrule
                case 'pre'
                xc(ismp,ch) = (1-delta_c)*xc(ismp-1,ch)+colorv(ch,ismp-1)*cfac+randn*sigma;
                xc(ismp,un) = (1-delta_u)*xc(ismp-1,un);
                otherwise
                xc(ismp,ch) = xc(ismp-1,ch)+colorv(ch,ismp-1)*cfac+randn*sigma;
                xc(ismp,un) = xc(ismp-1,un);
                xc(ismp,ch) = (1-delta_c)*xc(ismp,ch);
                xc(ismp,un) = (1-delta_u)*xc(ismp,un);
            end

            % update bound
            if bc(ch) == true
                if gamma == 0 % fixed bound
                    xt = theta;
                else % variable bound
                    xt = gamrnd(theta^2/gamma^2,gamma^2/theta);
                end
                bc(ch) = abs(xc(ismp,ch)) < xt;
            end

            % compute utility:
            utility = betav*xc(ismp,:)*cfg.targetc(iseq);
            utility = utility - betac*abs(xc(ismp,:));
            utility(:,ch) = utility(:,ch) + betar * (nopt-1)/nopt;
            utility(:,un) = utility(:,un) - betar/nopt;

            utility = utility - max(utility,[],2);
            exp_u = exp(utility);
            pc_softmax = exp_u ./ sum(exp_u,2);

            % compute choice probability
            pc = zeros(1,nopt);
            if bc(ch) == true
                pc(ch) = omega;
                pc(un) = (1-omega)/(nopt-1);
            else
                if betac > 100
                    u = utility(:); 
                    umax = max(u);
                    ismax = (u == umax); 
                    pc = double(ismax) / sum(ismax);
                    pc = reshape(pc, size(utility));
                else
                    pc = pc_softmax;
                end
            end
            % simulate a choice
            % mch{iseq}(ismp) = 1+(pc(1) < rand);
            mch{iseq}(ismp) = find(rand <= cumsum(pc), 1, 'first');
            % update the bound
            ch_prv = ch;
            ch_cur = mch{iseq}(ismp);
            if ch_cur ~= ch_prv
                bc(ch_prv) = false;
            end
        end

        % update beliefs for final question 
        ismp = nsmp + 1; % out of sample, final question
        ch = mch{iseq}(ismp-1);
        un = 1:nopt; un(ch) = []; % unchosen
        switch cfg.leakrule
            case 'pre'
            xc(ismp,ch) = (1-delta_c)*xc(ismp-1,ch)+colorv(ch,ismp-1)*cfac+randn*sigma;
            xc(ismp,un) = (1-delta_u)*xc(ismp-1,un);
            otherwise
            xc(ismp,ch) = xc(ismp-1,ch)+colorv(ch,ismp-1)*cfac+randn*sigma;
            xc(ismp,un) = xc(ismp-1,un);
            xc(ismp,ch) = (1-delta_c)*xc(ismp,ch);
            xc(ismp,un) = (1-delta_u)*xc(ismp,un);
        end

        if ~isfield(cfg,'latent')
            latent = sign(sum(colorv,2))';
        else
            latent = cfg.latent(iseq,:);
        end

        xe = xc(end,:);
        % in the direction of real color state:
        n = size(xe,1);
        xe = repmat(latent,n,1).*xe; % state-aligned evidence
        mfq(iseq,:) = xe(end,1);

        xe = xc(2:end,:);
        n = size(xe,1);
        xe = repmat(latent,n,1).*xe;
        xe = xe(:,1);
        mxc{iseq} = xe';

        xc_out{iseq} = xc;

    end

end

