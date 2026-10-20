function [xcon,ncon] = GetConsecutiveValues(x)

if nargin < 1
    error('Wrong input argument list.');
end

x = x(:);
d = [1;diff(x)] ~= 0;

ncon = diff([find(d);length(x)+1]);
xcon = x(d);

end