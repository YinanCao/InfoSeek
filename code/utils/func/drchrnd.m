function R = drchrnd(a,n)
%  DRCHRND  Random arrays from the Dirichlet distribution
a = reshape(a,1,[]);
p = length(a);
R = gamrnd(repmat(a,n,1),1,n,p);
R = R./repmat(sum(R,2),1,p);
end