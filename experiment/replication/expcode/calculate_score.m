clc; close all;
cd /home/equipe-wyart-2/Documents/Experiment/COLdisc_EEG2025/expcode
subj_info;

subjdir = sprintf('../Data/S%02d', subj);

score = [];

for iblock = 1:12
    file_prefix = sprintf('expout_S%02d_b%02d_', subj, iblock);
    files = dir(fullfile(subjdir, [file_prefix, '*.mat']));

    if isempty(files)
        warning('No files found for block %02d, skipping...', iblock);
        continue;
    end

    for i = 1:length(files)
        file_path = fullfile(subjdir, files(i).name);
        try
            data = load(file_path);
            if isfield(data, 'avgscore')
                score = cat(1, score, data.avgscore);
            else
                fprintf('Warning: avgscore not found in %s\n', files(i).name);
            end
        catch ME
            fprintf('Error loading file %s: %s\n', files(i).name, ME.message);
        end
    end
end

score

score_avg = mean(score);

% Define user-defined variables
score_min = 0.6;   % Lower bound of score_avg
score_max = 0.9;   % Upper bound of score_avg
bonus_min = 1;     % Minimum bonus
bonus_max = 5;     % Maximum bonus

% Compute the slope (m) and intercept (b) for the linear function
m = (bonus_max - bonus_min) / (score_max - score_min);
b = bonus_min - m * score_min;

% Compute bonus based on score_avg
bonus = round(m * score_avg + b);

% Ensure bonus is within the range [bonus_min, bonus_max]
bonus = max(bonus_min, min(bonus_max, bonus));

fprintf('Avg score: %f\n\n', score_avg)
fprintf('Bonus earned: %d\n\n', bonus)


