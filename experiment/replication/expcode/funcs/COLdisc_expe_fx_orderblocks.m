function [sqc] = COLdisc_expe_fx_orderblocks(sqc)
%%% ordering sequences within blocks
%%% this runs on preconstituted sequences and blocks made from COLEXP_expe_makeblocks
%%%     - shuffle drawn sequences
%%%     - checking not twice same condition or 'twinid' in a row
%%%     - check not twice the same symbol in a row: nbackcondition

NSEQ    = numel(sqc);
nblocks = numel(unique([sqc.blk]));
nseqblk = NSEQ/nblocks;
nback   = 2;

%init
temp = sqc;
temp(:) = [];
[temp.blkseq] = [];

fprintf('Ordering sequences within the blocks from >>>fx_orderingblocks:\n');
for iblock = 1:nblocks
    
    %get sequences of this block
    fprintf('...ordering block %d --', iblock);
    thisblock = sqc([sqc.blk] == iblock);
    
    %while shuffling doesn't match constraints, reshuffle
    while true
        
        %shuffle sequences of this block
        shuffle = randperm(numel(thisblock),numel(thisblock));
        thisblock = thisblock(shuffle);
        
        %for each seq check constraints
        thisblock(1).blkseq = 1;
        for rnk = 2:nseqblk
            % check 2 back for condition and counterfactualness
            if rnk == 2 ; diffcond = 1; %diffcf = 1;
            else
                diffcond = sum(abs(diff([thisblock(rnk-nback:rnk).condition])));
                % diffcf = sum(abs(diff([thisblock(rnk-nback:rnk).counterfness])));
            end
            % check current (target and badbad) combination wasn't the previous one
            if thisblock(rnk).condition == 1 && thisblock(rnk).counterfness == 2 
                diffbadbad = ~ (thisblock(rnk-1).counterfness == thisblock(rnk).counterfness);
            else; diffbadbad = 1;
            end
            % check current symbol was not in previous seq
            symlast = sum(ismember(thisblock(rnk-1).symbolpair, thisblock(rnk).symbolpair));

            twinlast = thisblock(rnk-1).twinid == thisblock(rnk).twinid;
            
            % if conditions are not met, break and restart looping over seqs for this block:
            if symlast ~= 0 || diffcond == 0 || diffbadbad == 0 || twinlast ~= 0
                break
            end
            
            thisblock(rnk).blkseq = rnk;
        end
                
        %if successfully checked all seqs = block is done = break
        if rnk == nseqblk && symlast == 0 && diffcond ~= 0 && diffbadbad ~=0 && twinlast == 0
            break
        end
        
    end%while this block is not good enough, shuffle again
    
    % once good enough, store
    temp = [temp thisblock];
    fprintf('...ok %d\n', iblock);
    
end%FOR each block

sqc = temp;

fprintf('Done ordering blocks!\n');

end% function definition