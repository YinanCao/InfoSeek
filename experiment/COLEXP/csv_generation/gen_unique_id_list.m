% script gen_unique_id_list

% Project:  COLEXP_online
% Date:     March 2022
% Author:   Jun Seok Lee

% creates an array of unique ids characterized by the following format:
%   [enumerator_id][random character of length 4][random numeric array of length 6]
%       where enumerator_id has 3 leading zeros 
%
% Note: this script is to be run ONE TIME ONLY per task cohort
function gen_unique_id_list(nsubj)

if isfile('unique_id_list.mat') 
    disp('Unique ID key list already exists! Doing nothing...');
else
    % Generate unique ID list
    char_array  = char(65:90);
    num_len     = 6;
    char_len    = 4;
    unique_id_list = strings(num_len,1);

    for isubj = 1:nsubj
        unique_id_list(isubj) = sprintf('%03d%s%06d',isubj,randsample(char_array,char_len),randi(999999));
    end

    save('unique_id_list','unique_id_list');
end

end