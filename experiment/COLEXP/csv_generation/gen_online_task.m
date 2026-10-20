% gen_online_task

% Project:  COLEXP_online
% Date:     March 2022
% Author:   Jun Seok Lee

% Requirements / Inputs
%{ 
        1/ File named testtable.mat inside sub-directory 'tables'
        2/ The table that contains the data must be called 'data' inside the file.
        3/ Script gen_unique_id_list.m to generate unique IDs
%}

% Output 
%{ 
    Text file named data.txt
        {} : represents a block split by '#'
        [] : represents a sequence split by '%'
        Each sequence contains an '(info)' string followed by the outcome values
%}
clear all

% user defined variables
datafile = 'COLINE_pilot01_42';
% datafile = 'trainingset';

% constants

load(sprintf('./tables/%s.mat',datafile));
if strcmpi(datafile,'trainingset')
    data = trainingset;
    nsubj = max(max(data.subjnb),1);
else
    % generate unique id list
    nsubj = max(max(data.subjnb),1);
    gen_unique_id_list(nsubj);
    load ./unique_id_list % loads unique_id_list
end
    

for isubj = 1:nsubj
    datastr = "";
    if strcmpi(datafile,'trainingset')
        isubj = isubj - 1;
    end
    
    idx_subj = data.subjnb == isubj;
    
    nb = max(data.nbofblocks_inexpe(idx_subj)); % number of blocks for subject
    % block loop
    for ib = 1:nb
        idx_blk = data.blockidx_inexpe == ib & idx_subj;
        
        ns = max(data.seqidx_inblock(idx_blk)); % number of sequences in block
        blkstr = "{";
        % sequence loop
        for is = 1:ns
            idx_seq = data.seqidx_inblock == is & idx_blk;
            
            nt    = sum(idx_seq);
            %{  
                info: 
                    1. condition
                        1-DRAW, 2-GUESS
                    2. shape 1
                    3. shape 2
                    4. goal color
                    5. color symmetry (between shapes)
                        1-2 symmetric, 3 not
            %}
            
            cond = unique(data.condition(idx_seq));
            shape1  = unique(data.firstsymbol(idx_seq));
            shape2  = unique(data.secondsymbol(idx_seq));
            goalcol = unique(data.targetcolour_fordraw(idx_seq));
            if goalcol == 2
                goalcol = 0;
            end
            issymm  = unique(data.symmetryofcolours(idx_seq));
            
            % check for errors in info variables
            if any([numel(cond) numel(shape1) numel(shape2) numel(goalcol) numel(issymm)] > 1)
                error('Check info values. ');
            end
            
            % outcomes for sequence
            outc = data.firstopt_outcomes(idx_seq)';
            outc(end) = [];
            
            % sides of first option for sequence
            sides = data.firstopt_sides(idx_seq)';
            streaks = diff(find([1,diff(sides),1]));
            
            % convert numerical data to strings
            condstr = string(cond);
            s1str   = string(shape1);
            s2str   = string(shape2);
            goalstr = string(goalcol);
            symmstr = string(issymm);
            outcstr = string(outc);
            streakstr = string(streaks);
            
            % generate data string
            infostr = "(" + strjoin([condstr s1str s2str goalstr symmstr],"*") + ")";
            sidestr = "(" + strjoin(streakstr,"") + ")";
            trlstr  = strjoin(outcstr,",");
            seqstr  = "[" + infostr + sidestr + trlstr + "]";
            blkstr  = strjoin([blkstr seqstr "%"],"");
        end
        blkstr = extractBefore(blkstr,strlength(blkstr)) + "}";
        datastr = datastr + "#" + blkstr;
    end
    
    % save data file
    if true
        datastr = extractAfter(datastr,1);
        fileID = fopen('data.txt','w');
        fprintf(fileID,'%s',datastr);
        fclose(fileID);
        
        if strcmpi(datafile,'trainingset')
            mkdir('000TRAINING'); % make folder with the uid as name
            movefile('data.txt','000TRAINING'); % move file into the folder
            movefile('000TRAINING','data'); % move folder into the data folder
        else
            uid = unique_id_list{isubj}; 
            mkdir(sprintf('%s',uid)); % make folder with the uid as name
            movefile('data.txt',sprintf('%s',uid)); % move file into the folder
            movefile(sprintf('%s',uid),'data'); % move folder into the data folder
        end

    end
    
end