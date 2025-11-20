% function that converts range of positions to the linare indexing

function [lin_idx] = range2index(frame_size,low,high,left,right)

    [x,y] = meshgrid(high:low,left:right);
    lin_idx = reshape(sub2ind(frame_size,x(:)',y(:)'),[right-left+1,low-high+1])';
    
end
    