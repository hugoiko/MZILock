clear;
clc;

nbits = 8;

N = 1e6;

x = round((2^(2*nbits-1)-1)*(2*rand(N,1)-1));

q1 = zeros(size(x));
q1state = 0;
q1error0 = 0;
q1error1 = 0;
for i = 1:numel(x)
    q1state = 2*q1error0 - q1error1 + x(i);
    ipart = floor(q1state/(2^nbits));
    q1error1 = q1error0;
    q1error0 = q1state - ipart*(2^nbits);
    q1(i) = ipart;
end

q2 = zeros(size(x));
q2state = 0;
q2error0 = 0;
q2error1 = 0;
for i = 1:numel(x)
    q2state = 2*q2error0 - q2error1 + q1(i);
    ipart = floor(q2state/(2^nbits));
    q2error1 = q2error0;
    q2error0 = q2state - ipart*(2^nbits);
    q2(i) = ipart;
end

q3 = zeros(size(x));
q3state = 0;
q3error0 = 0;
q3error1 = 0;
for i = 1:numel(x)
    q3state = 2*q3error0 - q3error1 + q2(i);
    ipart = floor(q3state/(2^nbits));
    q3error1 = q3error0;
    q3error0 = q3state - ipart*(2^nbits);
    q3(i) = ipart;
end

hold all;
plot(cumsum(cumsum(x))/(2^(3*nbits)))
plot(cumsum(cumsum(q3)))

