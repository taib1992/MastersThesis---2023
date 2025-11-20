function [x,y,size,energy] = particle_detection_2(frame,bg_frame,LoG_fwhm,bgth_factor)
% finds the location (x and y), size and energy of particals in a frame.
% the x and y are in pixels as well as the size. the energy is in photon
% count.

% normalzing the images
frame = double(frame); bg_frame = double(bg_frame);
frame_norm = (frame)/(prctile(frame(:),95));
%frame_norm = (frame-min(frame(:)))/(max(frame(:))-min(frame(:)));
bg_frame_norm = bg_frame/max(bg_frame(:));

% using LoG filter on both images
frame_log = LaplacianOfGaussian(frame_norm,LoG_fwhm/sqrt(2));
%figure,imagesc(frame_log);axis square;
bg_frame_log = LaplacianOfGaussian(bg_frame_norm,LoG_fwhm/sqrt(2));
%figure,imagesc(bg_frame_log);axis square;

%reducing the max from the background
bgth = min(bg_frame_log(:)*bgth_factor);
mask = double(frame_log<bgth);
frame_seg = frame.*mask;
%figure,imagesc(frame_seg);axis square;title('Background subtracted');

%segment processed image
if any(frame_seg(:))
    [S,n]=segmentImage(frame_seg);
%figure,imagesc(S);axis square;
%imagesp((S>0),'Segments');
%imagesp(S,'Segments');

%analyze segments
    [x,y,size,energy]=analyzeSegments(S,frame,n,0); %always ms=0
else
    x = [];
    y = [];
    size = [];
    energy = [];
end

