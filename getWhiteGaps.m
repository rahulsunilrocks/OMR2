function [white_gaps_above,white_gaps_below] = getWhiteGaps(coord,canvas)
%GETWHITEGAPS Summary of this function goes here
%   Detailed explanation goes here

upper_scan_line = canvas(1:(coord(2)-1),coord(1));
upper_scan_line = upper_scan_line([1,diff(upper_scan_line')]~=0);
% upper_scan_line = upper_scan_line(1:(end-1),1);
upper_scan_line

lower_scan_line = canvas((coord(2)+1):end,coord(1));
lower_scan_line = lower_scan_line([1,diff(lower_scan_line')]~=0);
% lower_scan_line = lower_scan_line(1:(end-1),1);
lower_scan_line

white_gaps_above = 0;
white_gaps_below = 0;

end

