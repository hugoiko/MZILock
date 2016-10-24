clear;
clc;


mant_bits = 16;
base_bits = 8;
expo_bits = 2;

base = 2^base_bits;

total_bits = mant_bits+expo_bits;
N_gains = 2^total_bits;

gains = zeros(N_gains, 1);

k = 0;
for j = 0:(2^expo_bits-1)
    for i = (-2^(mant_bits-1)):(2^(mant_bits-1)-1)
        gain = i*base^j;
        gains(k+1) = gain;
        k = k + 1;
    end
end

sorted_gains = gains; %sort(gains);

semilogy(sorted_gains)

%%
fpoint = single(1.999);
fid = fopen('test.bin','wb');
fwrite(fid, fpoint, 'float');
fclose(fid);
fid = fopen('test.bin','rb');
bytes = fread(fid,1,'uint32');
fclose(fid);
bitvect = reshape(dec2bin(flipud(bytes), 32), 1, 32);
signbit  = bitvect(1);
exponent = bitvect(2:9);
mantissa = bitvect(10:32);

fprintf('%s %s %s\n', signbit, exponent,mantissa);
vals = [(1-bin2dec(signbit)*2), 2^(bin2dec(exponent)-127), (1+bin2dec(mantissa)/(2^23))];
fprintf('(%+1i) 2^(%+3i) %f = %f\n', vals(1), log2(vals(2)), vals(3), prod(vals));













