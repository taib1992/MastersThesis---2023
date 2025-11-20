function [x,y,intensity,amplitude,fwhm,bg] = estimateFWHM_localization(img,fwhm0,isplot)
%ESTIMATEFRINGEPERIOD determines
%the fringe period present in the image stack.
%
% Inputs:
%       img:    image stack  - (Nx,Ny,Nt)

% Outputs:
%       fwhm:   list of full-width-half-maximum
%
if nargin<2
    fwhm0=3.1;
    isplot=false;
elseif nargin<3
    isplot=false;
end
[~,~,Nt]=size(img);
nseg_max=350; % maximum number of beads per raw image frame

% normalize the image stack between 0 and 1
img = (img - min(img(:))) / (max(img(:)) - min(img(:)));
x=cell(Nt,1);y=x;fwhm=x;amplitude=x;bg=x;

% finding all segments
for n=1:Nt
    clear segData a nseg;
    segData = dataSegments(img(:,:,n),fwhm0);
    
    %figure,histogram(segData.segA,10);title('Area');
    %figure,histogram(segData.segE,50);title('Summed Intensity')
    %figure,histogram(segData.yoAbsoluteDec,25);title('Position')
    x = segData.xoAbsoluteDec;
    y = segData.yoAbsoluteDec;
    
%     [~,ii]=sort(sum(reshape(segData.d,[size(segData.d,1)*size(segData.d,2),size(segData.d,3)]),1),'descend'); % index of the brightest beads
%     a= segData.ru-1;
%     nseg=size(segData.d,3);
%     fprintf('nseg: %1.1f \n',nseg);
%     xo=zeros(min(nseg,nseg_max),1);yo=xo;w=xo;A=xo;b=xo;%r=xo;bg=xo;
%     
%     for m=1:min(nseg,nseg_max)
%         %fitGaussian2D_LS has a (0,0) reference for pixel in lower left corner
%         [xo(m),yo(m),A(m),w(m),b(m)]=fitGaussian2D_LS(double(segData.d(:,:,ii(m))), segData.ru-0.5, segData.ru-0.5, segData.d(segData.ru,segData.ru,ii(m)), segData.ru/2.3548, segData.bg, 'xyAsc'); 
%         xo(m)=(segData.xoAbsolute(ii(m))+xo(m)-a);
%         yo(m)=(segData.yoAbsolute(ii(m))+yo(m)-a);
%     end
%     
%     jj = w<1 | w>30; % filter out
%     xo(jj)=[];yo(jj)=[];A(jj)=[];b(jj)=[];w(jj)=[];
%     x{n}=xo;y{n}=yo;amplitude{n}=A;fwhm{n}=2*sqrt(2*log(2))*w;bg{n}=b;
    if isplot
        figure('color',[1 1 1]),imagesc(img(:,:,n));hold on;text(y,x,num2str(2*sqrt(2*log(2))*segData.segE,3),'color','g');colormap gray;%scatter(yo,xo,'r.');
        if ~mod(n,30);h=figure;title('close this figure to close all others and proceed');waitfor(h);close all;end;
    end
    intensity =2*sqrt(2*log(2))*segData.segE;
%     fprintf('Progress... %1.2f %% \n',100*n/Nt);
end

end


% [k,l,Nt]=size(img);
% fRes = 7;
% Ihr=zeros(k*fRes,l*fRes);

% inside the for m=1:nseg loop
%         if w(m) < 3
%             sigmaE2 = 1;
%             s = round(2*sqrt(sigmaE2));
% 
%             if s < 20
%                 x0=fRes*xo(m);x00=round(x0);
%                 y0=fRes*yo(m);y00=round(y0);
% 
%                 if x00-s >= 1 && x00+s <= k*fRes && y00-s >= 1 && y00+s <= l*fRes
%                     [x,y]=meshgrid((-s:s),(-s:s));
%                     Ihr((x00-s:x00+s),(y00-s:y00+s))=Ihr((x00-s:x00+s),(y00-s:y00+s))+1/(2*pi*sigmaE2)*exp(-((x+x00-x0).^2+(y+y00-y0).^2)./(2*sigmaE2));
%                 end
%             end
%         end