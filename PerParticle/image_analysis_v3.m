% image processing for SDS nanogel analysis
clear all;
close all;
clc;

%% add folders
addpath(genpath('experiments'));
addpath(genpath('Localization'));
addpath(genpath('Utils'));
%addpath(genpath('Results'));

%%

% selecting experiment, choose the experiment name as writen in the
% experiments file
expe_name = 'ova_ca_1.7mm';

%%

% geting all the frames in the folder

experiment_path = [pwd,'\experiments\',expe_name,'\'];
%experiment_path = ['C:\Users\97252\Desktop\Masters\Thesis\Amiting-1.2.21\video_0.7mm_ca_ova'];
table_frames = dir([experiment_path,'\*.tiff']);
frame_names = strcat(experiment_path,natsortfiles({table_frames.name}));
num_frames = size(table_frames,1);

%%
% visualzing a sample image to set limits for the experiment.

for frame_idx = 1:2 % sample frame
    frame = imread(frame_names{frame_idx});
    figure
    clims = [min(frame(:)) max(frame(:))];
    imagesc(frame,clims); colormap gray; colorbar;
end

%%
% laser pairing and limits

num_channels = 2;

% for 532 laser:
c_532.uper_lim = 30; c_532.low_lim = 200;
c_532.left_lim = 50; c_532.right_lim = 450;
c_532.img_range = range2index(size(frame),c_532.low_lim,c_532.uper_lim,c_532.left_lim,c_532.right_lim);
c_532.start_frame = 1;
c_532.bg_map = create_bg_map(c_532.img_range,c_532.start_frame,num_channels,frame_names);
c_532.particle_data = {};

% for 640 laser:
c_640.uper_lim = 305; c_640.low_lim = 470;
c_640.left_lim = 50; c_640.right_lim = 450;
c_640.img_range = range2index(size(frame),c_640.low_lim,c_640.uper_lim,c_640.left_lim,c_640.right_lim);
c_640.start_frame = 1;
%frame = imread([experiment_path,'\Frame',num2str(c_640.start_frame),'.tiff']);
c_640.bg_map = create_bg_map(c_640.img_range,c_640.start_frame,num_channels,frame_names);
c_640.particle_data = {};

% struct array

channel = [c_532,c_640];

%%

% set of frames detection analysis
for j=2%1:num_channels
    LoG_fwhm =3;
    bgth_factor = 2;
    frame_vec = channel(j).start_frame:1:num_frames;
    prs_val= 1;
    tot_frames = numel(frame_vec);
    
    pro_bar = waitbar(prs_val/tot_frames,"analysing frames...");
    
    for i=frame_vec
        
        frame = imread([experiment_path,'Frame',num2str(i),'.tiff']);
        frame = double(frame(channel(j).uper_lim:channel(j).low_lim,channel(j).left_lim:channel(j).right_lim));
        [x,y,p_size,energy] = particle_detection_2(frame,channel(j).bg_map,LoG_fwhm,bgth_factor);
        frame_table = table(x,y,p_size,energy);
        % size filter
        min_size = 1; max_size = 100;
        size_filter = p_size>min_size & p_size<max_size;
        
        %saving after filtering
        channel(j).particle_data{i} = frame_table(size_filter,:);
        
        % progress
        waitbar(prs_val/tot_frames,pro_bar,"analysing frames...");
        prs_val = prs_val+1;
        
    end
    close(pro_bar)
end



%%

% visualzing frame data on the frame and creating video

for j=2:num_channels
    % create the video writer with 20 fps
    writerObj = VideoWriter([num2str(j),'testVideo.avi']);
    writerObj.FrameRate = 20;
    
    % open the video writer
    open(writerObj);
    
    prs_val= 1;
    frame_vec = channel(j).start_frame:1:num_frames;
    tot_frames = numel(frame_vec);
    
    pro_bar = waitbar(prs_val/tot_frames,"creating movie...");
    
    
    for i=frame_vec
        frame = imread([experiment_path,'\Frame',num2str(i),'.tiff']);
        F = figure('WindowState','maximized');
        clims = [min(frame(:)) max(frame(:))];
        imagesc(frame(channel(j).uper_lim:channel(j).low_lim,channel(j).left_lim:channel(j).right_lim),clims); colormap gray;
        hold on
        plot(channel(j).particle_data{i}.y,channel(j).particle_data{i}.x,'+r')
        m_frame = getframe;
        writeVideo(writerObj, m_frame.cdata);
        
        %progress
        waitbar(prs_val/tot_frames,pro_bar,"creating movie...");
        prs_val = prs_val+1;
        close(F)
        
    end
    % close the writer object
    close(writerObj);
    close(pro_bar)
end


%%
j=2;
frame_vec = channel(j).start_frame:1:num_frames;
for colInd=median(channel(j).left_lim:channel(j).right_lim)
    for i=frame_vec
        frame = imread([experiment_path,'\Frame',num2str(i),'.tiff']);
        frame=frame(channel(j).uper_lim:channel(j).low_lim,channel(j).left_lim:channel(j).right_lim);
        %colInd=median(channel(j).left_lim:channel(j).right_lim);
        allVid(:,i)=frame(:,colInd);
    end
    min_val=min(min(allVid(:,1:100)));
    max_val=max(max(allVid(:,1:100)));
    clims = [min(min(allVid(:,1:100))) max(max(allVid(:,1:100)))];
    figure; 
    subplot(2,1,1);
    imagesc(allVid,clims)
    colormap(gray);
    subplot(2,1,2);
    colSum=sum(allVid);
    norm_colSum=(colSum-min(colSum))./(max(colSum)-min(colSum));
    plot(norm_colSum);
end
