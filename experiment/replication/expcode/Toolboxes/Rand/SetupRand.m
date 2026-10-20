function [s] = SetupRand(s)

if nargin < 1
    s = sum(100*clock);
end

if ~exist('RandStream')
    rand('twister',s);
    randn('state',s);
elseif ismethod('RandStream','setGlobalStream')
    RandStream.setGlobalStream(RandStream('mt19937ar','Seed',s));
elseif ismethod('RandStream','setDefaultStream')
    RandStream.setDefaultStream(RandStream('mt19937ar','Seed',s));
end

end