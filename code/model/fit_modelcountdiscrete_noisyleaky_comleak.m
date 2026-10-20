function out = fit_modelcountdiscrete_noisyleaky_comleak(cfg)
% Count-based alternative to fit_modelbound_noisyleaky_comleak.
%
% ncrit is treated as a genuinely discrete parameter.
%
% If cfg.ncrit is absent or empty, the function enumerates ncrit = 1,...,20
% and fits the remaining continuous parameters separately for each value.
%
% With BADS, the best ncrit is selected using profile likelihood.
%
% With VBMC, the posterior over ncrit and the model evidence marginalized
% across ncrit are computed using a uniform discrete prior.
%
% Complete parameter order:
%   1. betav
%   2. betac
%   3. betar
%   4. ncrit
%   5. omega
%   6. delta
%   7. sigma

%% Check input arguments

if ~isfield(cfg,'fitalgo') || isempty(cfg.fitalgo), cfg.fitalgo = 'bads'; end
if ~isfield(cfg,'nrun') || isempty(cfg.nrun), cfg.nrun = 1; end
if ~isfield(cfg,'nsim') || isempty(cfg.nsim), cfg.nsim = 1; end
if ~isfield(cfg,'verbose') || isempty(cfg.verbose), cfg.verbose = 2; end
if ~isfield(cfg,'leakrule') || isempty(cfg.leakrule), cfg.leakrule = 'post'; end
if ~isfield(cfg,'noprior') || isempty(cfg.noprior), cfg.noprior = false; end
if ~isfield(cfg,'ncrit_min') || isempty(cfg.ncrit_min), cfg.ncrit_min = 1; end
if ~isfield(cfg,'ncrit_max') || isempty(cfg.ncrit_max), cfg.ncrit_max = 20; end

cfg.ncrit_min = round(cfg.ncrit_min);
cfg.ncrit_max = round(cfg.ncrit_max);

if cfg.ncrit_min < 1, error('cfg.ncrit_min must be at least 1.'); end
if cfg.ncrit_max < cfg.ncrit_min, error('cfg.ncrit_max must be greater than or equal to cfg.ncrit_min.'); end
if ~isfield(cfg,'choices') || isempty(cfg.choices), error('cfg.choices is required.'); end
if ~isfield(cfg,'colvals') || isempty(cfg.colvals), error('cfg.colvals is required.'); end
if ~isfield(cfg,'targetc') || isempty(cfg.targetc), error('cfg.targetc is required.'); end
if ~isfield(cfg,'npft') || isempty(cfg.npft), error('cfg.npft is required.'); end
if ~isfield(cfg,'nres') || isempty(cfg.nres), error('cfg.nres is required.'); end
if ~isfield(cfg,'conditn') || isempty(cfg.conditn), error('cfg.conditn is required.'); end

%% Determine whether ncrit is fixed or free

if isfield(cfg,'ncrit') && ~isempty(cfg.ncrit)
    ncrit_is_free = false;
    ncrit_grid = round(cfg.ncrit);
    ncrit_grid = min(max(ncrit_grid,cfg.ncrit_min),cfg.ncrit_max);
else
    ncrit_is_free = true;
    ncrit_grid = cfg.ncrit_min:cfg.ncrit_max;
end

n_ncrit = numel(ncrit_grid);

%% Fit continuous parameters conditional on each ncrit

fit_by_ncrit = cell(1,n_ncrit);

for ik = 1:n_ncrit
    cfg_k = cfg;
    cfg_k.ncrit = ncrit_grid(ik);

    if cfg.verbose > 0 && ncrit_is_free
        fprintf('\n============================================================\n');
        fprintf('Fitting count model with ncrit = %d (%d of %d)\n',ncrit_grid(ik),ik,n_ncrit);
        fprintf('============================================================\n\n');
    end

    fit_by_ncrit{ik} = fit_fixed_ncrit(cfg_k);
end

%% Return directly when ncrit is fixed

if ~ncrit_is_free
    out = fit_by_ncrit{1};
    out.ncrit = ncrit_grid(1);
    out.ncrit_fixed = true;
    out.ncrit_grid = ncrit_grid;
    out.ncrit_best_index = 1;
    out.fit_by_ncrit = fit_by_ncrit;
    out.cfg = cfg;
    out.cfg.ncrit = ncrit_grid(1);
    return
end

%% Combine conditional fits when ncrit is free

switch lower(cfg.fitalgo)

    case 'bads'

        ll_ncrit = cellfun(@(x)x.ll,fit_by_ncrit);
        ll_sd_ncrit = cellfun(@(x)x.ll_sd,fit_by_ncrit);
        [~,ik_best] = max(ll_ncrit);

        out = fit_by_ncrit{ik_best};

        out.xnam_continuous = out.xnam;
        out.xhat_continuous = out.xhat;
        out.xhat_model_continuous = out.xhat_model;

        out.ncrit = ncrit_grid(ik_best);
        out.ncrit_fixed = false;
        out.ncrit_grid = ncrit_grid;
        out.ncrit_best_index = ik_best;
        out.ll_ncrit = ll_ncrit;
        out.ll_sd_ncrit = ll_sd_ncrit;

        out.nfit_continuous = out.nfit;
        out.nfit = out.nfit_continuous + 1;

        out.aic = -2*out.ll + 2*out.nfit + 2*out.nfit*(out.nfit+1)/(out.nobs-out.nfit+1);
        out.bic = -2*out.ll + out.nfit*log(out.nobs);

        [out.xnam,out.xhat_model] = get_complete_free_parameter_vector(out,cfg,true);
        out.xhat = out.xhat_model;

    case 'vbmc'

        elbo_ncrit = cellfun(@(x)x.elbo,fit_by_ncrit);
        elbo_sd_ncrit = cellfun(@(x)x.elbo_sd,fit_by_ncrit);

        logprior_ncrit = -log(n_ncrit)*ones(size(ncrit_grid));
        logjoint_ncrit = elbo_ncrit + logprior_ncrit;
        log_model_evidence = logsumexp_local(logjoint_ncrit);

        logpost_ncrit = logjoint_ncrit - log_model_evidence;
        post_ncrit = exp(logpost_ncrit);
        [~,ik_best] = max(post_ncrit);

        out = fit_by_ncrit{ik_best};

        out.vp_conditional = out.vp;
        out.elbo_conditional = out.elbo;
        out.elbo_sd_conditional = out.elbo_sd;

        out.xnam_continuous = out.xnam;
        out.xmap_continuous = out.xmap;
        out.xavg_continuous = out.xavg;
        out.xstd_continuous = out.xstd;
        out.xcov_continuous = out.xcov;
        out.xmed_continuous = out.xmed;
        out.xqrt_continuous = out.xqrt;

        out.ncrit = ncrit_grid(ik_best);
        out.ncrit_fixed = false;
        out.ncrit_grid = ncrit_grid;
        out.ncrit_best_index = ik_best;

        out.elbo_ncrit = elbo_ncrit;
        out.elbo_sd_ncrit = elbo_sd_ncrit;
        out.logprior_ncrit = logprior_ncrit;
        out.logpost_ncrit = logpost_ncrit;
        out.post_ncrit = post_ncrit;

        out.elbo = log_model_evidence;
        out.elbo_sd = sqrt(sum((post_ncrit.^2).*(elbo_sd_ncrit.^2)));

        out.ncrit_avg = sum(ncrit_grid.*post_ncrit);
        out.ncrit_std = sqrt(sum(((ncrit_grid-out.ncrit_avg).^2).*post_ncrit));
        out.ncrit_cdf = cumsum(post_ncrit);
        out.ncrit_ci95 = discrete_credible_interval(ncrit_grid,post_ncrit,0.95);

        out.nfit_continuous = out.nfit;
        out.nfit = out.nfit_continuous + 1;

        [out.xnam,out.xmap] = get_complete_free_parameter_vector(out,cfg,true);
        [~,out.xavg] = get_complete_free_parameter_vector(out,cfg,false);

        ncrit_position = find(strcmp(out.xnam,'ncrit'));
        if ~isempty(ncrit_position), out.xavg(ncrit_position) = out.ncrit_avg; end

        out.posterior_is_mixture = true;

    otherwise
        error('Undefined fitting algorithm: %s',cfg.fitalgo);
end

out.fit_by_ncrit = fit_by_ncrit;
out.cfg = cfg;
out.cfg.ncrit = [];

end

%% Fit model conditional on a fixed integer ncrit

function out = fit_fixed_ncrit(cfg)

fitalgo = cfg.fitalgo;
noprior = cfg.noprior;
npft = cfg.npft;
nres = cfg.nres;
nrun = cfg.nrun;
verbose = cfg.verbose;

epsi = 1e-6;
cfac = get_cfac(1/3);

nseq = numel(cfg.choices);
nobs = sum(cellfun(@numel,cfg.choices));

ncrit = round(cfg.ncrit);
ncrit = min(max(ncrit,cfg.ncrit_min),cfg.ncrit_max);

if cfg.conditn == 2, cfg.betav = 0; end

%% Define continuous model parameters

npar = 6;

pnam = cell(npar,1);
pfun = cell(npar,1);
pini = nan(npar,1);
pmin = nan(npar,1);
pmax = nan(npar,1);
pplb = nan(npar,1);
ppub = nan(npar,1);

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

% omega = repetition probability during count phase ~ beta(4,1)
pnam{4} = 'omega';
pini(4) = 0.8;
pmin(4) = 0;
pmax(4) = 1;
pplb(4) = 0.1;
ppub(4) = 0.9;
pfun{4} = @(x)betapdf(x,4,1);

% delta = decay rate ~ beta(1,9)
pnam{5} = 'delta';
pini(5) = 0.1;
pmin(5) = 0;
pmax(5) = 1;
pplb(5) = 0.01;
ppub(5) = 0.5;
pfun{5} = @(x)betapdf(x,1,9);

% sigma = learning noise ~ exponential(mean = 1)
pnam{6} = 'sigma';
pini(6) = 1;
pmin(6) = 0;
pmax(6) = 10;
pplb(6) = 0.1;
ppub(6) = 5;
pfun{6} = @(x)exppdf(x,1);

if noprior, pfun = cell(npar,1); end

%% Apply user-defined initial values

if isfield(cfg,'pini') && ~isempty(cfg.pini)
    for i = 1:npar
        if isfield(cfg.pini,pnam{i}) && ~isnan(cfg.pini.(pnam{i}))
            pini(i) = cfg.pini.(pnam{i});
            pini(i) = min(max(pini(i),pplb(i)+epsi),ppub(i)-epsi);
        end
    end
end

%% Define fixed parameters

pfix = cell(1,npar);

for i = 1:npar
    if isfield(cfg,pnam{i}) && ~isempty(cfg.(pnam{i}))
        pfix{i} = min(max(cfg.(pnam{i}),pmin(i)),pmax(i));
    end
end

%% Define free continuous parameters

ifit = cell(1,npar);
pfit_ini = [];
pfit_min = [];
pfit_max = [];
pfit_plb = [];
pfit_pub = [];
n = 1;

for i = 1:npar
    if isempty(pfix{i})
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

sigma_index = find(strcmp(pnam,'sigma'));
isnoisy = isempty(pfix{sigma_index}) || pfix{sigma_index} > 0;

%% Fit free continuous parameters

if nfit > 0

    switch verbose
        case 0
            opt_disp = 'none';
        case 1
            opt_disp = 'final';
        otherwise
            opt_disp = 'iter';
    end

    if ~exist(lower(fitalgo),'file'), error('%s not found in path!',lower(fitalgo)); end

    switch lower(fitalgo)

        case 'bads'

            if ~exist('bads','file'), error('BADS missing from path!'); end

            if any(~cellfun(@isempty,pfun)), warning('Disabling priors when using BADS.'); end
            pfun = cell(npar,1);

            options = bads('defaults');
            options.UncertaintyHandling = isnoisy;
            options.NoiseFinalSamples = nres;
            options.Display = opt_disp;

            fval = nan(1,nrun);
            xhat_all = cell(1,nrun);
            output_all = cell(1,nrun);

            num_free_params = sum(cellfun(@isempty,pfix));

            for irun = 1:nrun
                done = false;

                while ~done
                    pfit_start = nan(1,num_free_params);
                    n = 1;

                    for i = 1:npar
                        if isempty(pfix{i})
                            pfit_start(n) = unifrnd(pplb(i),ppub(i));
                            n = n + 1;
                        end
                    end

                    [xhat_all{irun},fval(irun),exitflag,output_all{irun}] = bads(@getnl,pfit_start,pfit_min,pfit_max,pfit_plb,pfit_pub,[],options);

                    if exitflag > 0, done = true; end
                end
            end

            [best_fval,irun_best] = min(fval);
            xhat = xhat_all{irun_best};
            output = output_all{irun_best};
            phat = getpval(xhat);

            out = cell2struct(phat(:),pnam(:));
            out.ncrit = ncrit;

            out.fitalgo = fitalgo;
            out.npft = npft;
            out.nres = nres;
            out.nrun = nrun;
            out.nobs = nobs;
            out.nfit = nfit;
            out.ll = -best_fval;

            if isfield(output,'fsd') && ~isempty(output.fsd)
                out.ll_sd = output.fsd;
            else
                [~,out.ll_sd] = getll(phat{:});
            end

            out.aic = -2*out.ll + 2*nfit + 2*nfit*(nfit+1)/(nobs-nfit+1);
            out.bic = -2*out.ll + nfit*log(nobs);

            out.xnam = pnam(cellfun(@isempty,pfix));
            out.xhat = xhat;
            out.xhat_model = cell2mat(phat(cellfun(@isempty,pfix)));

            out.output = output;
            out.all_fval = fval;
            out.all_xhat = xhat_all;
            out.all_output = output_all;

        case 'vbmc'

            if ~exist('vbmc','file'), error('VBMC missing from path!'); end

            options = vbmc('defaults');
            options.MaxIter = 500;
            options.MaxFunEvals = 500;
            options.SpecifyTargetNoise = isnoisy;
            options.Display = opt_disp;

            [vp,elbo,~,~,output] = vbmc(@getlp,pfit_ini,pfit_min,pfit_max,pfit_plb,pfit_pub,options);

            xsmp = vbmc_rnd(vp,1e6);

            xmap = vbmc_mode(vp);
            xavg = mean(xsmp,1);
            xstd = std(xsmp,[],1);
            xcov = cov(xsmp);
            xmed = median(xsmp,1);
            xqrt = quantile(xsmp,[0.25,0.75],1);

            phat_map = getpval(xmap);
            phat_avg = getpval(xavg);
            phat = phat_map;

            out = cell2struct(phat(:),pnam(:));
            out.ncrit = ncrit;

            out.pmap = cell2struct(phat_map(:),pnam(:));
            out.pmap.ncrit = ncrit;

            out.pavg = cell2struct(phat_avg(:),pnam(:));
            out.pavg.ncrit = ncrit;

            out.fitalgo = fitalgo;
            out.npft = npft;
            out.nres = nres;
            out.nobs = nobs;
            out.nfit = nfit;

            out.vp = vp;
            out.elbo = elbo;
            out.elbo_sd = output.elbo_sd;
            out.lp = getlp(xmap);
            out.ll = getll(phat_map{:});

            out.xnam = pnam(cellfun(@isempty,pfix));
            out.xmap = xmap;
            out.xavg = xavg;
            out.xstd = xstd;
            out.xcov = xcov;
            out.xmed = xmed;
            out.xqrt = xqrt;
            out.output = output;

        otherwise
            error('Undefined fitting algorithm: %s',fitalgo);
    end

else

    phat = getpval([]);

    out = cell2struct(phat(:),pnam(:));
    out.ncrit = ncrit;

    out.fitalgo = fitalgo;
    out.npft = npft;
    out.nres = nres;
    out.nrun = nrun;
    out.nobs = nobs;
    out.nfit = 0;

    [out.ll,out.ll_sd] = getll(phat{:});

    out.aic = -2*out.ll;
    out.bic = -2*out.ll;

    out.xnam = {};
    out.xhat = [];
    out.xhat_model = [];

    if strcmpi(fitalgo,'vbmc')
        out.elbo = out.ll;
        out.elbo_sd = out.ll_sd;
        out.lp = out.ll;
        out.vp = [];
        out.xmap = [];
        out.xavg = [];
        out.xstd = [];
        out.xcov = [];
        out.xmed = [];
        out.xqrt = [];
    end

    out.output = struct;
end

%% Get model predictions

[~,out.pt_avg,out.vopt,out.copt,out.mcol] = getp(phat{:});

out.cfg = cfg;
out.cfg.ncrit = ncrit;

%% Get full continuous parameter values

    function pval = getpval(p)

        pval = cell(1,npar);

        for k = 1:npar
            if isempty(pfix{k})
                pval{k} = p(ifit{k});
            else
                pval{k} = pfix{k};
            end
        end
    end

%% Negative log-likelihood for BADS

    function nl = getnl(p)

        pval = getpval(p);
        nl = -getll(pval{:});
    end

%% Log-posterior for VBMC

    function [lp,lp_sd] = getlp(p)

        pval = getpval(p);
        l0 = 0;

        for k = 1:npar
            if isempty(pfix{k})
                if isempty(pfun{k})
                    prior_density = unifpdf(pval{k},pmin(k),pmax(k));
                else
                    prior_density = pfun{k}(pval{k});
                end

                if prior_density <= 0 || ~isfinite(prior_density)
                    lp = -Inf;
                    lp_sd = 0;
                    return
                end

                l0 = l0 + log(prior_density);
            end
        end

        [ll,ll_sd] = getll(pval{:});
        lp = ll + l0;
        lp_sd = ll_sd;
    end

%% Compute log-likelihood

    function [ll,ll_sd] = getll(varargin)

        pseq = getp(varargin{:});
        ll_seq = nan(nseq,1);

        if nargout > 1, lsumres = nan(nres,nseq); end

        for iseq = 1:nseq
            p = pseq{iseq};
            resp = cfg.choices{iseq};

            if nargout > 1
                lres = nan(nres,1);

                for ires = 1:nres
                    jres = randsample(npft,npft,true);
                    pres = mean(p(:,:,jres),3);
                    pres = adjust_probabilities_matrix(pres,epsi);
                    response_index = sub2ind(size(pres),(1:size(pres,1))',resp(:));
                    pc = pres(response_index);
                    lres(ires) = sum(log(pc));
                end

                lsumres(:,iseq) = lres;
            end

            pmean = mean(p,3);
            pmean = adjust_probabilities_matrix(pmean,epsi);
            response_index = sub2ind(size(pmean),(1:size(pmean,1))',resp(:));
            pc = pmean(response_index);
            ll_seq(iseq) = sum(log(pc));
        end

        ll = sum(ll_seq);

        if nargout > 1, ll_sd = max(std(sum(lsumres,2)),1e-6); end
    end

%% Compute choice probabilities

    function [pt_seq,pt_avg,vopt,copt,mcol] = getp(betav,betac,betar,omega,delta,sigma)

        mcol = cell(nseq,1);
        vopt = cell(nseq,1);
        copt = cell(nseq,1);
        pt_seq = cell(nseq,1);
        pt_avg = cell(nseq,1);

        for iseq = 1:nseq
            choices = cfg.choices{iseq};
            nsmp = numel(choices);

            xc = nan(nsmp,2,npft);
            pt = nan(nsmp,2,npft);
            wt = nan(nsmp,npft);

            bc = true(1,2);
            nselected = zeros(1,2);

            xc(1,:,:) = 0;
            pt(1,:,:) = 0.5;
            wt(1,:) = 1/npft;

            for ismp = 2:nsmp
                ch = choices(ismp-1);
                un = 3-ch;

                nselected(ch) = nselected(ch) + 1;

                switch cfg.leakrule
                    case 'pre'
                        xc(ismp,ch,:) = (1-delta)*xc(ismp-1,ch,:) + cfg.colvals{iseq}(ch,ismp-1)*cfac;
                        xc(ismp,ch,:) = noisrnd(xc(ismp,ch,:),sigma);

                    otherwise
                        xc(ismp,ch,:) = xc(ismp-1,ch,:) + cfg.colvals{iseq}(ch,ismp-1)*cfac;
                        xc(ismp,ch,:) = noisrnd(xc(ismp,ch,:),sigma);
                        xc(ismp,ch,:) = (1-delta)*xc(ismp,ch,:);
                end

                xc(ismp,un,:) = (1-delta)*xc(ismp-1,un,:);

                dv = betav*(xc(ismp,1,:)-xc(ismp,2,:))*cfg.targetc(iseq);
                dv = dv-betac*(abs(xc(ismp,1,:))-abs(xc(ismp,2,:)));
                dv = dv+betar*(3-2*ch);

                in_count_phase = bc(ch) && nselected(ch) < ncrit;

                if in_count_phase
                    pt(ismp,ch,:) = omega;
                    pt(ismp,un,:) = 1-omega;
                else
                    pt(ismp,1,:) = 1./(1+exp(-dv));
                    pt(ismp,2,:) = 1-pt(ismp,1,:);
                end

                wt(ismp,:) = squeeze(pt(ismp,choices(ismp),:));

                if nnz(wt(ismp,:)) == 0 || any(~isfinite(wt(ismp,:)))
                    wt(ismp,:) = 1/npft;
                else
                    wt(ismp,:) = wt(ismp,:)/sum(wt(ismp,:));
                end

                ch_prv = ch;
                ch_cur = choices(ismp);

                if ch_cur ~= ch_prv, bc(ch_prv) = false; end

                resample_index = randsample(npft,npft,true,wt(ismp,:));
                xc(ismp,:,:) = xc(ismp,:,resample_index);
            end

            mt_avg = sum(bsxfun(@times,xc,reshape(wt,[nsmp,1,npft])),3);
            mcol{iseq} = mt_avg;

            [~,tempopt] = max(mt_avg*cfg.targetc(iseq),[],2);
            vopt{iseq} = [choices == tempopt' nan(1,20-numel(choices))];

            [~,tempopt] = min(abs(mt_avg),[],2);
            copt{iseq} = [choices == tempopt' nan(1,20-numel(choices))];

            pt_seq{iseq} = pt;
            pt_avg{iseq} = mean(pt,3);
        end
    end
end

%% Construct complete free-parameter vector

function [xnam,xval] = get_complete_free_parameter_vector(out,cfg,use_map)

complete_names = {'betav','betac','betar','ncrit','omega','delta','sigma'};
is_free = false(size(complete_names));

for i = 1:numel(complete_names)
    parameter_name = complete_names{i};

    if strcmp(parameter_name,'ncrit')
        is_free(i) = true;
    elseif ~isfield(cfg,parameter_name) || isempty(cfg.(parameter_name))
        is_free(i) = true;
    end
end

if isfield(cfg,'conditn') && cfg.conditn == 2, is_free(strcmp(complete_names,'betav')) = false; end

xnam = complete_names(is_free);
xval = nan(1,sum(is_free));

for i = 1:numel(xnam)
    parameter_name = xnam{i};

    if strcmp(parameter_name,'ncrit')
        xval(i) = out.ncrit;
    elseif use_map
        if isfield(out,'pmap') && isfield(out.pmap,parameter_name)
            xval(i) = out.pmap.(parameter_name);
        else
            xval(i) = out.(parameter_name);
        end
    else
        if isfield(out,'pavg') && isfield(out.pavg,parameter_name)
            xval(i) = out.pavg.(parameter_name);
        else
            xval(i) = out.(parameter_name);
        end
    end
end
end

%% Equal-tailed credible interval for a discrete distribution

function ci = discrete_credible_interval(grid,probability,mass)

probability = probability/sum(probability);
cdf_value = cumsum(probability);
alpha = (1-mass)/2;

lower_index = find(cdf_value >= alpha,1,'first');
upper_index = find(cdf_value >= 1-alpha,1,'first');

if isempty(lower_index), lower_index = 1; end
if isempty(upper_index), upper_index = numel(grid); end

ci = [grid(lower_index) grid(upper_index)];
end

%% Numerically stable log-sum-exp

function value = logsumexp_local(x)

xmax = max(x);

if isinf(xmax)
    value = xmax;
else
    value = xmax + log(sum(exp(x-xmax)));
end
end

%% Adjust choice probabilities

function p_adjusted = adjust_probabilities_matrix(p,epsi)

nan_mask = isnan(p);
valid_counts = sum(~nan_mask,2);
p_adjusted = epsi + (1-bsxfun(@times,valid_counts,epsi)).*p;
p_adjusted(nan_mask) = NaN;
end

%% Add learning noise

function x = noisrnd(m,s)

if isscalar(s), s = s.*ones(size(m)); end
x = normrnd(m,s);
end

%% Get color-to-evidence conversion factor

function cfac = get_cfac(perr)

x = -1:0.001:+1;
cfac = fzero(@(b)trapz(x(x>0),1./(1+exp(x(x>0)*b))/trapz(x,1./(1+exp(x*b))))-perr,[0,10]);
end