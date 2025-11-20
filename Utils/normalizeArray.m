function [y] = normalizeArray(v)
y=(v-min(v(:)))/(max(v(:))-min(v(:)));
end

