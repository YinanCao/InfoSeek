function [sqc] = COLdisc_expe_fx_makeblocks(sqc)
    % COLdisc_expe_fx_makeblocks
    % Function to create blocks of sequences while ensuring balance and avoiding repetitions.
    %
    % Input:
    %   - sqc : Structure array containing sequences
    %
    % Output:
    %   - sqc : Updated structure array with block assignments

    % Define parameters
    sqc_raw   = sqc;
    NSEQ      = numel(sqc);
    nseqblock = 8;
    nblocks   = NSEQ / nseqblock;
    nseq_cf   = 2; % blue vs. orange
    nseq_oo   = 1; % both orange
    nseq_bb   = 1; % both blue

    ntask     = 2;
    nseqcol   = nseqblock / ntask / 2; % 2 possible target colors
    noksymrepeats = 3;

    fprintf('Making blocks of seqs from >>> COLdisc_expe_fx_makeblocks:\n');

    while true
        % Initialize temporary structure for storing sequences
        currentpool = sqc;
        temp = sqc;
        temp(:) = [];
        [temp.blk] = [];

        % Loop over blocks
        for iblock = 1:nblocks
            fprintf('...block %d\n', iblock);

            while true
                % Randomly draw sequences for the current block
                idrawnseq = randperm(numel(currentpool), nseqblock);
                drawnseq  = currentpool(idrawnseq);

                % Compute color latent states
                color_latent = sum([drawnseq.latent]);
                color_dist = ...
                    sum(color_latent==-2 & [drawnseq.condition] == 1) == nseq_bb && ...
                    sum(color_latent==+2 & [drawnseq.condition] == 1) == nseq_oo && ...
                    sum(color_latent==0  & [drawnseq.condition] == 1) == nseq_cf && ...
                    sum(color_latent==-2 & [drawnseq.condition] == 2) == nseq_bb && ...
                    sum(color_latent==+2 & [drawnseq.condition] == 2) == nseq_oo && ...
                    sum(color_latent==0  & [drawnseq.condition] == 2) == nseq_cf;

                % Ensure equal number of sequences for blue vs. orange target
                ncoltarg = sum([drawnseq.condition] == 1 & [drawnseq.targetcolor] == 2);

                % Check symbol pair repetitions
                maxsymreps = max(histcounts([drawnseq.symbolpair]));
                % pairs = reshape([drawnseq.symbolpair], [2, nseqblock])';
                % nofullrepeat = sum(sum(diff(sort(pairs,2)) == 0, 2) > 1) == 0;

                maxtwinreps = max(histcounts([drawnseq.twinid]));

                % If all constraints are met, exit loop
                if color_dist && ncoltarg == nseqcol && maxsymreps <= noksymrepeats && maxtwinreps<=2
                    break
                % Restart from the first block if last block fails constraint
                elseif (iblock == nblocks) && ( (maxsymreps > noksymrepeats)||(maxtwinreps>2) )
                    currentpool = sqc;
                    iblock = 1; % Restart from block 1
                    fprintf('...!!! BREAKING AT LAST BLOCK !!!\n');
                end
            end % End while loop for current block

            % Store drawn sequences and remove them from the pool
            [drawnseq.blk] = deal(iblock);
            temp = [temp drawnseq];
            currentpool(idrawnseq) = [];

        end % End for loop over blocks

        % If all blocks were successfully assigned, exit the while loop
        if isempty(currentpool)
            break
        end
    end % End while loop

    % Assign final block information back to sqc
    sqc = temp;
    [~, sortIdx] = sort([sqc.genid]);
    sqc_sorted = sqc(sortIdx);

    % Remove the 'blk' field
    if isfield(sqc_sorted, 'blk')
        sqc_sorted = rmfield(sqc_sorted, 'blk');
    end

    % Check if sqc_raw and sqc_sorted are identical
    isEqual = isequal(sqc_raw, sqc_sorted);

    if isEqual
        disp('sqc and sqc_raw are identical after sorting by genid.');
    else
        disp('sqc and sqc_raw are NOT identical after sorting by genid.');
    end
end
