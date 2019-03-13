function sheets = getSheets(location)
% Return cell array of loaded music sheet images.
% Each image represents a page of the sheet music. Alphebetical order of
% the named titles of the image files are reserved.

sheets = {};
sheet_idx = 1;
directory = ls(location);
for i=1:size(directory,1)
    try
        im = double(imread(strcat(location,'/',directory(i,:))));
        % Verify single channel
        if size(size(im),2) < 3
            im = im./max(im(:));
        else
            im = rgb2gray(im./max(im(:)));
        end
        % Verify image is not inverted
        if round(mean(im(:)))==0
            im = 1-im;
        end
        sheets{sheet_idx} = imresize(im,[1700*size(im,1)/size(im,2),1700]);
        sheet_idx = sheet_idx+1;
    catch
    end
end
end

