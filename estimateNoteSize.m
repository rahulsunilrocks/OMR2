function est_note_diam = estimateNoteSize(segments)
% Return an estimated diameter of notes. Compute by performing Hough Circle
% Transform over the sheets and return 2 times the median detected radii.
% 5,15 Radius range empirically chosen for our sheet image set size.
sheet_circ_radii = [];
for i=1:size(segments,2)
    segment_image = 1-segments{i}.image;
    [circ_centers,circ_radii] = imfindcircles(segment_image,[5,15],'Method','TwoStage');
    sheet_circ_radii = cat(1,sheet_circ_radii,circ_radii);
%     figure(); imshow(segment_image); hold on; viscircles(circ_centers, circ_radii,'EdgeColor','g'); hold off;
end
est_note_diam = 2*median(sort(sheet_circ_radii));

end

