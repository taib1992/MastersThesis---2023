function [norm_super_frame] = norm_frame(super_frame,cal_avg,arb_avg)

if cal_avg
    avg = mean(super_frame(1,:));
else 
    avg = arb_avg;
end

norm_super_frame = zeros(size(super_frame));

for i=1:size(super_frame,2) % going through the frames
    background = mean(super_frame(1:140,i));
    background_shift = avg - background;
    norm_super_frame(:,i) = super_frame(:,i)+background_shift;
end

end

