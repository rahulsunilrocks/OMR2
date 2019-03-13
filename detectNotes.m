function [segments,est_note_diam] = detectNotes(segments)
% Use preprocessed segment images and run connectivity to find bounding
% boxes for musical objects. Run template matching over bounding boxes for
% note detection and lastly, call a get*NoteLength function to determine
% the lengths of the notes. Generate a collection of awesome visualizations

est_note_diam = estimateNoteSize(segments);
segments = trimNotes(segments,est_note_diam);
templates = retrieveTemplates(est_note_diam);
for i=1:size(segments,2)
    % Retrieve segment information
    segment_image = 1-segments{i}.image;
    segment_stave_lines = segments{i}.stave_lines;
    % Find y coordinates right before and right after stave lines and other
    % useful information from stave lines
    vert_grad = segment_stave_lines(2:end)-segment_stave_lines(1:(end-1));
    stave_priors = find(vert_grad>0);
    stave_posts = find(vert_grad<0)+1;
    stave_mids = (stave_posts+stave_priors)./2;
    stave_line_widths = stave_posts-stave_priors-1;
    staff_height = max(stave_posts)-min(stave_priors);
    segment_mid = segments{i}.segment_mid+round(mean(stave_line_widths))-round(mean(stave_line_widths)/2);
    % Save average stave line width/gap information
%     avg_stave_line_width = mean(stave_line_widths);
%     avg_stave_line_gap = mean(stave_priors(2:end)-stave_posts(1:(end-1)));
%     tmp_stave_idx = min(stave_priors);
%     tmp_stave_idx = tmp_stave_idx-(avg_stave_line_gap+avg_stave_line_width+1);
%     while(tmp_stave_idx > 0)
%         segment_stave_lines(tmp_stave_idx:(tmp_stave_idx+avg_stave_line_width),1) = 1;
%         tmp_stave_idx = tmp_stave_idx-(avg_stave_line_gap+avg_stave_line_width+1);
%     end
    % Cut out stave lines
    segment_image = segment_image-repmat(segment_stave_lines,1,size(segment_image,2));
    % Fill in lost data in empty space from stave line removal
    for j=1:size(stave_priors,1)
        stave_line_upper_half_width = stave_line_widths(j)-round(stave_line_widths(j)/2);
        stave_line_lower_half_width = round(stave_line_widths(j)/2);
        segment_image((stave_priors(j)+1):(stave_priors(j)+stave_line_upper_half_width),:) = repmat(segment_image(stave_priors(j),:),stave_line_upper_half_width,1);
        segment_image((stave_posts(j)-stave_line_lower_half_width):(stave_posts(j)-1),:) = repmat(segment_image(stave_posts(j),:),stave_line_lower_half_width,1);
    end
    % Remove measure lines
    segment_measure_lines = double(im2bw(mean(segment_image(min(stave_priors):max(stave_posts),:),1),0.9));
    hor_grad = segment_measure_lines(2:end)-segment_measure_lines(1:(end-1));
    measure_priors = find(hor_grad>0);
    measure_posts = find(hor_grad<0)+1;
    measure_line_widths = measure_posts-measure_priors-1;
    for j=1:size(measure_priors,2)
        measure_line_left_half_width = measure_line_widths(j)-round(measure_line_widths(j)/2);
        measure_line_right_half_width = round(measure_line_widths(j)/2);
        segment_image((min(stave_priors)+1):(max(stave_posts)-1),(measure_priors(j)+1):(measure_priors(j)+measure_line_left_half_width)) = repmat(segment_image((min(stave_priors)+1):(max(stave_posts)-1),measure_priors(j)),1,measure_line_left_half_width);
        segment_image((min(stave_priors)+1):(max(stave_posts)-1),(measure_posts(j)-measure_line_right_half_width):(measure_posts(j)-1)) = repmat(segment_image((min(stave_priors)+1):(max(stave_posts)-1),measure_posts(j)),1,measure_line_right_half_width);
        %         segment_image((stave_posts(j)-measure_line_right_half_width):(stave_posts(j)-1),:) = repmat(segment_image(stave_posts(j),:),measure_line_right_half_width,1);
    end
    figure(); imshow(~segment_image);
    % Get bounding box of music objects via flood fill and return note
    % information
    music_obj_cc = bwconncomp(segment_image);
%     size(music_obj_cc.PixelIdxList,2)
    music_obj_bbox = [];
    music_obj_im = {};
    segment_note_info = [];
    notes = {};
    hold on;
    for j=1:size(music_obj_cc.PixelIdxList,2)
        tmp_obj_pixel_idx = music_obj_cc.PixelIdxList{j};
        tmp_obj_pixel_coor = [floor(tmp_obj_pixel_idx./size(segment_image,1)+1) mod(tmp_obj_pixel_idx,size(segment_image,1))];
%         hold on; scatter(tmp_obj_pixel_coor(:,1),tmp_obj_pixel_coor(:,2),1); hold off;
        tmp_obj_bbox_h = max(tmp_obj_pixel_coor(:,2))-min(tmp_obj_pixel_coor(:,2))+1;
        tmp_obj_bbox_w = max(tmp_obj_pixel_coor(:,1))-min(tmp_obj_pixel_coor(:,1))+1;
        tmp_obj_bbox = [min(tmp_obj_pixel_coor(:,1)),min(tmp_obj_pixel_coor(:,2)),tmp_obj_bbox_w,tmp_obj_bbox_h];
        % Copy musical object onto a clean canvas (to remove overlapping
        % bounding boxes)
        canvas_obj_bbox = zeros(tmp_obj_bbox_h,tmp_obj_bbox_w);
        obj_canvas_coor = [tmp_obj_pixel_coor(:,1)-tmp_obj_bbox(1)+1 tmp_obj_pixel_coor(:,2)-tmp_obj_bbox(2)+1];
        obj_canvas_idx = (obj_canvas_coor(:,1)-1).*tmp_obj_bbox_h+obj_canvas_coor(:,2);
        canvas_obj_bbox(obj_canvas_idx) = 1;
        music_obj_im{j} = canvas_obj_bbox;
        % 
        canvas_top_half = canvas_obj_bbox(1:floor(tmp_obj_bbox_h/2),:);
        canvas_bottom_half = canvas_obj_bbox(ceil(tmp_obj_bbox_h/2):end,:);
        % Run template response for notes, and retrieve centroids
        [~,tmp_match_q_response_NCC] = template_matching(templates.q_note,canvas_obj_bbox);
        [~,tmp_match_h_response_NCC] = template_matching(templates.h_note,canvas_obj_bbox);
        [~,tmp_match_w_response_NCC] = template_matching(templates.w_note,canvas_obj_bbox);
        tmp_match_q_response_NCC = double(tmp_match_q_response_NCC>0.76);
        tmp_match_h_response_NCC = double(tmp_match_h_response_NCC>0.80);
        tmp_match_w_response_NCC = double(tmp_match_w_response_NCC>0.75);
        tmp_q_note_stats = regionprops(bwlabel(logical(tmp_match_q_response_NCC)),'Centroid');
        tmp_h_note_stats = regionprops(bwlabel(logical(tmp_match_h_response_NCC)),'Centroid');
        tmp_w_note_stats = regionprops(bwlabel(logical(tmp_match_w_response_NCC)),'Centroid');
        % Find detected notes and categorize by filled(1), unfilled(2), or
        % whole(3). [x y type]
        tmp_detected_notes = [];
        for k=1:size(tmp_q_note_stats,1)
            tmp_detected_notes = cat(1,tmp_detected_notes,[tmp_q_note_stats(k).Centroid,1]);
        end
        for k=1:size(tmp_h_note_stats,1)
            tmp_detected_notes = cat(1,tmp_detected_notes,[tmp_h_note_stats(k).Centroid,2]);
        end
        for k=1:size(tmp_w_note_stats,1)
            tmp_detected_notes = cat(1,tmp_detected_notes,[tmp_w_note_stats(k).Centroid,3]);
        end
        % Sort musical objects based on bounding box size
        tmp_obj_note_info = [];
        if tmp_obj_bbox_w<est_note_diam/2
            if tmp_obj_bbox_h>staff_height/2
                rectangle('Position',tmp_obj_bbox,'EdgeColor','r');
            end
        end
        if tmp_obj_bbox_w>=est_note_diam/2 && tmp_obj_bbox_w<est_note_diam*2.5
            if tmp_obj_bbox_h>staff_height/1.5
                rectangle('Position',tmp_obj_bbox,'EdgeColor','r');
            elseif tmp_obj_bbox_h<est_note_diam && mean(canvas_obj_bbox(:))<0.5
                rectangle('Position',tmp_obj_bbox,'EdgeColor','r');
            elseif tmp_obj_bbox_h<est_note_diam/2 && (tmp_obj_bbox(4)<min(stave_priors) || tmp_obj_bbox(4)>max(stave_posts))
                rectangle('Position',tmp_obj_bbox,'EdgeColor','r');
            elseif isempty(tmp_detected_notes)
                rectangle('Position',tmp_obj_bbox,'EdgeColor','r');
            else
                rectangle('Position',tmp_obj_bbox,'EdgeColor','g');
                scatter(tmp_obj_bbox(1)+tmp_detected_notes(find(tmp_detected_notes(:,3)==1),1),tmp_obj_bbox(2)+tmp_detected_notes(find(tmp_detected_notes(:,3)==1),2),'g');
                scatter(tmp_obj_bbox(1)+tmp_detected_notes(find(tmp_detected_notes(:,3)==2),1),tmp_obj_bbox(2)+tmp_detected_notes(find(tmp_detected_notes(:,3)==2),2),'b');
                scatter(tmp_obj_bbox(1)+tmp_detected_notes(find(tmp_detected_notes(:,3)==3),1),tmp_obj_bbox(2)+tmp_detected_notes(find(tmp_detected_notes(:,3)==3),2),'r');
                % Determine length of notes
                tmp_obj_note_info = getSingleNoteLengths(tmp_detected_notes,canvas_obj_bbox,est_note_diam,max(stave_line_widths));
                tmp_obj_note_info(:,1:2) = [tmp_obj_note_info(:,1)+tmp_obj_bbox(1),tmp_obj_note_info(:,2)+tmp_obj_bbox(2)];
                scatter(tmp_obj_note_info(:,1),tmp_obj_note_info(:,2),'g')
                % Find nearby lengthen dot indicators
                lengthen_indicator = 0;
                if tmp_obj_bbox(2) > est_note_diam && mean(mean(segment_image((round(tmp_obj_note_info(:,2)-est_note_diam*3/4)):round((tmp_obj_note_info(:,2)-est_note_diam/4)),round(tmp_obj_note_info(:,1)+est_note_diam*3/4):round((tmp_obj_note_info(:,1)+est_note_diam*5/4))))) > 0.2
                    scatter(tmp_obj_note_info(:,1)+est_note_diam*3/4,tmp_obj_note_info(:,2)-est_note_diam*3/4,1,'m')
                    scatter(tmp_obj_note_info(:,1)+est_note_diam*5/4,tmp_obj_note_info(:,2)-est_note_diam/4,1,'m')
                    scatter(tmp_obj_note_info(:,1)+est_note_diam,tmp_obj_note_info(:,2)-est_note_diam/2,'m')
                    lengthen_indicator = 1;
                end
                if (tmp_obj_bbox(2)+tmp_obj_bbox(4)+est_note_diam) < size(segment_image,1) && mean(mean(segment_image(round(tmp_obj_note_info(:,2)+est_note_diam/4):round(tmp_obj_note_info(:,2)+est_note_diam*3/4),round(tmp_obj_note_info(:,1)-est_note_diam*5/4):round(tmp_obj_note_info(:,1)-est_note_diam*3/4)))) > 0.2
                    scatter(tmp_obj_note_info(:,1)-est_note_diam*3/4,tmp_obj_note_info(:,2)+est_note_diam*3/4,1,'m')
                    scatter(tmp_obj_note_info(:,1)-est_note_diam*5/4,tmp_obj_note_info(:,2)+est_note_diam/4,1,'m')
                    scatter(tmp_obj_note_info(:,1)-est_note_diam,tmp_obj_note_info(:,2)+est_note_diam/2,'m')
                    lengthen_indicator = 1;
                end
                if lengthen_indicator
                    tmp_obj_note_info(:,3) = (tmp_obj_note_info(:,3).^(-1)).*1.5;
                else
                    tmp_obj_note_info(:,3) = tmp_obj_note_info(:,3).^(-1);
                end
                tmp_obj_note_info(find(tmp_obj_note_info(:,3)==Inf),3) = 0;
            end
        end
        if tmp_obj_bbox_w>=est_note_diam*2.5
            if tmp_obj_bbox_h<est_note_diam*2
                rectangle('Position',tmp_obj_bbox,'EdgeColor','r');
            else
            	rectangle('Position',tmp_obj_bbox,'EdgeColor','b');
                canvas_hor_proj = sum(canvas_obj_bbox);
                % Handle filled notes
                if ~isempty(tmp_detected_notes)
                    scatter(tmp_obj_bbox(1)+tmp_detected_notes(find(tmp_detected_notes(:,3)==1),1),tmp_obj_bbox(2)+tmp_detected_notes(find(tmp_detected_notes(:,3)==1),2),'g');
                    scatter(tmp_obj_bbox(1)+tmp_detected_notes(find(tmp_detected_notes(:,3)==2),1),tmp_obj_bbox(2)+tmp_detected_notes(find(tmp_detected_notes(:,3)==2),2),'b');
                    scatter(tmp_obj_bbox(1)+tmp_detected_notes(find(tmp_detected_notes(:,3)==3),1),tmp_obj_bbox(2)+tmp_detected_notes(find(tmp_detected_notes(:,3)==3),2),'r');
                    % Determine length of notes
                    tmp_obj_note_info = getGroupNoteLengths(tmp_detected_notes,canvas_obj_bbox,est_note_diam,max(stave_line_widths));
                    tmp_obj_note_info(:,1:2) = [tmp_obj_note_info(:,1)+tmp_obj_bbox(1),tmp_obj_note_info(:,2)+tmp_obj_bbox(2)];
                    scatter(tmp_obj_note_info(:,1),tmp_obj_note_info(:,2),'g')
                    tmp_obj_note_info(:,3) = tmp_obj_note_info(:,3).^(-1);
                    tmp_obj_note_info(find(tmp_obj_note_info(:,3)==Inf),3) = 0;
                end
%                 % Test horizontal projection feature vectors (Optional)
%                 canvas_hor_proj = cat(2,0,canvas_hor_proj);
% %                 canvas_hor_proj = imfilter(canvas_hor_proj,[0.5 0 0.5],'same');
% %                 figure(); plot(canvas_hor_proj);
%                 canvas_hor_proj_grad = canvas_hor_proj(2:end)-canvas_hor_proj(1:(end-1));
%                 canvas_hor_proj_grad(find(canvas_hor_proj_grad<0)) = 0;
%                 canvas_hor_proj_grad(find(canvas_hor_proj_grad<mean(canvas_hor_proj_grad)+3*std(canvas_hor_proj_grad,1))) = 0;
%                 [~,canvas_hor_proj_grad_pks] = findpeaks(cat(2,0,canvas_hor_proj_grad));
%                 canvas_hor_proj_grad_pks = canvas_hor_proj_grad_pks-1;
% %                 mean(canvas_hor_proj_grad)
% %                 std(canvas_hor_proj_grad,1)
% %                 figure(); plot(canvas_hor_proj_grad);
%                 text(tmp_obj_bbox(1)+10,tmp_obj_bbox(2)+10,sprintf('%d',size(canvas_hor_proj_grad_pks,2)),'Color',[0 1 0])
            end
        end
%         % Filter out super thin/small boxes and/or crazy ratios (Optional)
%         if tmp_obj_bbox_h>mean(stave_line_widths) && tmp_obj_bbox_w>mean(stave_line_widths) && tmp_obj_bbox_w/tmp_obj_bbox_h<50 && tmp_obj_bbox_h/tmp_obj_bbox_w<50
%             music_obj_bbox = cat(1,music_obj_bbox,tmp_obj_bbox);
%             % Label oversized bounding boxes
%             if size(tmp_obj_pixel_coor,1)<0.4*tmp_obj_bbox_h*tmp_obj_bbox_w
%                 rectangle('Position',tmp_obj_bbox,'EdgeColor','r');
%             else
%                 rectangle('Position',tmp_obj_bbox,'EdgeColor','b');
%             end
%             rectangle('Position',tmp_obj_bbox,'EdgeColor','r');
%         end
        segment_note_info = cat(1,segment_note_info,tmp_obj_note_info);
    end
    hold off;
    % Save staff lines and note information
    segments{i}.note_info = segment_note_info;
    segments{i}.stave_mids = stave_mids;
    segments{i}.segment_mid = segment_mid;
end

end

