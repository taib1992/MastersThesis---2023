function [super_frame] = creat_super_frame(expe_name)
% The function takes a single pixel column from the every tiff file from
% the experiment and concatenates it to a single image
% EXAMPLE:
% expe_name = '384'

expe_path = ['E:\SDS image processing\experiments\',expe_name];
table_frames = dir([expe_path,'\*.tiff']);
num_frames = size(table_frames,1);

% determining the image size
sample_image = imread([expe_path,'\',table_frames(1).name]);
[row,col] = size(sample_image);

% seting super frame
super_frame = zeros([row,num_frames-1]);
for i=1:num_frames-1 % going through the frames
    frame_path = [expe_path,'\Frame',num2str(i),'.tiff'];
    frame = imread(frame_path); % reading image
    v = frame(:,(col+6)/2);
    %v = normalizeArray(double(v));
    super_frame(:,i) = v; % copying the pixels
end


end

