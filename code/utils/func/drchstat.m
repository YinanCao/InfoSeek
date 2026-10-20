function [M,V] = drchstat(a)
%  DRCHSTAT  Mean and variance for the Dirichlet distribution
a0 = sum(a);
M = a./a0;
V = -a*a';
V = V - diag(diag(V))+diag(a.*(a0-a));
V = V./((a0+1)*a0^2);