%% Analysis of Single-molecule SDS page data
clear 
close all
clc

filename='super_frame_2524.tiff';
addpath(genpath('Segmentation'));

%%
close all
img=double(imread(filename));

fwhm0=2.5;plot=true;
[x,y,amplitude,fwhm,bg] = estimateFWHM_localization(img,fwhm0,plot);

min_f = min(img,[],'all');
max_f = max(img,[],'all');
figure
imshow(img,[min_f,5000]); hold on
x = round(x);
y = round(y);
plot(y,x,'r+');

