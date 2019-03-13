function segments = trimNotes(segments,est_note_diam)
% Trim off edges from notes that are grouped by beams, helps for second
% grouping based on connectivity

for i=1:size(segments,2)
    % Retrieve segment information
    segment_image = 1-segments{i}.image;
    segment_stave_lines = segments{i}.stave_lines;
    % Find y coordinates right before and right after stave lines and other
    % useful information from stave lines
    vert_grad = segment_stave_lines(2:end)-segment_stave_lines(1:(end-1));
    stave_priors = find(vert_grad>0);
    stave_posts = find(vert_grad<0)+1;
    stave_line_widths = stave_posts-stave_priors-1;
    staff_height = max(stave_posts)-min(stave_priors);
    segment_mid = segments{i}.segment_mid+round(mean(stave_line_widths))-round(mean(stave_line_widths)/2);
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
    end
    % Get bounding box of music objects via flood fill
    music_obj_cc = bwconncomp(segment_image);
    music_obj_im = {};
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
        if tmp_obj_bbox_w>=est_note_diam*2 && tmp_obj_bbox_h>est_note_diam*2
            canvas_hor_proj = sum(canvas_obj_bbox);
            extra_stave_line = find(canvas_hor_proj<=max(stave_line_widths)+1);
%             imshow(canvas_obj_bbox)
            for k=1:size(extra_stave_line,2)
                segment_image(tmp_obj_bbox(2):(tmp_obj_bbox(2)+tmp_obj_bbox(4)-1),tmp_obj_bbox(1)+extra_stave_line(k)-1) = segment_image(tmp_obj_bbox(2):(tmp_obj_bbox(2)+tmp_obj_bbox(4)-1),tmp_obj_bbox(1)+extra_stave_line(k)-1)-canvas_obj_bbox(:,extra_stave_line(k));
            end
        end
    end
    % Filter out some additional noise (super small pixels)
    segment_image = double(bwareaopen(segment_image,5*5));
    segments{i}.image = 1-segment_image;
end

