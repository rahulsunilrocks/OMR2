%% Add dependencies
% Add path to Midi Tools
addpath('./dependencies/midi_lib');
addpath('./dependencies/template_matching');
% Add Java dependency to Midi Tools
javaaddpath('./dependencies/midi_lib/KaraokeMidiJava.jar');

%% Clear all
clear all; close all;

%% Some Sample Sheets (Uncomment to try it Out! Song is saved to './song.mid')
% Ordered from pretty good to terribly bad
% See ./notes/png for guide on keys

all_segments = detectSong('./sheets/River Flows In You',23,[1,65,60,67]); % Speed = 23, Key = F# C# G#
% all_segments = detectSong('./sheets/Brian Crain Opus/Butterfly Waltz',40,[-1,59]); % Speed = 40, Key = Bb
% all_segments = detectSong('./sheets/Gabriel',20,[1]); % Speed = 20, Key = C Major
% all_segments = detectSong('./sheets/The Moment',25,[1,65,60,67,62]); % Speed = 25, Key = F# C# G# D#
% all_segments = detectSong('./sheets/Maybe',25,[-1,59,64,57,62,55]); % Speed = 25, Key = Bb Eb Ab Db Gb

% TODO Samples (These works are what I want to get working in the future)
% all_segments = detectSong('./sheets/Concerning Hobbits',25,[1,65]); % Speed = 30, Key = F#

%% Combine all segment note matrices and timing
time = zeros(1,7);
note_matrix = [];
for i=1:size(all_segments,2)
    % Piece together timeline for segments over
    tmp_note_matrix = all_segments{i};
    tmp_note_matrix = tmp_note_matrix+repmat(time,size(tmp_note_matrix,1),1);
    last_element = tmp_note_matrix(size(tmp_note_matrix,1),:);
    time = [last_element(1)+last_element(2),0,0,0,0,last_element(6)+last_element(7),0];
    
    % Reading in a midi file
    % note_matrix = readmidi_java('song.mid');
    % Read a midi file into a note matrix, getting the optional
    % track column.  (Note that .kar files are midi karaoke files.  They use
    % exactly the same file format as .mid files.  The .kar basically just
    % indicates that this is a midi file which contains midi lyric messages.) 
    %
    % The columns are:
    %       (1) - note start in beats
    %       (2) - note duration in beats
    %       (3) - channel
    %       (4) - midi pitch (60 --> C4 = middle C)
    %       (5) - velocity
    %       (6) - note start in seconds
    %       (7) - note duration in seconds
    % Do additional post-processing here
    tmp_note_matrix(:,5) = ones(size(tmp_note_matrix,1),1)*40;
    % Sample time function
%     tmp_note_matrix(26:end,1) = tmp_note_matrix(26:end,1).*linspace(1,1.3,27)';
%     tmp_note_matrix(26:end,2) = tmp_note_matrix(26:end,2).*linspace(1,1.5,27)';
%     tmp_note_matrix(26:end,6) = tmp_note_matrix(26:end,6).*linspace(1,1.3,27)';
%     tmp_note_matrix(26:end,7) = tmp_note_matrix(26:end,7).*linspace(1,1.5,27)';
%     tmp_note_matrix(26:end,5) = tmp_note_matrix(26:end,5).*linspace(1,0.8,27)';
    
    % Add segment note matrix to song matrix
    note_matrix = cat(1,note_matrix,tmp_note_matrix);
    
end
writemidi_java(note_matrix,'song.mid');
fprintf('\nSong finished! :)\nMIDI file saved to ./song.mid\n');

    