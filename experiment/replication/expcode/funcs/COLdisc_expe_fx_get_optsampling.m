function [sqc] = COLdisc_expe_fx_get_optsampling(sqc)
%%% simulates optimal model's choices at each sampling decision
%%% optimal as in alpha = 1 and sigma = 0
%%% at each sampling decision:
%%%     - chooses perfectly rationaly which symbol to sample from,
%%%     - accumulates perfectly the values of outcomes,
%%% NB: two series are stored: 1st choice is target or first choice is the other.

alpha = 1; % optimal = no leak, 
sigma = 0; % optimal = no noise.

fprintf('Adding optimal sampling behaviour to each run from >>>fx_get_optsampling:\n');

for isqc = 1:numel(sqc)
    
    condition   = sqc(isqc).condition;
    targetcolor = sqc(isqc).targetcolor;
    nsmp        = sqc(isqc).nsamples;
    cv          = [sqc(isqc).colorslin.target'; sqc(isqc).colorslin.other'];
    
    choices     = nan(2, nsmp); %first choice (1/2) x nsmp
    acc         = nan(2, nsmp+1, 2); %first choice 1/2 x nsmp x each symb
    
    for ismp = 1:nsmp
        
        %%% choose symbol to sample:
        if ismp == 1
            choices(1,ismp) = 1; 
            choices(2,ismp) = 2;
            acc(:,ismp,:) = 0;
        elseif ismp > 1 % else, choose for target, and open:
            switch condition
                case 1 % target: choose blue or orange
                    switch targetcolor
                        case 1; [~, choices(1,ismp)] = min(acc(1,ismp,:),[],3);
                                [~, choices(2,ismp)] = min(acc(2,ismp,:),[],3);
                        case 2; [~, choices(1,ismp)] = max(acc(1,ismp,:),[],3);
                                [~, choices(2,ismp)] = max(acc(2,ismp,:),[],3);
                    end
                case 2 % open: choose min info
                    [~, choices(1,ismp)] = min(abs(acc(1,ismp,:)),[],3);
                    [~, choices(2,ismp)] = min(abs(acc(2,ismp,:)),[],3);
            end
         end%choosing which symbol to sample from
             
        %%% accumulate corresponding values:
        ch = choices(1,ismp); % chosen if first choice is 1
        acc(1,ismp+1,ch)   = alpha * acc(1, ismp, ch) + ((sigma * randn(1)) + cv(ch,ismp));
        acc(1,ismp+1,3-ch) = acc(1,ismp,3-ch);
        
        ch = choices(2,ismp); % chosen if first choice is 2
        acc(2,ismp+1,ch) = alpha * acc(2, ismp, ch) + ((sigma * randn(1)) + cv(ch,ismp));
        acc(2,ismp+1,3-ch) = acc(2,ismp,3-ch);
        
        %%% store optimal choices into sqc main structure
        sqc(isqc).optchoices = choices;
        
    end%for each ismp
end%for each isqc

fprintf('Done adding opt sampling behaviour!\n');

end% function definition