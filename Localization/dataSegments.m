function segData = dataSegments(Id,fwhm)
bg=0.2*(sum(Id(1,:)+Id(end,:))+sum(Id(:,1)+Id(:,end))) / (2*size(Id,1)+2*size(Id,2)); % [gsv]

segData = struct('ru',round(fwhm),'nh',0,'bg',bg);
alol=2;aupl=(2.5*fwhm)^2;

segData=hriSegmentation(Id,fwhm/sqrt(2),segData);
segData=hriFilterSegments(Id,aupl,alol,segData);
    
end

