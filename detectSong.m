function all_segments = detectSong(sheets_loc, music_speed, key)
% Using note information (coordinates, timing, beats, etc), construct a
% melody using a visual observation-based alignment-sensative method.
sheets = getSheets(sheets_loc);
all_segments = {};
all_segments_idx = 1;
for sheet_idx=1:size(sheets,2)
    segments = getStaveSegments(sheets{sheet_idx});
    [segments,est_note_diam] = detectNotes(segments);
    % Load scale and beat information
    scale = [21,23,24,26,28,29,31,33,35,36,38,40,41,43,45,47,48,50,52,53,55,57,59,60,62,64,65,67,69,71,72,74,76,77,79,81,83,84,86,88,89,91,93,95,96,98,100,101,103,105,107,108];
    % Modify scale with key
    for i=2:size(key,2)
        tmp_key_notes = find(mod(scale-(ones(1,size(scale,2))*key(1,i)),12)==0);
        scale(tmp_key_notes) = scale(tmp_key_notes)+key(1,1);
    end
    beats_per_second = (60*2)/music_speed;
    for i=1:size(segments,2)
        % Load segment information
        image = segments{i}.image;
        note_info = segments{i}.note_info;
        segment_staves = segments{i}.stave_mids;
        segment_mid = segments{i}.segment_mid;
        % Set A3 (57) and E4 (64) as pivot points
        segment_staves = cat(2,segment_staves,ones(size(segment_staves,1),1)*-1);
        segment_staves(5,2) = 26;
        segment_staves(6,2) = 22;
%         % Visualize segment information
%         figure(); imshow(image);
%         for j=1:size(segment_staves,1)
%             hold on; plot([1;size(image,2)],[segment_staves(j,1);segment_staves(j,1)],'m'); hold off;
%         end
%         hold on; plot([1;size(image,2)],[segment_mid;segment_mid],'m'); hold off;
        % Add pitch column to note_info [x y length group pitch]
        note_info = cat(2,note_info,ones(size(note_info,1),1)*-1);
        for j=1:size(note_info,1)
            if note_info(j,2) < segment_mid
                upper_gap_avg = mean(segment_staves(2:5,1)-segment_staves(1:4,1));
                note_info(j,5) = scale(round((segment_staves(5,1)-note_info(j,2))/(upper_gap_avg/2)+segment_staves(5,2)));
            else
                lower_gap_avg = mean(segment_staves(7:10,1)-segment_staves(6:9,1));
                note_info(j,5) = scale(round((segment_staves(6,1)-note_info(j,2))/(lower_gap_avg/2)+segment_staves(6,2)));
            end
        end
        % Split notes into left hand and right hand
        left_hand_notes = note_info(find(note_info(:,2)>segment_mid),:);
%         hold on; scatter(left_hand_notes(:,1),left_hand_notes(:,2),'g'); hold off;
        right_hand_notes = note_info(find(note_info(:,2)<=segment_mid),:);
%         hold on; scatter(right_hand_notes(:,1),right_hand_notes(:,2),'r'); hold off;
        % Apply beat duration while enforing note alignment
        right_hand_notes = cat(2,right_hand_notes,ones(size(right_hand_notes,1),1));
        left_hand_notes = cat(2,left_hand_notes,ones(size(left_hand_notes,1),1)*2);
        % Initiate temporary variables for segment
        beat_start = 0;
        time_start = 0;
        prev_left_beat = 0;
        prev_right_beat = 0;
        segment_note_matrix = [];
        scan_x_idx = 1;
        prev_aligned_left_notes = [];
        prev_aligned_right_notes = [];
        % Push scan line horizontally across segment to compute ordering of
        % notes. Base timing on grouping and readjust based on alignments
        while ~isempty(right_hand_notes) || ~isempty(left_hand_notes)
            if (~isempty(find(abs(left_hand_notes(:,1)-scan_x_idx)<est_note_diam)) && ~isempty(find(abs(right_hand_notes(:,1)-scan_x_idx)<est_note_diam))) || scan_x_idx==size(image,2)
                % Group together all left hand notes prior to the alignment
                left_idx = max(find(abs(left_hand_notes(:,1)-scan_x_idx)<est_note_diam));
                unaligned_left_idx = min(find(abs(left_hand_notes(:,1)-scan_x_idx)<est_note_diam));
                if scan_x_idx==size(image,2)
                    aligned_left_notes = [];
                    unaligned_left_notes = left_hand_notes;
                    left_hand_notes = [];
                else
                    aligned_left_notes = left_hand_notes(unaligned_left_idx:left_idx,:);
                    if unaligned_left_idx<=1
                        unaligned_left_notes = [];
                    else
                        unaligned_left_notes = left_hand_notes(1:(unaligned_left_idx-1),:);
                    end
                    left_hand_notes(1:left_idx,:) = [];
                end
                % Group together all right hand notes prior to the alignment
                right_idx = max(find(abs(right_hand_notes(:,1)-scan_x_idx)<est_note_diam));
                unaligned_right_idx = min(find(abs(right_hand_notes(:,1)-scan_x_idx)<est_note_diam));
                if scan_x_idx==size(image,2)
                    aligned_right_notes = [];
                    unaligned_right_notes = right_hand_notes;
                    right_hand_notes = [];
                else
                    aligned_right_notes = right_hand_notes(unaligned_right_idx:right_idx,:);
                    if unaligned_right_idx<=1
                        unaligned_right_notes = [];
                    else
                        unaligned_right_notes = right_hand_notes(1:(unaligned_right_idx-1),:);
                    end
                    right_hand_notes(1:right_idx,:) = [];
                end
                
                if ~isempty(unaligned_left_notes)
                    prev_left_beat = prev_left_beat+sum(unaligned_left_notes(find(unaligned_left_notes(:,4)<2),3));
                end
                if ~isempty(unaligned_right_notes)
                    prev_right_beat = prev_right_beat+sum(unaligned_right_notes(find(unaligned_right_notes(:,4)<2),3));
                end
                % Add notes to the note matrix
                if prev_left_beat == prev_right_beat
                    % Add right beats
                    tmp_beat_start = beat_start;
                    for j=1:size(prev_aligned_right_notes,1)
                        segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,prev_aligned_right_notes(j,3),prev_aligned_right_notes(j,6),prev_aligned_right_notes(j,5),45,tmp_beat_start,prev_aligned_right_notes(j,3)]);
                        if j==size(prev_aligned_right_notes,1) || prev_aligned_right_notes(j+1,4)<=prev_aligned_right_notes(j,4)
                            tmp_beat_start = tmp_beat_start+prev_aligned_right_notes(j,3);
                        end
                    end
                    for j=1:size(unaligned_right_notes,1)
                        segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,unaligned_right_notes(j,3),unaligned_right_notes(j,6),unaligned_right_notes(j,5),45,tmp_beat_start,unaligned_right_notes(j,3)]);
                        if j==size(unaligned_right_notes,1) || unaligned_right_notes(j+1,4)<=unaligned_right_notes(j,4)
                            tmp_beat_start = tmp_beat_start+unaligned_right_notes(j,3);
                        end
                    end
                    % Add left beats
                    tmp_beat_start = beat_start;
                    for j=1:size(prev_aligned_left_notes,1)
                        segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,prev_aligned_left_notes(j,3),prev_aligned_left_notes(j,6),prev_aligned_left_notes(j,5),45,tmp_beat_start,prev_aligned_left_notes(j,3)]);
                        if j==size(prev_aligned_left_notes,1) || prev_aligned_left_notes(j+1,4)<=prev_aligned_left_notes(j,4)
                            tmp_beat_start = tmp_beat_start+prev_aligned_left_notes(j,3);
                        end
                    end
                    for j=1:size(unaligned_left_notes,1)
                        segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,unaligned_left_notes(j,3),unaligned_left_notes(j,6),unaligned_left_notes(j,5),45,tmp_beat_start,unaligned_left_notes(j,3)]);
                        if j==size(unaligned_left_notes,1) || unaligned_left_notes(j+1,4)<=unaligned_left_notes(j,4)
                            tmp_beat_start = tmp_beat_start+unaligned_left_notes(j,3);
                        end
                    end
                    beat_start = beat_start+prev_left_beat;
                else
                    better_beat = min(prev_left_beat,prev_right_beat);
                    shrink_ratio = min(prev_left_beat,prev_right_beat)/max(prev_left_beat,prev_right_beat);
                    
%                     % Adjust if want to have right beats converge to left
%                     longest_beat = prev_left_beat;
                    
                    if better_beat == prev_right_beat
                        % Add right beats as normal
                        tmp_beat_start = beat_start;
                        for j=1:size(prev_aligned_right_notes,1)
                            segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,prev_aligned_right_notes(j,3),prev_aligned_right_notes(j,6),prev_aligned_right_notes(j,5),45,tmp_beat_start,prev_aligned_right_notes(j,3)]);
                            if j==size(prev_aligned_right_notes,1) || prev_aligned_right_notes(j+1,4)<=prev_aligned_right_notes(j,4)
                                tmp_beat_start = tmp_beat_start+prev_aligned_right_notes(j,3);
                            end
                        end
                        for j=1:size(unaligned_right_notes,1)
                            segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,unaligned_right_notes(j,3),unaligned_right_notes(j,6),unaligned_right_notes(j,5),45,tmp_beat_start,unaligned_right_notes(j,3)]);
                            if j==size(unaligned_right_notes,1) || unaligned_right_notes(j+1,4)<=unaligned_right_notes(j,4)
                                tmp_beat_start = tmp_beat_start+unaligned_right_notes(j,3);
                            end
                        end
                        % Shrink left beats
                        if ~isempty(unaligned_left_notes)
                            unaligned_left_notes(:,3) = unaligned_left_notes(:,3)*shrink_ratio;
                        end
                        if ~isempty(prev_aligned_left_notes)
                            prev_aligned_left_notes(:,3) = prev_aligned_left_notes(:,3)*shrink_ratio;
                        end
                        % Add left beats
                        tmp_beat_start = beat_start;
                        for j=1:size(prev_aligned_left_notes,1)
                            segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,prev_aligned_left_notes(j,3),prev_aligned_left_notes(j,6),prev_aligned_left_notes(j,5),45,tmp_beat_start,prev_aligned_left_notes(j,3)]);
                            if j==size(prev_aligned_left_notes,1) || prev_aligned_left_notes(j+1,4)<=prev_aligned_left_notes(j,4)
                                tmp_beat_start = tmp_beat_start+prev_aligned_left_notes(j,3);
                            end
                        end
                        for j=1:size(unaligned_left_notes,1)
                            segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,unaligned_left_notes(j,3),unaligned_left_notes(j,6),unaligned_left_notes(j,5),45,tmp_beat_start,unaligned_left_notes(j,3)]);
                            if j==size(unaligned_left_notes,1) || unaligned_left_notes(j+1,4)<=unaligned_left_notes(j,4)
                                tmp_beat_start = tmp_beat_start+unaligned_left_notes(j,3);
                            end
                        end
                    else
                        % Shrink right beats
                        if ~isempty(unaligned_right_notes)
                            unaligned_right_notes(:,3) = unaligned_right_notes(:,3)*shrink_ratio;
                        end
                        if ~isempty(prev_aligned_right_notes)
                            prev_aligned_right_notes(:,3) = prev_aligned_right_notes(:,3)*shrink_ratio;
                        end
                        % Add right beats
                        tmp_beat_start = beat_start;
                        for j=1:size(prev_aligned_right_notes,1)
                            segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,prev_aligned_right_notes(j,3),prev_aligned_right_notes(j,6),prev_aligned_right_notes(j,5),45,tmp_beat_start,prev_aligned_right_notes(j,3)]);
                            if j==size(prev_aligned_right_notes,1) || prev_aligned_right_notes(j+1,4)<=prev_aligned_right_notes(j,4)
                                tmp_beat_start = tmp_beat_start+prev_aligned_right_notes(j,3);
                            end
                        end
                        for j=1:size(unaligned_right_notes,1)
                            segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,unaligned_right_notes(j,3),unaligned_right_notes(j,6),unaligned_right_notes(j,5),45,tmp_beat_start,unaligned_right_notes(j,3)]);
                            if j==size(unaligned_right_notes,1) || unaligned_right_notes(j+1,4)<=unaligned_right_notes(j,4)
                                tmp_beat_start = tmp_beat_start+unaligned_right_notes(j,3);
                            end
                        end
                        % Add left beats as normal
                        tmp_beat_start = beat_start;
                        for j=1:size(prev_aligned_left_notes,1)
                            segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,prev_aligned_left_notes(j,3),prev_aligned_left_notes(j,6),prev_aligned_left_notes(j,5),45,tmp_beat_start,prev_aligned_left_notes(j,3)]);
                            if j==size(prev_aligned_left_notes,1) || prev_aligned_left_notes(j+1,4)<=prev_aligned_left_notes(j,4)
                                tmp_beat_start = tmp_beat_start+prev_aligned_left_notes(j,3);
                            end
                        end
                        for j=1:size(unaligned_left_notes,1)
                            segment_note_matrix = cat(1,segment_note_matrix,[tmp_beat_start,unaligned_left_notes(j,3),unaligned_left_notes(j,6),unaligned_left_notes(j,5),45,tmp_beat_start,unaligned_left_notes(j,3)]);
                            if j==size(unaligned_left_notes,1) || unaligned_left_notes(j+1,4)<=unaligned_left_notes(j,4)
                                tmp_beat_start = tmp_beat_start+unaligned_left_notes(j,3);
                            end
                        end
                    end
                    beat_start = beat_start+better_beat;
                end
                % Compute next set of aligned points 
                if ~isempty(aligned_left_notes)
                    prev_left_beat = max(aligned_left_notes(:,3));
                else
                    prev_left_beat = 0;
                end
                if ~isempty(aligned_right_notes)
                    prev_right_beat = max(aligned_right_notes(:,3));
                else
                    prev_right_beat = 0;
                end
                prev_aligned_left_notes = aligned_left_notes;
                prev_aligned_right_notes = aligned_right_notes;
                if scan_x_idx==size(image,2)
                    break;
                end
            else
                scan_x_idx = scan_x_idx+1;
            end
        end
        % Save segment notes
        segment_note_matrix(:,1:2) = segment_note_matrix(:,1:2)*beats_per_second;
        segment_note_matrix(:,6:7) = segment_note_matrix(:,6:7)*beats_per_second;
        all_segments{all_segments_idx} = segment_note_matrix;
        all_segments_idx = all_segments_idx+1;
    end
end

end

