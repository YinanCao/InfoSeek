function samples = truncated_exponential(t_min, t_max, t_mean, N)
    lambda = 1 / (t_mean - t_min);
    % Normalization constant C
    C = exp(-lambda * t_min) - exp(-lambda * t_max);
    % Generate N uniform random numbers U
    U = rand(N, 1);
    % Apply inverse transform sampling to generate the truncated exponential samples
    samples = -log((1 - U) * C + exp(-lambda * t_max)) / lambda;
    % Ensure that the samples are within the specified range
    samples = max(min(samples, t_max), t_min);
end