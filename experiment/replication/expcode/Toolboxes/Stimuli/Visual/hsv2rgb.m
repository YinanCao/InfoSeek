function [rgb] = hsv2rgb(hsv)

% https://en.wikipedia.org/wiki/HSL_and_HSV
%
% H in [0,360]
% S in [0,1]
% V in [0,1]

% C  = V*S
% H' = H/60
% X  = C*(1-abs(mod(H',2)-1))
% m  = V-C

% (R',G',B') = 

hsv(:,1) = mod(hsv(:,1),360);
hsv(:,2) = min(max(hsv(:,2),0),1);
hsv(:,3) = min(max(hsv(:,3),0),1);

h = hsv(:,1)/60;
c = hsv(:,2).*hsv(:,3);
x = c.*(1-abs(mod(h,2)-1));
m = hsv(:,3)-c;

rgb = zeros(size(hsv));
i = h >= 0 & h < 1; n = nnz(i);
rgb(i,:) = [c(i,:),x(i,:),zeros(n,1)];
i = h >= 1 & h < 2; n = nnz(i);
rgb(i,:) = [x(i,:),c(i,:),zeros(n,1)];
i = h >= 2 & h < 3; n = nnz(i);
rgb(i,:) = [zeros(n,1),c(i,:),x(i,:)];
i = h >= 3 & h < 4; n = nnz(i);
rgb(i,:) = [zeros(n,1),x(i,:),c(i,:)];
i = h >= 4 & h < 5; n = nnz(i);
rgb(i,:) = [x(i,:),zeros(n,1),c(i,:)];
i = h >= 5 & h < 6; n = nnz(i);
rgb(i,:) = [c(i,:),zeros(n,1),x(i,:)];

rgb = bsxfun(@plus,rgb,m);

end