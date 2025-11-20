function create_mov(mov_name,frame_rate,f_start,f_end,frame_names,channel,bg_on)
% creating a movie from the frame range

n_ch = numel(channel);

for ch=1:n_ch
    % create the video writer with 20 fps
    writerObj = VideoWriter([mov_name,'_',num2str(ch),'.avi']);
    writerObj.FrameRate = frame_rate;

    % open the video writer
    open(writerObj);

    % chosing the next img from the set
    if mod(f_start-channel(ch).start_frame,2)
        f_start = f_start+1;
    end
    % going through all the frames
    for i=f_start:n_ch-1:f_end
      % read frame
      img = double(imread(frame_names{i}));
      img = img(channel(ch).img_range)-(bg_on*channel(ch).bg_map);
      img = max(img,0);
      %frame = img/max(img(:));
      frame = norm_image_by_range(img,[3000,3500]);
      writeVideo(writerObj, frame);
    end

    % close the writer object
    close(writerObj);
end