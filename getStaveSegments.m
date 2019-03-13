function segments = getStaveSegments(image)
% Divide sheet image vertically into segments containing a set of staff
% lines. Return segment images and associated staff line templates.

%% Gaussian blur
gaussian_filter = fspecial('gaussian',[5 5],2);
image_gaussian_filtered = imfilter(image,gaussian_filter,'same');

%% Find stave lines
% Retrieve binary image information, averaged horizontally
image_binary = im2bw(image,mean(image(:)));
scan_line = 1-mean(image_binary,2);
% Filter peaks for stave lines
scan_peak_thresh = mean(scan_line)+2*std(scan_line,1);
scan_filtered = (scan_line>scan_peak_thresh);
[scan_peak_idx,scan_peak_locs] = findpeaks(double(scan_filtered));
% Visualize stave lines
figure(); imshow(image_binary);
hold on; 
for i=1:size(scan_peak_locs,1)
    plot([1;size(image,2)],[scan_peak_locs(i,1);scan_peak_locs(i,1)],'r');
end
hold off;

%% Compute whitespace widths and find music staff sections
whitespace_widths = [scan_peak_locs',size(image,1)]-[0,scan_peak_locs'];
med_whitespace_width = median(sort(whitespace_widths));
% whitespace_idx = kmeans(whitespace_widths,3,'Start','uniform');
whitespace_measure_filtered = imfilter(whitespace_widths,[1,1,1,1,0,-1,-1,-1,-1],'same');
music_segment_whitespace_idx = find(abs(whitespace_measure_filtered)<4);
num_staff_sections_per_line = 2;
% Add top and bottom of image to scan peak locations
scan_peak_locs = [0;scan_peak_locs;size(image,1)];
music_segment_whitespace_idx = music_segment_whitespace_idx(1:2:size(music_segment_whitespace_idx,2));
music_segment_locs = scan_peak_locs(music_segment_whitespace_idx)'+floor(whitespace_widths(music_segment_whitespace_idx)./2);
% Visualize music staff sections
hold on; 
for i=1:size(music_segment_locs,2)
    plot([1;size(image,2)],[music_segment_locs(1,i);music_segment_locs(1,i)],'m');
end
hold off;

%% Localise each segment and corresponding staff line information
segments = {};
segment_idx = 1;
% mean_line = 
for i=1:size(music_segment_locs,2)
    % Trim top of segment
    segment_top = scan_peak_locs(music_segment_whitespace_idx(i)-5+1);
    top_scan_line = flipud(scan_line(1:segment_top-1));
    top_scan_line_zeros = find(top_scan_line==0);
    segment_top = segment_top-top_scan_line_zeros(1,1);
    % Trim bottom of segment
    segment_bottom = scan_peak_locs(music_segment_whitespace_idx(i)+5);
    bottom_scan_line = scan_line((segment_bottom+1):end);
    bottom_scan_line_zeros = find(bottom_scan_line==0);
    segment_bottom = segment_bottom+bottom_scan_line_zeros(1,1);
    % Get filtered scan line of segment for stave lines
    segments{segment_idx}.stave_lines = double(scan_filtered(segment_top:segment_bottom,1));
    % Save segment
    segments{segment_idx}.image = double(image_binary(segment_top:segment_bottom,:));
    segments{segment_idx}.segment_mid = double(music_segment_locs(1,i)-segment_top);
    segment_idx = segment_idx+1;
end

end

