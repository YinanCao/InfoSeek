function [patch] = CreatePlaceholder(diameter,width,anglelist,colorlist,lumibg)

if nargin < 5
    error('missing input argument(s)!');
end

if mod(diameter,2) ~= 0
    error('diameter should be even!');
end
if width < 4
    error('width should be larger than 4 pixels!');
end
if ~isvector(anglelist)
    error('anglelist should be a vector!');
end
if ndims(colorlist) ~= 2 || ~all(size(colorlist) == [length(anglelist),3])
    error('colorlist should be sized [n,3], where n is the length of anglelist!');
end
if lumibg < 0 || lumibg > 1
    error('lumibg should be in [0,1]!');
end

smoothfun = @(x,dx)dx(1)+diff(dx)./(1+99.^(-x));

[x,y] = meshgrid([1:diameter]-(diameter+1)/2);

r = sqrt(x.^2+y.^2);
t = -atan2(y,x);

n = length(anglelist);
a = zeros(diameter,diameter,n);
for i = 1:n
    a(:,:,i) = (cos(2*(t-anglelist(i)))+1)/2;
end
a = bsxfun(@rdivide,a,sum(a,3));

patchbg = lumibg*ones(diameter,diameter,3);

patchfg = zeros(diameter,diameter,3);
for i = 1:n
    rgb = repmat(reshape(colorlist(i,:),[1,1,3]),[diameter,diameter,1]);
    patchfg = patchfg+rgb.*repmat(a(:,:,i),[1,1,3]);
end
patchfg = patchfg/max(patchfg(:));

patchtp = ones(diameter,diameter);
patchtp = min(patchtp,smoothfun(r-diameter/2+width,[0,1]));
patchtp = min(patchtp,smoothfun(r-diameter/2,[1,0]));
patchtp = repmat(patchtp,[1,1,3]);
patchfg = patchfg.*patchtp+patchbg.*(1-patchtp);

patchtp = ones(diameter,diameter);
patchtp = min(patchtp,smoothfun(r-diameter/2+width,[0,1]));
patchtp = min(patchtp,smoothfun(r-diameter/2+width-2,[1,0]));
patchtp = repmat(patchtp,[1,1,3]);
patchfg = patchfg.*(1-patchtp);

patchtp = ones(diameter,diameter);
patchtp = min(patchtp,smoothfun(r-diameter/2+2,[0,1]));
patchtp = min(patchtp,smoothfun(r-diameter/2,[1,0]));
patchtp = repmat(patchtp,[1,1,3]);
patchfg = patchfg.*(1-patchtp);

patch = patchfg;

end