function [n_frame] = norm_image_by_range(img,range)
% normelized the image with range of min and max from the user and also
% scaled from 0 to 1

n_frame = img;
min_idx = img <= min(range);
max_idx = img >= max(range);
n_frame(min_idx) = 0;
n_frame = n_frame/max(range);
n_frame(max_idx) = 1;

