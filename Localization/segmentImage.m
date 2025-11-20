%[S,n]=segmentImage(I)
%---------------------
%
%Segment an image I and return the segment map S and the number of segments n.
%
function [I,n]=segmentImage(I)
I(end+1,end+1)=0;

% Copyright ? 2011 Stefan Geissbuehler
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.


%
% Segment along x
%
a=find(I); % 1D indexes (first column then second and so on) exhibiting signal
I(a)=cumsum([1;diff(a) > 1]); 
% diff(a)>1: logical array of 1s between signals: [0;0;0;0;1;0;0;0;0;1 ..]
% cumsum([1;diff(a)>1]: creates region: [1;1;1;1;1;2;2;2;2;3;3;3;3;4...]
I=I.'; % transpose

%
% Segment along y
%
a=find(I);
b=I(a); % 1D indexes (first column then second and so on) exhibiting signal
% a are logical indexes. Therefore, if two successive values >0 in y axis (no longer x since I=I.'),
% diff(a)=1. 
for n=find(diff(a) == 1).'
   b(b == b(n+1))=b(n); % attributes a single unique value per segment.
end
% basically, we had before "segment along y": each segment was divided into k
% columns and l lines. Each line had the same value, but each column
% a different. b(n+1)=b(n) makes sure that now each column took the value
% of the top line so that now each 2D segment has a distinct value
%
% Enumerate segments
%
c=unique(b); % removes the same values (i.e. to get one value per segment: in other words, the index of the top left corner of the sub-image/segment)
n=numel(c); % total # of segments
d=zeros(c(end),1); 
d(c+0)=1:n;          % avoid logicals
I(a)=d(b+0); % numbers segments
I=I(1:end-1,1:end-1).';
