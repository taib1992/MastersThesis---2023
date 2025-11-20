function [bg_map] = create_bg_map(img_range,start_frame,num_channels,frame_names,frame_vec)
bg_frames=[];
if ~exist('frame_vec','var')
    frame_vec = start_frame:num_channels:(1*num_channels);
else
    frame_vec=frame_vec(1:100);
end
[r,c] = size(img_range);
for i=1:length(frame_vec)
    frame = imread(frame_names{frame_vec(i)});
    bg_frames(:,:,i) = frame(img_range);
end
%bg_map = mean(bg_frames,3);
bg_map = max(bg_frames,[],3);
end
        