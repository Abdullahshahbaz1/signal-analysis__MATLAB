%% ==============================================================
%  OpenBCI EEG Signal Analyzer
%  --------------------------------------------------------------
%  Loads and compares two OpenBCI EEG .TXT files and opens them
%  directly in MATLAB’s Signal Analyzer app for inspection.
%
%  Supports: Cyton (8-channel), Ganglion (4-channel), or generic EEG data.
%
%  Author: [Abdullah Shahbaz]
%  Date:   [14 oct 2025]
%% ==============================================================

clear; clc; close all;

%% === Configuration ===
fs = 250;  % Sampling frequency (Hz)
            % Cyton default: 250 Hz
            % Ganglion default: 125 Hz
fprintf('=== OpenBCI EEG Signal Analyzer ===\n\n');

%% === File Selection ===
fprintf('Select the first EEG TXT file...\n');
[file1, path1] = uigetfile('*.txt', 'Select First EEG TXT File');
if isequal(file1, 0)
    disp('User cancelled file selection.');
    return;
end

fprintf('Select the second EEG TXT file...\n');
[file2, path2] = uigetfile('*.txt', 'Select Second EEG TXT File', path1);
if isequal(file2, 0)
    disp('User cancelled file selection.');
    return;
end

%% === Load Files ===
fprintf('\nLoading %s...\n', file1);
[data1, headers1] = readOpenBCItxt(fullfile(path1, file1));

fprintf('Loading %s...\n', file2);
[data2, headers2] = readOpenBCItxt(fullfile(path2, file2));

%% === Extract EEG Channels ===
% Column 1 = sample index; 2–9 = EEG channels; last columns = AUX or accelerometer.
eeg1 = extractEEGChannels(data1);
eeg2 = extractEEGChannels(data2);

numCh1 = size(eeg1, 2);
numCh2 = size(eeg2, 2);
fprintf('Loaded %d EEG channels from File 1\n', numCh1);
fprintf('Loaded %d EEG channels from File 2\n', numCh2);

%% === Time Vectors ===
t1 = (0:size(eeg1, 1)-1) / fs;
t2 = (0:size(eeg2, 1)-1) / fs;

%% === Channel Labels ===
labels1 = generateLabels(headers1, numCh1, "File1");
labels2 = generateLabels(headers2, numCh2, "File2");

%% === Create Timeseries Objects for Signal Analyzer ===
ts1 = timeseries(eeg1, t1, 'Name', 'EEG_File1');
ts2 = timeseries(eeg2, t2, 'Name', 'EEG_File2');

ts1.DataInfo.Units = 'µV';
ts2.DataInfo.Units = 'µV';
ts1.TimeInfo.Units = 'seconds';
ts2.TimeInfo.Units = 'seconds';

%% === Display Basic Statistics ===
fprintf('\n=== File 1 Statistics ===\n');
printStats(t1, eeg1, fs);

fprintf('\n=== File 2 Statistics ===\n');
printStats(t2, eeg2, fs);

%% === Open in Signal Analyzer ===
fprintf('\nOpening Signal Analyzer...\n');
signalAnalyzer(ts1, ts2);

fprintf('\n✅ Done! EEG signals are now loaded in Signal Analyzer.\n');
fprintf('You can now analyze, filter, and compare both recordings.\n');

%% ==============================================================
%  Helper Functions
% ==============================================================

function eeg = extractEEGChannels(data)
    % Extract EEG columns depending on number of available columns
    if size(data, 2) >= 11
        eeg = data(:, 2:9);  % Cyton (8 channels)
    elseif size(data, 2) >= 5
        eeg = data(:, 2:5);  % Ganglion (4 channels)
    else
        eeg = data(:, 2:end); % Generic
    end
end

function labels = generateLabels(headers, n, prefix)
    % Generate readable channel labels
    if ~isempty(headers) && numel(headers) >= n + 1
        labels = headers(2:n+1);
    else
        labels = arrayfun(@(i) sprintf('%s_Ch%d', prefix, i), 1:n, 'UniformOutput', false);
    end
end

function printStats(t, eeg, fs)
    fprintf('Duration: %.2f seconds\n', t(end));
    fprintf('Samples: %d\n', numel(t));
    fprintf('Sampling Frequency: %.2f Hz\n', fs);
    fprintf('Voltage Range: %.2f to %.2f µV\n', min(eeg(:)), max(eeg(:)));
end

function [data, headers] = readOpenBCItxt(filename)
    % Read OpenBCI TXT file and return numeric data and headers

    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end

    % --- Detect data start line ---
    allLines = {};
    dataStartLine = 0;
    while ~feof(fid)
        line = fgetl(fid);
        allLines{end+1} = line;
        trimmed = strtrim(line);
        if ~isempty(trimmed) && isempty(regexp(trimmed, '^[a-zA-Z%#]', 'once'))
            if dataStartLine == 0
                dataStartLine = numel(allLines);
            end
        end
    end
    fclose(fid);

    % --- Extract header information ---
    if dataStartLine > 1
        headerLine = allLines{dataStartLine - 1};
        headers = strsplit(headerLine, {',', '\t'});
        headers = strtrim(headers(~cellfun('isempty', headers)));
        fprintf('Detected %d header lines\n', dataStartLine - 1);
        fprintf('Column Headers: %s\n', strjoin(headers, ', '));
    else
        headers = {};
        dataStartLine = 1;
        fprintf('No header detected.\n');
    end

    % --- Load numeric data ---
    try
        data = readmatrix(filename, 'NumHeaderLines', dataStartLine - 1);
    catch
        fid = fopen(filename, 'r');
        for i = 1:dataStartLine - 1, fgetl(fid); end
        firstLine = fgetl(fid);
        frewind(fid);
        for i = 1:dataStartLine - 1, fgetl(fid); end
        cols = numel(strsplit(firstLine, {',', '\t'}));
        formatSpec = repmat('%f', 1, cols);
        data = textscan(fid, formatSpec, 'Delimiter', {',', '\t'}, 'CollectOutput', true);
        data = data{1};
        fclose(fid);
    end

    % --- Clean data ---
    validCols = ~all(isnan(data), 1);
    data = data(:, validCols);
    validRows = ~all(isnan(data), 2);
    data = data(validRows, :);

    fprintf('Successfully loaded %d samples × %d columns from %s\n', size(data, 1), size(data, 2), filename);
end
