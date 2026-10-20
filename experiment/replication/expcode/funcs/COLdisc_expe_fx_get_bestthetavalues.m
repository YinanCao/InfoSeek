function [bestthetavalues] = COLdisc_expe_fx_get_bestthetavalues(nsampleslist, counterfnesslist, targetcolorslist, kappa)
                                               
% default colored-disc with no shift: orange=0(pointing towards 'right'), blue=pi/2('up')
% theta = 0:pure orange, theta=pi/2:pure blue
% % % % % % % % % %
% % % % % % % % % %     inputs:
% % % % % % % % % %     - nsampleslist: a list of all the lengths of all the runs,
% % % % % % % % % %                     in the shape [8 8 8 8 8 8 8 8 8 8 8 8 12 12 12 12.. etc]
% % % % % % % % % %     - counterfnesslist: list of all counterfness conditions of all runs
% % % % % % % % % %                        1 = good / good (both are target)
% % % % % % % % % %                        2 = bad  / bad  (none is target)
% % % % % % % % % %                        3 = good / bad  (one is target)
% % % % % % % % % %                     in the shape [1 1 1 1 2 2 2 2 3 3 3 3 1 1 1 1 2 2 2 2 etc..]
% % % % % % % % % %     - targetcolorslist: list of all targetcolors 
% % % % % % % % % %                     in the shape [1 2 1 2 1 2 1 2etc..]
% % % % % % % % % %     - kappa: concentration parameter of von Mises. This will determine the perr
% % % % % % % % % %     (perr: probability of misclassification of the form based on a single sample/color)
% % % % % % % % % %
% % % % % % % % % %     output:
% % % % % % % % % %     bestthetavalues: structure of same length (= length(nsampleslist)),
% % % % % % % % % %     with fields:
% % % % % % % % % %                   - target: the color (theta) draws for target shape of the run
% % % % % % % % % %                   - other: color (theta) draws for the other shape of this run
% % % % % % % % % %                   - nsamples: n of samples in run (=numel(other))
% % % % % % % % % %                   - counterfness: cf condition in run
% % % % % % % % % %                   - targetcolor: target color in run
% % % % % % % % % %
% % % % % % % % % %     NB: the order of fields couterfness/targetcolors matters => otherwise won't be paired well

% (1) defines the probability distribution of the color
%       // NB: draws from the "high prob on 0-1" distribution => so the orange
%       and flips at the end for the blue target condition \\
% (2) for each length-counterfness combination:
%       - get ndraws of length-many colors
%       - run nmodelsimulations of the sampling sequences on this color draw
%       - sort the color draws by (a) final amount of info accumulated, 
% and (b) similarity to the original underlying color distribution
%         NB: "difficulty" is the median "amount of information" 
%             accumulated for the options abs()
%       - store as many draws as we have sequences of this length-counterfness combination
%         flipped when the target was blue.
% // NB: RETURNS "theta" ON 0~pi CONTINUUM

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% target        - + + - - + - + % [+:orange, -:blue]
% other         - + + - + - + -
% counterfness  1 1 2 2 3 3 3 3
% targetcolor   1 2 1 2 1 2 1 2  % [1:blue, 2:orange] *only meaningful for draw
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% parameters:
% init:
lengthxcf       = unique([nsampleslist' counterfnesslist'], 'rows');
bestthetavalues = struct();
all             = struct();
stored          = 0; % this will add up
% model parameters:
alpha   = 1;
sigma   = 0.5;
ncolsim = 1e2;  % nb of color draws simulations, this could be higher!
nmodsim = 1e3;  % nb of model simulations to run on each color draw
tprec   = 0.05; % precision on theta (%)
kprec   = 0.05; % precision on kappa (%)
ntask   = 2;    % draw vs. guess
% customized functions:
rndvm   = @(n,t,k)mod(randraw('vonmises',[t*2,k],n)/2,pi);
pdfvm   = @(x,t,k)exp(k.*cos(2*(x-t)))./(pi*besseli(0,k));

%% We could also define a desired 'perr' first, and then estimate the kappa:
delta_mu = pi/2; % Difference in means (0 and pi/2)
% Define the error function to solve for kappa
perr     = 1/3;
equation = @(k) 0.5*(1-erf((delta_mu*sqrt(k))/(2*sqrt(2))))-perr;
% Initial guess for kappa
initial_guess = 0.5;
% Use fsolve to find the kappa that gives the target error probability
options = optimset('Display', 'off'); % Suppress output
if isempty(kappa)
    kappa = fsolve(equation, initial_guess, options);
    fprintf('*** using error rate %03f to compute kappa = %03f ***',perr,kappa)
end
%% I// draw colors & simulate discriminability/difficulty based on model learning => nsim times:
% loop over each unique comb of nsamples and counterfness:
for ilengthxcf      = 1:size(lengthxcf,1)
        
    nsamples        = lengthxcf(ilengthxcf, 1);
    counterfness    = lengthxcf(ilengthxcf, 2);
    thetavalues     = nan(ncolsim, nsamples, 2);
    drawntheta      = nan(2, nsamples);
    dval            = nan(ncolsim, nmodsim, nsamples, ntask); % decision values to compute ranks on:
    colrnk          = nan(ncolsim, nsamples, ntask);
    arnk            = nan(ncolsim, nsamples, ntask);

    % latent state
    switch counterfness
        case 1; latent = [+1; +1];
        case 2; latent = [-1; -1];
        case 3; latent = [+1; -1];
    end
    %% first, we pre-generate good theta samples;
    %% and empirically ensure the kappa and mu are precise enough:
    while true
        % generate samples for the von Mises;
        % make sure the empirically estimated mean and kappa are accurate:
        xt   = rndvm([ncolsim,nsamples],0,kappa); % [0, pi]
        phat = fminsearch(@(p)-sum(log(pdfvm(xt(:),p(1),p(2)))),[0,kappa], ...
                 optimset('Display','off','MaxFunEvals',1e4,'TolX',1e-6));
        that = phat(1);
        khat = phat(2);
        if abs(that)/pi < tprec/2 && abs(khat-kappa)/kappa < kprec/2
            theta_match = xt; % if accurate enough, save to theta_match
            break
        end
    end
    % log-odds: theta=0 means pure orange:
    thetalogodds = 2 * kappa * cos(2*theta_match);
    %%
    for icolsim = 1:ncolsim % loop over simulations

        if mod(icolsim,round(ncolsim/4)) == 0; fprintf('xxx...\n'); end
        
        % init for current color simulation:
        samplings = zeros(1, nsamples,  ntask); % sampling response symbol (which form to look at)
        learntval = zeros(2, nsamples+1,ntask); % expected/infered/learnt color of each sym
        seenval   = zeros(2, nsamples,  ntask); % actual colors values *seen* by model: drawn(sampled)
        
        %%% (a) draw colvals for this round of simulations depending on condition:
        % 'Von Mises':
        theta = theta_match(icolsim, :); % [0, pi]

        % switch counterfness
        switch counterfness
            case 1; drawntheta(1,:) = theta;        drawntheta(2,:) = theta;        % good good
            case 2; drawntheta(1,:) = theta + pi/2; drawntheta(2,:) = theta + pi/2; % bad  bad
            case 3; drawntheta(1,:) = theta;        drawntheta(2,:) = theta + pi/2; % good bad
        end
        drawntheta = mod(drawntheta, pi); % wrap to [0,pi) because this is orientation
        thetavalues(icolsim,:,:) = drawntheta'; % size of [nsamples,2]

        % log-odds in support of category orange (note that "pure orange": theta=0)
        % assuming orange mean = theta 0 (arrow pointing to x-axis
        % positive):
        drawnlogodds = 2 * kappa * cos(2*drawntheta); % log-odds

        %%% (b) run nmodsim model simulations on each color draw simulation:
        for imodsim = 1:nmodsim

            for ismp = 1:nsamples
                
                %%% choose option to sample from
                if ismp == 1 % if first one, choose randomly
                    ro = randi(2,1);
                    tr = ro;
                    samplings(:,ismp,:) = ro; % for row one = random but same
                    learntval(:,ismp,:) = 0;
                    dval(icolsim, imodsim, ismp, :) = 0;
                elseif ismp > 1
                    % bandit task: choose orange:
                    [trv, tr] = max(learntval(:,ismp,1),[],1); % orange = 1 = max
                    samplings(:,ismp,1) = tr;
                    dval(icolsim, imodsim, ismp, 1) = trv;
                    % guess task: symbol with least information
                    [rov, ro] = min(abs(learntval(:,ismp,2)),[],1); % min abs learnt value
                    samplings(:,ismp,2) = ro;
                    dval(icolsim, imodsim, ismp, 2) = rov;
                end

                %%% learn = accumulate color values (log-odds):
                seenval(tr,ismp,1) = drawnlogodds(tr, ismp); % bandit
                seenval(ro,ismp,2) = drawnlogodds(ro, ismp); % guess
                % chosen: update
                learntval(tr,ismp+1,1) = alpha*learntval(tr,ismp,1) + ((sigma*randn(1)) + seenval(tr,ismp,1));
                learntval(ro,ismp+1,2) = alpha*learntval(ro,ismp,2) + ((sigma*randn(1)) + seenval(ro,ismp,2));
                % unchosen: no update
                learntval(3-tr,ismp+1,1) = learntval(3-tr,ismp,1);
                learntval(3-ro,ismp+1,2) = learntval(3-ro,ismp,2);  
            end%for each sample, choose and learn
        end%for imodsim: model simulations on this color draw

        %%% for each colsim, take median value learnt by models for each sample:
        % median across nmodsim=1,000
        colrnk(icolsim,:,1) = median(dval(icolsim,:,:,1), 2);
        colrnk(icolsim,:,2) = median(dval(icolsim,:,:,2), 2);
        
    end%for each color draw simulation

    %%% (c) rank simulations & sum ranks (for difficulty):
    for ismp = 1:nsamples % at each sample 
        arnk(:,ismp,1) = tiedrank( abs ( colrnk(:,ismp,1) - mean(colrnk(:,ismp,1)) )); % draw task
        arnk(:,ismp,2) = tiedrank( abs ( colrnk(:,ismp,2) - mean(colrnk(:,ismp,2)) )); % guess task
    end
    srnk = squeeze(sum(arnk, 2)); % for each colsim, sum of the ranks of all the samples

    %%% (d) add constraint on color distribution for each block:
    % Let's do it based on the log-odds computed directly from
    % 'theta_match':
    mucol = tiedrank( abs (  mean(thetalogodds,2) - mean(mean(thetalogodds,2)) ) ) ;
    sdcol = tiedrank( abs (  std(thetalogodds,0,2) - mean(std(thetalogodds,0,2)) ) ) ;
    scrnk = (mucol + sdcol);

    %%% (e) pick color series whose sum of ranks is lowest & store them
    % based on a joint criterion:
    [~,lowest_rank] = sort( tiedrank(srnk(:,1))+tiedrank(srnk(:,2))+tiedrank(scrnk) ); 
    % the number of sequences we need for this level of nsamples & ncf
    npck = sum(nsampleslist==nsamples & counterfnesslist==counterfness);
    % sort sims by sum of ranks summed across smp and conditions
    pk = lowest_rank(1:npck);
    % randomize, so that targetcolorslist won't have confound:
    pk = pk(randperm(npck)); % no problem! still the npck best ones!

    % idx = nsampleslist==nsamples & counterfnesslist==counterfness;
    % this_targ_color = targetcolorslist(idx);

    % we don't need 'all', for debug only:
    all(ilengthxcf).arnk   = arnk;
    all(ilengthxcf).srnk   = srnk;
    all(ilengthxcf).colrnk = colrnk;
    all(ilengthxcf).scrnk  = scrnk;

    %%% (f) store selected color values and conditions
    for ist = 1:npck % store final colvals
        stored = stored + 1;
        if     targetcolorslist(stored) == 1 % if draw target is blue
            % shift the theta to blue (+90 deg), and wrap to [0,pi]
            bestthetavalues(stored).target = mod(thetavalues(pk(ist),:,1) + pi/2, pi);
            bestthetavalues(stored).other  = mod(thetavalues(pk(ist),:,2) + pi/2, pi);
            bestthetavalues(stored).latent = latent * -1;
        elseif targetcolorslist(stored) == 2 % if draw target is orange
            % note: thetavalues were already wrapped to [0,pi) before
            bestthetavalues(stored).target = thetavalues(pk(ist),:,1);
            bestthetavalues(stored).other  = thetavalues(pk(ist),:,2);
            bestthetavalues(stored).latent = latent;
        end
        bestthetavalues(stored).nsamples     = nsamples;
        bestthetavalues(stored).counterfness = counterfness;
        bestthetavalues(stored).targetcolors = targetcolorslist(stored);
        bestthetavalues(stored).kappa        = kappa;
        bestthetavalues(stored).twinid       = stored;
    end

fprintf('...done with length %d & cf %d...\n', nsamples, counterfness);
end % for each length x cf condition

fprintf('Done choosing color values!\n')
end % function end


