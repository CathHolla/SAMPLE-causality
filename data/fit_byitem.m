%% Set up

data = csvread('ratings.csv');
models = {'ours', 'sp', 'dp', 'icard', 'hh'};
norm = 1;

priors = {@(x) 1/2, @(x) normpdf(x, 0, .25), @(x) 1, @(x) 1};

bounds_full = [0 0 0 0; 10 2 1 1];
numStarts = 10;

%% Fit
lme = zeros(length(models), 1);
lme_bms = zeros(length(models), 1);
parfor modelind = 1:length(models)
    model = models(modelind);
    
    params = 1:2;
    if strcmp(model, 'hh'), params = 2:4; end
    bounds = bounds_full(:,params);

    numParams = length(params);
    starts = zeros(numStarts, numParams);
    for i = 1:numParams
        ub = bounds(2,i);
        lb = bounds(1,i);
        starts(:,i) = rand(numStarts, 1) * (ub-lb) + lb;
    end

    options = optimoptions(@fmincon, 'Display', 'off', 'UseParallel', false);
    options_unc = optimoptions(@fminunc, 'Display', 'Off', 'Algorithm', 'quasi-newton', 'MaxFunEvals', 0);

    f = @(params) -posterior_byitem(params, data, model, priors, norm);
    logposts_starts = zeros(numStarts, 1);
    params_starts = zeros(numStarts, numParams);

    for thisStart = 1:numStarts
        [params_starts(thisStart, :), logposts_starts(thisStart), ~, ~, ~, ~] = ...
            fmincon(f, starts(thisStart, :), [], [], [], [], ...
            bounds(1, 1:numParams), bounds(2, 1:numParams), [], options);
    end

    [~, bestStart] = min(logposts_starts);
    post = -logposts_starts(bestStart);
    optParams = params_starts(bestStart, :);

    [~, ~, ~, ~, ~, hessian] = fminunc(f, optParams, options_unc);
    lme_bms(modelind) = numParams / 2 * log(2*pi) + post - .5 * log(det(hessian));

    %if isnan(lme(xind,aind,modelind)) || isinf(lme(xind,aind,modelind)) || ~isreal(lme(xind,aind,modelind))
    %[~, ll] = posterior_byitem(optParams, data, model);
    %lme(:,:,modelind) = -0.5 * (numParams * (log(size(data,1)) - log(2*pi)) - 2 * ll);
    %end

    %lme_bms(:,modelind) = reshape(lme(:,:,modelind), 100, 1);
end

fits_normed = lme_bms;

%% Run BMS
%[~, modelprobs, ~, pxp, ~] = bms(lme_bms);
%modelprobs
%pxp