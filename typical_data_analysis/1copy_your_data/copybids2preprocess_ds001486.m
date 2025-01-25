%% Copies data from bids to preproc folder
% Original code written by Jin Wang 1/5/2021 for copying data from bids that have multiple sessions.
% A txt file will list subs with >1 T1 image (copy_repeated_anat.m/delete_bad_t1.m to evaluate)
% This script organizes for preprocessing

%% Last modified: 11/20/2024 IC
% 11/18/2024 IC: Updated filepaths and reorganzied script to improve readability
% 11/20/2024 IC: Improve readability

%% Specify filepaths
clear; clc;

% Add 1copy_your_data folder to search path so that we can use the
% expand_path function
addpath(genpath('/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/Isaac/reading-PA-NVIQ/typical_data_analysis/1copy_your_data')); 

% Create structure CCN
global CCN;

% Define project directory
proj_dir = '/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/Isaac/reading-PA-NVIQ/';

% Define dataset of interest
ds = 'ds001486-1.3.1';

% Define raw data directory
raw_dir = fullfile(proj_dir, 'bids', ds);

% Define preprocessing directory, where you want to copy your data to
proc_dir = fullfile(proj_dir, 'preproc', ds);

%% Specify participants
% Either manually put in your subjects (e.g.'sub-5004' 'sub-5009') OR
% Leave it empty and define a path of an excel that contains subject numbers as indicated below
subjects = {};

% In this excel, there should be a column of subjects with the header (subjects). 
% The subjects should all be sub plus numbers (sub-5002).
data_info = fullfile(proj_dir, 'preproc', ds, 'subjects_ds001486.csv');

if isempty(subjects)
    M = readtable(data_info);
    subjects = M.subjects;
end

%% Define data files to be moved
% Functional image search pattern
CCN.funcf1 = 'sub*_*_task-Rhyming*_bold.ni*';

% Anatomical image search pattern
CCN.anat = '*_T1w.nii.gz'; 

% This is the session. You can define 'ses*' to grab all sessions too. In this example, it's just grabbing ses-7.
session = 'ses-T1'; 

% Filename for list of subs with multiple T1s, used in delete_bad_t1.m 
% This file is used to record repetited T1s, and will be used in code delete_bad_t1.m later when you want unique t1 to preprocess the data. 
writefile = 'multiple_T1w_subjects_bids.txt';

%% Copy BIDS data
cd(proc_dir);
% create a multiple_t1.txt, if there is an existing one, delete it. 
if exist(writefile, 'file')
    delete(writefile);
end

fid = fopen([proc_dir '/' writefile],'w');

disp('==Job start=='); 
tic; 
count = 1;

for i= 1:length(subjects)
    
    % Define source and destination file paths
    old_dir = [raw_dir '/' subjects{i} '/' session];
    new_dir = [proc_dir '/' subjects{i} '/' session];
    
    % Modify this if you have more than 1 func patterns
    if ~isempty(expand_path([old_dir '/func/' '[funcf1]']))
        
        fprintf('\n%i. Working on %s from %s ...\n', count, subjects{i}, ds); 
        
        % Set up directories
        if ~exist(new_dir, 'dir')
            mkdir(new_dir);
            mkdir([new_dir '/func']);
            mkdir([new_dir '/anat']);
        end
        
        % List out functional image paths
        source{1} = expand_path([old_dir '/func/[funcf1]']);
        
        disp('---Copying functionals ---');
        
        % Copy functionals
        for j = 1:length(source)
            for jj = 1:length(source{j})
                % Get file parts of functional image
                [f_path, f_name, ext] = fileparts(source{j}{jj});
                % Create task-specific folder
                mkdir([new_dir '/func/' f_name(1:end-4)]);
                % Define filepath for functional image
                dest = [new_dir '/func/' f_name(1:end-4) '/' f_name ext];
                % Change permissions
                system(['chmod -R 770 ', fileparts(dest)]);
                % Copy from source to destination
                copyfile(source{j}{jj}, dest);
                % Change file permissions again
                system(['chmod 770 ', dest]);
                % Unzip nii.gz to .nii (b/c SPM only works with .nii)
                gunzip(dest);
                % Delete nii.gz
                delete(dest);
            end
        end
        
        % Copy anatomicals
        disp('---Copying anatomicals ---'); 
        sanat = expand_path([old_dir '/anat/[anat]']);
        
        % Notes any particpants with more than 1 anatomical
        if length(sanat) > 1
            fprintf(fid,'%s\n', subjects{i});
        end
        
        for k = 1:length(sanat)
            % Get file parts of anatomical scan 
            [a_path, a_name, ext] = fileparts(sanat{k});
            % Define destination
            dt = [new_dir '/anat/' a_name ext];
            % Change file permissions
            system(['chmod -R 770 ', fileparts(dt)]);
            % Copy from source to destination
            copyfile(sanat{k},dt);
            % Change file permissions
            system(['chmod 770 ', dt]);
            % Unzip .nii.gz to .nii
            gunzip(dt);
            % Delete .nii.gz
            delete(dt);
        end
        
        fprintf('Complete!\n')
    
    else 
        % Print out the subjects that you requested but not found in bids.
        fprintf('%s targeted tasks not found\n', subjects{i});
    end
    
    count = count + 1;
end

fprintf('\n==Job Done==\n');
toc;
%%