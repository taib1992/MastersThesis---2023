function [super_frame] = all_frame_analysis(expe_name,first_frame,last_frame)
% The function takes a single pixel column from the every tiff file from
% the experiment and concatenates it to a single image
% EXAMPLE:
% expe_name = '384'

expe_path = ['E:\SDS image processing\experiments\',expe_name];

for i=first_frame:last_frame % going through the frames
    frame_path = [expe_path,'\Frame',num2str(i),'.tiff'];
    frame = imread(frame_path); % reading image
    v = frame(:,(col-6)/2);
    %v = normalizeArray(double(v));
    super_frame(:,i) = v; % copying the pixels
end


end

