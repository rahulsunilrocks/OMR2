function note_info = getSingleNoteLengths(notes_coords,canvas,est_note_diam,max_staff_line_width)
% Given note coordinate on its bounding box canvas, return the length of
% the note (time), ex. 8th note, 16th note. Works specifically for single
% notes, which takes into account FLAG information.

note_info = [];
note_info_grouping = 1;
ori_notes_coords = notes_coords;
while ~isempty(notes_coords)
    removal_queue = [1];
    tmp_coords = notes_coords(1,:);
    % Look for notes in the same chord
    if size(notes_coords,1)>1
        for i=2:size(notes_coords,1)
            if abs(tmp_coords(1,1)-notes_coords(i,1))<0.5*est_note_diam
                % Remove notes that lie on a similar x but are too far away
                if pdist([tmp_coords(1,1:2);notes_coords(i,1:2)])<2*est_note_diam
                    tmp_coords = cat(1,tmp_coords,notes_coords(i,:));
                end
                removal_queue = cat(1,removal_queue,i);
            end
        end
    end
    notes_coords(removal_queue,:) = [];
    % Find middle x coordinate for the chord
    mid_x = mean(tmp_coords(:,1));
    % Look for extranneous notes with impossible x coordinates
    removal_queue = [];
    if size(notes_coords,1)>1
        for i=1:size(notes_coords,1)
            if abs(mid_x-notes_coords(i,1))<est_note_diam*1.5
                removal_queue = cat(1,removal_queue,i);
            end
        end
    end
    notes_coords(removal_queue,:) = [];
    %Pre-process for beam scanning
    top_y = floor(min(tmp_coords(:,2)));
    bottom_y = ceil(max(tmp_coords(:,2)));
    % Isolate upper half or lower half for beams
    if mean(tmp_coords(:,2))<0.5*size(canvas,1)
        canvas(1:round(0.5*size(canvas,1)),:) = 0;
    end
    if mean(tmp_coords(:,2))>0.5*size(canvas,1)
        canvas(round(0.5*size(canvas,1)):end,:) = 0;
    end
    % Reposition center of note for beat computation
    if (mid_x+est_note_diam)<size(canvas,2)
        % If note is on the far left
        mid_x = (size(canvas,2)/2-mid_x)+size(canvas,2)/2;
    elseif (mid_x-est_note_diam)>1
        % If note is on the far right
        mid_x = size(canvas,2)/2-(mid_x-size(canvas,2)/2);
    end
    % Scan above the chord for beams
    upper_scan_line = canvas(1:top_y,round(mid_x));
%     % Remove any mini-staff lines that are in the way of gap computation
%     upper_scan_line_grad = [upper_scan_line(2:end)-upper_scan_line(1:(end-1));0];
%     line_priors = find(upper_scan_line_grad>0);
%     est_line_posts = line_priors+max_staff_line_width+1;
%     est_line_posts = est_line_posts(find(est_line_posts<top_y));
%     bad_line_posts = est_line_posts(find(upper_scan_line(est_line_posts)<1));
%     for j=1:size(bad_line_posts)
%         upper_scan_line((bad_line_posts(j,1)-max_staff_line_width):bad_line_posts(j,1),1) = 0;
%     end
    upper_scan_line = upper_scan_line([1,diff(upper_scan_line')]~=0);
    num_beams_above = sum(upper_scan_line);

    % Scan below the chord for beams
    lower_scan_line = canvas(bottom_y:end,round(mid_x));
%     % Remove any mini-staff lines that are in the way of gap computation
%     lower_scan_line_grad = [lower_scan_line(2:end)-lower_scan_line(1:(end-1));0];
%     line_priors = find(lower_scan_line_grad>0);
%     est_line_posts = line_priors+max_staff_line_width+1;
%     est_line_posts = est_line_posts(find(est_line_posts<size(lower_scan_line,1)));
%     bad_line_posts = est_line_posts(find(lower_scan_line(est_line_posts)<1));
%     for j=1:size(bad_line_posts)
%         lower_scan_line((bad_line_posts(j,1)-max_staff_line_width):bad_line_posts(j,1),1) = 0;
%     end
    lower_scan_line = lower_scan_line([1,diff(lower_scan_line')]~=0);
    num_beams_below = sum(lower_scan_line);
    beat = 0;
    if (num_beams_above == 0 && num_beams_below > 0)
        beat = 2^(num_beams_below+2);
    elseif (num_beams_below == 0 && num_beams_above > 0)
        beat = 2^(num_beams_above+2);
    else
        beat = 2^(3-tmp_coords(1,3));
    end
    tmp_coords = cat(2,tmp_coords(:,1:2),ones(size(tmp_coords,1),1)*beat);
    tmp_coords = cat(2,tmp_coords,(1:size(tmp_coords,1))');
    note_info_grouping = note_info_grouping+1;
    note_info = cat(1,note_info,tmp_coords);
end

if size(note_info,1)>=2
    % If rightmost note, converge to beat of left note
    if note_info(1,3)==0
        note_info(1,3) = note_info(2,3);
    end
    % If leftmost note, converge to beat of right note
    if note_info(size(note_info,1),3)==0
        note_info(size(note_info,1),3) = note_info(size(note_info,1)-1,3);
    end
end

end

