function [out] = fit_modelbound_noisyleaky_comleak(cfg)
% 31/07/2025: leak prior beta(1,9)
% particle filter -> end of loop

% check input arguments
if ~isfield(cfg,'fitalgo')
    cfg.fitalgo = 'bads';
end
if ~isfield(cfg,'nrun')
    cfg.nrun = 1;
end
if ~isfield(cfg,'nsim')
    cfg.nsim = 1;
end
if ~isfield(cfg,'verbose')
    cfg.verbose = 2;
end
if ~isfield(cfg,'leakrule')
    cfg.leakrule = 'post';
end

% get fitting parameters
fitalgo = cfg.fitalgo; % fitting algorithm (bads or vbmc)
noprior = cfg.noprior; % ignore priors?
npft    = cfg.npft;    % number of samples used by particle filter
nres    = cfg.nres;    % number of bootstrap/validation resamples
nrun    = cfg.nrun;    % number of random starting points (fitalgo = bads)
verbose = cfg.verbose; % fitting display level

% set fitting parameters
epsi = 1e-6; % infinitesimal response probability
cfac = get_cfac(1/3); % get color-to-evidence factor

% define logit and sigmoid functions
logit = @(x)log(x./(1-x));
sigmd = @(x)1./(1+exp(-x));

% get number of sequences
nseq = numel(cfg.choices);

if cfg.conditn == 2
    % do not fit sensitivity to value
    cfg.betav = 0;
end

if isfield(cfg,'theta') && cfg.theta == 0
    % do not fit other bound parameters
    cfg.omega = 0;
    cfg.gamma = 0;
end

% define model parameters
npar = 8;
pnam = cell(npar,1); % name
pfun = cell(npar,1); % prior function
pini = nan(npar,1);  % initial value
pmin = nan(npar,1);  % lower bound
pmax = nan(npar,1);  % upper bound
pplb = nan(npar,1);  % plausible lower bound
ppub = nan(npar,1);  % plausible upper bound

% betav = sensitivity to value ~ normal(0,2)
pnam{1} = 'betav';
pini(1) = 0;
pmin(1) = -10;
pmax(1) = +10;
pplb(1) = -4;
ppub(1) = +4;
pfun{1} = @(x)normpdf(x,0,2);

% betac = sensitivity to certainty ~ normal(0,2)
pnam{2} = 'betac';
pini(2) = 0;
pmin(2) = -10;
pmax(2) = +10;
pplb(2) = -4;
ppub(2) = +4;
pfun{2} = @(x)normpdf(x,0,2);

% betar = repetition bias ~ normal(0,2)
pnam{3} = 'betar';
pini(3) = 0;
pmin(3) = -10;
pmax(3) = +10;
pplb(3) = -4;
ppub(3) = +4;
pfun{3} = @(x)normpdf(x,0,2);

% theta = bound level ~ logit(uniform(0.5,1))
pnam{4} = 'theta';
pini(4) = logit(0.8);
pmin(4) = 0;
pmax(4) = 10;
pplb(4) = 0.1;
ppub(4) = 5;
pfun{4} = @(x)unifpdf(sigmd(x),0.5,1).*sigmd(x).*(1-sigmd(x));

% omega = bound hardness ~ beta(4,1)
pnam{5} = 'omega';
pini(5) = 0.8;
pmin(5) = 0;
pmax(5) = 1;
pplb(5) = 0.1;
ppub(5) = 0.9;
pfun{5} = @(x)betapdf(x,4,1);

% gamma = bound standard deviation ~ exp(0.1)
pnam{6} = 'gamma';
pini(6) = 0.1;
pmin(6) = 0.001;
pmax(6) = 1;
pplb(6) = 0.01;
ppub(6) = 0.5;
pfun{6} = @(x)exppdf(x,0.1);

% decay rate ~ beta(1,9)
pnam{7} = 'delta';
pmin(7) = 0;
pmax(7) = 1;
pini(7) = 0.1;
pplb(7) = 0.01;
ppub(7) = 0.5;
pfun{7} = @(x)betapdf(x,1,9);

% learning noise
pnam{8} = 'sigma';
pmin(8) = 0;
pmax(8) = 10;
pini(8) = 1;
pplb(8) = 0.1;
ppub(8) = 5;
pfun{8} = @(x)exppdf(x,1);

if noprior
    % ignore priors
    pfun = cell(npar,1);
end

% apply user-defined initialization values
if isfield(cfg,'pini')
    for i = 1:npar
        if isfield(cfg.pini,pnam{i}) && ~isnan(cfg.pini.(pnam{i}))
            pini(i) = cfg.pini.(pnam{i});
            % clamp initialization value within plausible bounds
            pini(i) = min(max(pini(i),pplb(i)+epsi),ppub(i)-epsi);
        end
    end
end

% define fixed parameters
pfix = cell(1,npar);
for i = 1:npar
    if isfield(cfg,pnam{i}) && ~isempty(cfg.(pnam{i}))
        pfix{i} = min(max(cfg.(pnam{i}),pmin(i)),pmax(i));
    end
end

% define free parameters
ifit = cell(1,npar);
pfit_ini = [];
pfit_min = [];
pfit_max = [];
pfit_plb = [];
pfit_pub = [];
n = 1;
for i = 1:npar
    if isempty(pfix{i}) % free parameter
        ifit{i} = n;
        pfit_ini = cat(2,pfit_ini,pini(i));
        pfit_min = cat(2,pfit_min,pmin(i));
        pfit_max = cat(2,pfit_max,pmax(i));
        pfit_plb = cat(2,pfit_plb,pplb(i));
        pfit_pub = cat(2,pfit_pub,ppub(i));
        n = n + 1;
    end
end

nfit = numel(pfit_ini);
nobs = sum(cellfun(@length,cfg.choices));

idx = find(contains(pnam, 'sigma'));
isnoisy = any(arrayfun(@(i) isempty(pfix{i}) || pfix{i} > 0, idx));

if nfit > 0
    % set display level
    switch cfg.verbose
        case 0, opt_disp = 'none';
        case 1, opt_disp = 'final';
        case 2, opt_disp = 'iter';
    end

    if ~exist(lower(cfg.fitalgo),'file')
        error('%s not found in path!',lower(cfg.fitalgo));
    end
    
    switch lower(cfg.fitalgo)
        
        case 'bads'
            
            % fit model using Bayesian Adaptive Direct Search
            if ~exist('bads','file')
                error('BADS missing from path!');
            end
            
            % do not use priors
            warning('Disabling the use of priors when using BADS.');
            pfun = cell(npar,1); % redundant but ensure no prior

            % configure BADS
            options = bads('defaults');
            options.UncertaintyHandling = isnoisy; % noisy objective function
            options.NoiseFinalSamples = nres; % number of samples
            switch verbose % display level
                case 0, options.Display = 'none';
                case 1, options.Display = 'final';
                case 2, options.Display = 'iter';
            end
            
            % fit model using multiple random starting points
            fval   = nan(1,nrun);
            xhat   = cell(1,nrun);
            output = cell(1,nrun);

            num_free_params = sum(cellfun(@isempty, pfix));

            for irun = 1:nrun
                done = false;
                while ~done
                    % set random starting point
                    pfit_ini = nan(1,num_free_params); % Preallocate
                    n = 1;
                    for i = 1:npar
                        if isempty(pfix{i}) % free parameter
                            % sample starting point uniformly between plausible bounds
                            pfit_ini(n) = unifrnd(pplb(i),ppub(i));
                            n = n+1;
                        end
                    end
                    % fit model using BADS
                    [xhat{irun},fval(irun),exitflag,output{irun}] = ...
                        bads(@(x)getnl(x),pfit_ini,pfit_min,pfit_max,pfit_plb,pfit_pub,[],options);
                    if exitflag > 0
                        done = true;
                    end
                end
            end
            % find best fit among random starting points
            [~,irun] = min(fval);
            xhat = xhat{irun};
            output = output{irun};
            
            % get best-fitting values
            phat = getpval(xhat);
            
            % create output structure with best-fitting values
            out = cell2struct(phat(:),pnam(:));
            
            % store fitting information
            out.fitalgo = fitalgo; % fitting algorithm
            out.npft    = npft;    % number of samples used by particle filter
            out.nres    = nres;    % number of validation resamples
            out.nrun    = nrun;    % number of random starting points
            out.nobs    = nobs;    % number of trials
            out.nfit    = nfit;    % number of fitted parameters
            
            % get maximum log-likelihood
            out.ll = -output.fval; % estimated log-likelihood
            out.ll_sd = output.fsd; % estimated s.d. of log-likelihood
            
            % get complexity-penalized fitting metrics
            out.aic = -2*out.ll+2*nfit+2*nfit*(nfit+1)/(nobs-nfit+1); % AIC
            out.bic = -2*out.ll+nfit*log(nobs); % BIC
            
            % get parameter values
            out.xnam = pnam(cellfun(@isempty,pfix));
            out.xhat = xhat;
            
            % store additional output from BADS
            out.output = output;
            
        case 'vbmc'

            % configure VBMC
            options = vbmc('defaults');
            options.MaxIter = 500; % maximum number of iterations
            options.MaxFunEvals = 500; % maximum number of function evaluations
            options.SpecifyTargetNoise = isnoisy; % noise-free log-posterior function
            options.Display = opt_disp; % display level
            
            % fit model
            [vp,elbo,~,~,output] = vbmc(@(x)getlp(x),pfit_ini,pfit_min,pfit_max,pfit_plb,pfit_pub,options);
            
            % generate 10^6 samples from the variational posterior
            xsmp = vbmc_rnd(vp,1e6);
            
            % get sample statistics
            xmap = vbmc_mode(vp); % posterior mode
            xavg = mean(xsmp,1); % posterior mean
            xstd = std(xsmp,[],1); % posterior s.d.
            xcov = cov(xsmp); % posterior covariance matrix
            xmed = median(xsmp,1); % posterior medians
            xqrt = quantile(xsmp,[0.25,0.75],1); % posterior 1st and 3rd quartiles
            
            % get full parameter set with best-fitting values
            phat_map = getpval(xmap); % posterior mode
            phat_avg = getpval(xavg); % posterior mean
            
            % use posterior mode as default
            phat = phat_map;
            
            % create output structure
            out = cell2struct(phat(:),pnam(:));
            
            % create substructure with posterior mode
            out.pmap = cell2struct(phat_map(:),pnam(:));
            
            % create substructure with posterior mean
            out.pavg = cell2struct(phat_avg(:),pnam(:));
            
            % store fitting information
            out.fitalgo = fitalgo; % fitting algorithm
            out.npft    = npft;    % number of samples used by particle filter
            out.nres    = nres;    % number of bootstrap resamples
            out.nobs    = nobs;    % number of trials
            out.nfit    = nfit;    % number of fitted parameters
            
            % store variational posterior solution
            out.vp = vp;
            
            % get ELBO (expected lower bound on log-marginal likelihood)
            out.elbo = elbo; % estimate
            out.elbo_sd = output.elbo_sd; % standard deviation
            
            % get maximum log-posterior and maximum log-likelihood
            out.lp = getlp(xmap); % log-posterior
            out.ll = getll(phat_map{:}); % log-likelihood
            
            % get parameter values
            out.xnam = pnam(cellfun(@isempty,pfix)); % fitted parameters
            out.xmap = xmap; % posterior mode
            out.xavg = xavg; % posterior mean
            out.xstd = xstd; % posterior s.d.
            out.xcov = xcov; % posterior covariance matrix
            out.xmed = xmed; % posterior median
            out.xqrt = xqrt; % posterior 1st and 3rd quartiles
            
        otherwise
            error('Undefined fitting algorithm!');
    
    end
    
    % store extra information
    out.out = output; % output structure
    out.cfg = cfg; % configuration structure
    
else % nfit = 0
    % use fixed parameter values
    phat = getpval([]);
    % create output structure
    out = cell2struct(phat(:),pnam(:));
end

% get model predictions: 
[~,out.pt_avg,out.vopt,out.copt,out.mcol] = getp(phat{:});

% store extra information
out.cfg = cfg; % configuration structure
%%
function [pval] = getpval(p)
    % get parameter values
    pval = cell(1,npar);
    for k = 1:npar
        if isempty(pfix{k}) % free parameter
            pval{k} = p(ifit{k});
        else % fixed parameter
            pval{k} = pfix{k};
        end
    end
end
%% get -ll for bads fitting
function [nl] = getnl(p)
    % get parameter values
    pval = getpval(p);
    % get negative log-likelihood
    nl = -getll(pval{:});
end
%% vbmc fitting
function [lp,lp_sd] = getlp(p) % pfun priors
    % get parameter values
    pval = getpval(p);
    % get log-prior
    l0 = 0;
    for k = 1:npar
        if isempty(pfix{k}) % free parameter
            if isempty(pfun{k}) % use uniform prior
                l0 = l0+log(unifpdf(pval{k},pmin(k),pmax(k)));
            else % use specified prior
                l0 = l0+log(pfun{k}(pval{k}));
            end
        end
    end
    % get log-likelihood
    [ll,ll_sd] = getll(pval{:});
    % get log-posterior
    lp = ll+l0; % estimate
    lp_sd = ll_sd; % bootstrap s.d.
end

function [ll,ll_sd] = getll(varargin)
    % compute response probability
    pseq    = getp(varargin{:});
    ll      = nan(nseq,1);
    lsumres = nan(nres,nseq);
    for iseq = 1:nseq
        p = pseq{iseq};
        resp = cfg.choices{iseq};
        if nargout > 1
            % compute log-likelihood s.d.
            lres = nan(nres,1);
            for ires = 1:nres
                jres = randsample(npft,npft,true);
                pres = mean(p(:,:,jres),3);
                pres = adjust_probabilities_matrix(pres, epsi);
                pc   = [];
                for k = size(pres,1):-1:1
                    pc(k,1) = pres(k,resp(k)); % chosen
                end
                lres(ires) = sum(log(pc));
            end
            lsumres(:,iseq) = lres;
        end
        % compute log-likelihood
        p  = mean(p,3);
        p  = adjust_probabilities_matrix(p, epsi);
        pc = [];
        for k = size(p,1):-1:1
            pc(k,1) = p(k,resp(k)); % chosen
        end
        ll(iseq) = sum(log(pc));
    end
    ll = sum(ll);
    % sum across seq, then std across bootstraps
    ll_sd = max(std(sum(lsumres,2)),1e-6);
end
%% 
function [pt_seq,pt_avg,vopt,copt,mcol] = getp(betav,betac,betar,theta,omega,gamma,delta,sigma)

    mcol = cell(nseq,1); % filtered posterior means
    vopt = cell(nseq,1); % target-directed choice fraction
    copt = cell(nseq,1); % uncertainty-directed choice fraction
    pt_seq = cell(nseq,1); % model p
    pt_avg = cell(nseq,1); % model p mean (across filters)
    
    for iseq = 1:nseq
        
        nsmp = numel(cfg.choices{iseq});
        xc = nan(nsmp,2,npft);
        pt = nan(nsmp,2,npft);
        wt = nan(nsmp,npft);   % filtering weights
        bc = true(1,2);
        if theta == 0
            bc(:) = false;
        end
        xc(1,:,:) = 0;
        pt(1,:,:) = 0.5;
        % initialize filtering noise and weights
        wt(1,:) = 1/npft;

        for ismp = 2:nsmp
            ch = cfg.choices{iseq}(ismp-1); % choice(t-1)
            un = 3-ch; % unchosen

            % update chosen v1:
            switch cfg.leakrule
                case 'pre'
                xc(ismp,ch,:) = (1-delta)*xc(ismp-1,ch,:)+cfg.colvals{iseq}(ch,ismp-1)*cfac;
                % add learning noise:
                xc(ismp,ch,:) = noisrnd(xc(ismp,ch,:),sigma);
                otherwise
                xc(ismp,ch,:) = xc(ismp-1,ch,:)+cfg.colvals{iseq}(ch,ismp-1)*cfac;
                xc(ismp,ch,:) = noisrnd(xc(ismp,ch,:),sigma);
                xc(ismp,ch,:) = (1-delta)*xc(ismp,ch,:);
            end

            % unchosen:
            xc(ismp,un,:) = (1-delta)*xc(ismp-1,un,:);

            % compute decision variable:
            dv = betav*(xc(ismp,1,:)-xc(ismp,2,:))*cfg.targetc(iseq);
            dv = dv-betac*(abs(xc(ismp,1,:))-abs(xc(ismp,2,:)));
            dv = dv+betar*(3-2*ch);
            if bc(ch) == true
                if gamma == 0
                    pinb = abs(xc(ismp,ch,:)) < theta;
                else
                    pinb = 1-gamcdf(abs(xc(ismp,ch,:)),theta^2/gamma^2,gamma^2/theta);
                end
                pinb = squeeze(pinb);
                pc_inb = nan(npft,2);
                pc_inb(:,ch) = omega;
                pc_inb(:,un) = 1-omega;
                pc_out = nan(npft,2);
                pc_out(:,1) = 1./(1+exp(-dv));
                pc_out(:,2) = 1-pc_out(:,1);
                pp = bsxfun(@times,pc_inb,pinb)+bsxfun(@times,pc_out,(1-pinb));
                pt(ismp,:,:) = permute(pp,[3,2,1]);
            else
                pt(ismp,1,:) = 1./(1+exp(-dv)); % probability of choosing option 1
                pt(ismp,2,:) = 1-pt(ismp,1,:);  % probability of choosing option 2
            end
            % compute filtering weights:
            % [The weight of each particle is updated to reflect how well it predicts the observed behavior;
            % Particles that better predict the response get higher weights, 
            % and those that predict the wrong response get lower weights.]
            wt(ismp,:) = squeeze(pt(ismp,cfg.choices{iseq}(ismp),:));
            if nnz(wt(ismp,:)) == 0
                wt(ismp,:) = 1/npft; % if all weights are zero, uniform weights are assigned (1/nsmp)
            else
                wt(ismp,:) = wt(ismp,:)/sum(wt(ismp,:)); % normalized to prevent numerical instability
            end
            % update the bound
            ch_prv = ch;
            ch_cur = cfg.choices{iseq}(ismp);
            if ch_cur ~= ch_prv % if subj's choice changes
                % then it means they had exited the initial phase
                bc(ch_prv) = false;
            end
            % RESAMPLE particles:
            xc(ismp,:,:) = xc(ismp,:,randsample(npft, npft, true, wt(ismp,:)));
        end
        
        mt_avg = sum(bsxfun(@times,xc,reshape(wt,[nsmp,1,npft])),3);
        mcol{iseq} = mt_avg; % save

        % compute vopt and copt choices for participants:
        [~, tempopt] = max(mt_avg*cfg.targetc(iseq),[],2);
        vopt{iseq} = [cfg.choices{iseq} == tempopt' nan(1, 20-size(cfg.choices{iseq},2))];
        [~, tempopt] = min(abs(mt_avg),[],2);
        copt{iseq} = [cfg.choices{iseq} == tempopt' nan(1, 20-size(cfg.choices{iseq},2))];
        
        pt_seq{iseq}  = pt;
        pt_avg{iseq}  = mean(pt,3);
        
    end % end of seq loop
end % end getp

end % end fitting function

%%
function p_adjusted = adjust_probabilities_matrix(p, epsi)
    % Create a mask for NaN entries
    nan_mask = isnan(p);
    % Calculate the number of valid (non-NaN) entries in each row
    valid_counts = sum(~nan_mask, 2);
    % Adjust the probabilities using vectorized operations
    p_adjusted = epsi + (1 - bsxfun(@times, valid_counts, epsi)) .* p;
    % Reapply the original NaN positions
    p_adjusted(nan_mask) = NaN;
end
%%
function [x] = noisrnd(m,s)
    if isscalar(s)
        s = s .* ones(size(m));
    end
    % Draw samples directly from the normal distribution
    x = normrnd(m, s);
end
%%
function [cfac] = get_cfac(perr)
    % get color-to-evidence factor
    x = -1:0.001:+1;
    cfac = fzero(@(b)trapz(x(x > 0),1./(1+exp(x(x > 0)*b))/trapz(x,1./(1+exp(x*b))))-perr,[0,10]);
end