function [parameters,fh] = getMultiStarts(parameters, objective_function, varargin)
% getMultiStarts() computes the maximum a posterior estimate of the
% parameters of a user-supplied posterior function. Therefore, a
% multi-start local optimization is used. The parameters from the best 
% value of the posterior function arethen used as the global optimum.
% To ensure that the found maximum is a global one, a sufficiently high
% number of multistarts must be done. Those starts can be initialized with
% either randomly sampled parameter values, following either a uniform
% distribution or a latin hypercube, or they can be sampled by a user
% provided initial function (provided as option.init_fun).
%
% Note: This function can exploit up to (n_start + 1) workers when running
% in 'parallel' mode.
%
% USAGE:
% * [...] = getMultiStarts(parameters,objective_function)
% * [...] = getMultiStarts(parameters,objective_function,options)
% * [parameters,fh] = getMultiStarts(...)
%
% getMultiStarts() uses the following PestoOptions members:
%  * PestoOptions::start_index
%  * PestoOptions::n_starts
%  * PestoOptions::mode
%  * PestoOptions::fh
%  * PestoOptions::fmincon
%  * PestoOptions::rng
%  * PestoOptions::proposal
%  * PestoOptions::save
%  * PestoOptions::foldername
%  * PestoOptions::trace
%  * PestoOptions::comp_type
%  * PestoOptions::tempsave
%  * PestoOptions::resetobjective
%  * PestoOptions::obj_type
%  * PestoOptions::init_threshold
%  * PestoOptions::plot_options
%
% Parameters:
%   parameters: parameter struct
%   objective_function: objective function to be optimized. 
%       This function should accept one input, the parameter vector.
%   varargin:
%     options: A PestoOptions object holding various options for the 
%         algorithm.
%
% Required fields of parameters:
%   number: Number of parameters
%   min: Lower bound for each parameter
%   max: upper bound for each parameter
%   name = {'name1', ...}: names of the parameters
%   guess: initial guess for the parameters (Optional, will be initialized 
%       empty if not provided)
%   init_fun: function to draw starting points for local optimization, must
%       have the structure init_fun(theta_0, theta_min, theta_max).
%       (Only required if proposal == 'user-supplied')
%
% Return values:
%   parameters: updated parameter object
%   fh: figure handle
%
% Generated fields of parameters:
%   MS: information about multi-start optimization
%     * par0(:,i): starting point yielding ith MAP
%     * par(:,i): ith MAP
%     * logPost(i): log-posterior for ith MAP
%     * logPost0(i): log-posterior for starting point yielding ith MAP
%     * gradient(_,i): gradient of log-posterior at ith MAP
%     * hessian(:,:,i): hessian of log-posterior at ith MAP
%     * n_objfun(i): # objective evaluations used to calculate ith MAP
%     * n_iter(i): # iterations used to calculate ith MAP
%     * t_cpu(i): CPU time for calculation of ith MAP
%     * exitflag(i): exitflag the optimizer returned for ith MAP
%     * par_trace(:,:,i): parameter trace for ith MAP
%         (if options.trace == true)
%     * fval_trace(:,i): objective function value trace for ith MAP
%         (if options.trace == true)
%     * time_trace(:,i): computation time trace for ith MAP
%         (if options.trace == true)
%
% History:
% * 2012/05/31 Jan Hasenauer
% * 2012/07/11 Jan Hasenauer
% * 2014/06/11 Jan Hasenauer
% * 2015/07/28 Fabian Froehlich
% * 2015/11/10 Fabian Froehlich
% * 2016/06/07 Paul Stapor
% * 2016/10/04 Daniel Weindl
% * 2016/12/04 Paul Stapor

global error_count

%% Check inputs
if length(varargin) >= 1
    options = varargin{1};
    if ~isa(options, 'PestoOptions')
        error('Third argument is not of type PestoOptions.')
    end
else
    options = PestoOptions();
end

if isempty(options.start_index)
    options.start_index = 1:options.n_starts;
end
parameters = parametersSanityCheck(parameters);

if strcmp(options.localOptimizer, 'fmincon')
    options.localOptimizerOptions = optimset(options.localOptimizerOptions,...
        'MaxFunEvals', 400*parameters.number);
end

%% Initialization and figure generation
fh = [];
switch options.mode
    case 'visual'
        if isempty(options.fh)
            fh = figure('Name', 'getMultiStarts');
        else
            fh = figure(options.fh);
        end
    case 'text'
        fprintf(' \nOptimization:\n=============\n');
    case 'silent' % no output
        % Force fmincon to be silent.
        options.localOptimizerOptions.Display = 'off';
end

%% Initialization of random number generator
if ~isempty(options.rng)
    rng(options.rng);
end

%% Sampling of starting points
switch options.proposal
    case 'latin hypercube'
        % Sampling from latin hypercube
        par0 = [parameters.guess,...
                bsxfun(@plus,parameters.min,bsxfun(@times,parameters.max - parameters.min,...
                             lhsdesign(options.n_starts - size(parameters.guess,2),parameters.number,'smooth','off')'))];
    case 'uniform'
        % Sampling from uniform distribution
        par0 = [parameters.guess,...
                bsxfun(@plus,parameters.min,bsxfun(@times,parameters.max - parameters.min,...
                             rand(parameters.number,options.n_starts - size(parameters.guess,2))))];
    case 'user-supplied'
        % Sampling from user-supplied function
        par0 = [parameters.guess,...
                parameters.init_fun(parameters.guess,parameters.min,parameters.max,options.n_starts - size(parameters.guess,2))];
end
parameters.MS.n_starts = options.n_starts;
parameters.MS.par0 = par0(:,options.start_index);

%% Preparation of folder
if options.save
    if(~exist(options.foldername,'dir'))
        mkdir(options.foldername);
    end
    save([options.foldername '/init'],'parameters','-v7.3');
end

%% Initialization
parameters.MS.par = nan(parameters.number,length(options.start_index));
parameters.MS.logPost0 = nan(length(options.start_index),1);
parameters.MS.logPost = nan(length(options.start_index),1);
parameters.MS.gradient = nan(parameters.number,length(options.start_index));
parameters.MS.hessian  = nan(parameters.number,parameters.number,length(options.start_index));
parameters.MS.n_objfun = nan(length(options.start_index),1);
parameters.MS.n_iter = nan(length(options.start_index),1);
parameters.MS.t_cpu = nan(length(options.start_index),1);
parameters.MS.exitflag = nan(length(options.start_index),1);
if(options.trace)
    parameters.MS.par_trace = nan(parameters.number,options.localOptimizerOptions.MaxIter+1,length(options.start_index));
    parameters.MS.fval_trace = nan(options.localOptimizerOptions.MaxIter+1,length(options.start_index));
    parameters.MS.time_trace = nan(options.localOptimizerOptions.MaxIter+1,length(options.start_index));
end
waitbarFields1 = {'logPost', 'logPost0', 'n_objfun', 'n_iter', 't_cpu', 'exitflag'};
waitbarFields2 = {'par', 'par0', 'gradient', 'fval_trace', 'time_trace'};
waitbarFields3 = {'hessian', 'par_trace'};

%% Multi-start local optimization -- SEQUENTIAL
if strcmp(options.comp_type, 'sequential')
    
    % initialise tracing of parameter and objective function values
    ftrace = options.trace;
    ftempsave  = options.tempsave;
    
    if strcmp(options.localOptimizer, 'fmincon')
        options.localOptimizerOptions.OutputFcn = @outfun_fmincon;
    end
    
    % initialize the waitbar
    waitBar = waitbar(0, '1', 'name', 'Parameter estimation in process, please wait...', 'CreateCancelBtn', 'setappdata(gcbf, ''canceling'', 1)');
    stringTimePrediction = updateWaitBar(0.004 * length(options.start_index) * parameters.number);
    waitbar(0, waitBar, stringTimePrediction);
    C = onCleanup(@() delete(waitBar));
    
    % Loop: Multi-starts
    for i = 1 : length(options.start_index)
        % reset the objective function
        if(options.resetobjective)
            fun = functions(objective_function);
            s_start = strfind(fun.function,')')+1;
            s_end = strfind(fun.function,'(')-1;
            clear(fun.function(s_start(1):s_end(2)));
        end
        
        % Reset error count
        error_count = 0;
        
        % Evaluation of objective function at starting point
        if (~strcmp(options.localOptimizer, 'fmincon') || ~strcmp(options.localOptimizerOptions.GradObj, 'on'))
            J_0 = obj_w_error_count(parameters.MS.par0(:,i),objective_function,options.obj_type);
        elseif (strcmp(options.localOptimizerOptions.GradObj, 'on') && ~strcmp(options.localOptimizerOptions.Hessian,'on'))
            [J_0, grad_J_0] = obj_w_error_count(parameters.MS.par0(:,i),objective_function,options.obj_type);
        else
            [J_0, grad_J_0, H_J_0] = obj_w_error_count(parameters.MS.par0(:,i),objective_function,options.obj_type);
        end
        parameters.MS.logPost0(i) = -J_0;
        
        % Optimization
        startTimeLocalOptimization = cputime;
        if J_0 < -options.init_threshold
            
            if strcmp(options.localOptimizer, 'fmincon')    
                %% fmincon as local optimizer
                % Optimization using fmincon
                [theta,J_opt,parameters.MS.exitflag(i),results_fmincon,~,gradient_opt,hessian_opt] = ...
                    fmincon(@(theta) obj_w_error_count(theta,objective_function,options.obj_type),...  % negative log-likelihood function
                    parameters.MS.par0(:,i),...    % initial parameter
                    parameters.constraints.A  ,parameters.constraints.b  ,... % linear inequality constraints
                    parameters.constraints.Aeq,parameters.constraints.beq,... % linear equality constraints
                    parameters.min,...     % lower bound
                    parameters.max,...     % upper bound
                    [],options.localOptimizerOptions);   % options
                
                % Assignment of reseults
                parameters.MS.J(1, i) = -J_0;
                parameters.MS.logPost(i) = -J_opt;
                parameters.MS.par(:,i) = theta;
                parameters.MS.gradient(:,i) = gradient_opt;
                if isempty(hessian_opt)
                    if strcmp(options.localOptimizerOptions.Hessian,'on')
                        [~,~,hessian_opt] = obj(theta,objective_function,options.obj_type);
                    end
                elseif max(hessian_opt(:)) == 0
                    if strcmp(options.localOptimizerOptions.Hessian,'on')
                        [~,~,hessian_opt] = obj(theta,objective_function,options.obj_type);
                    end
                end
                parameters.MS.n_objfun(i) = results_fmincon.funcCount;
                parameters.MS.n_iter(i) = results_fmincon.iterations;
                parameters.MS.hessian(:,:,i) = full(hessian_opt);
                
            elseif strcmp(options.localOptimizer, 'meigo-ess') || strcmp(options.localOptimizer, 'meigo-vns')
                %% Use MEIGO as local optimizer
                if ~exist('MEIGO', 'file')
                    error('MEIGO not found. This feature requires the "MEIGO" toolbox to be installed. See http://gingproc.iim.csic.es/meigo.html for download and installation instructions.');
                end
                
                problem.f = 'meigoDummy';
                problem.x_L = parameters.min;
                problem.x_U = parameters.max;
                problem.x_0 = parameters.MS.par0(:,i);
                
                meigoAlgo = 'ESS';
                if strcmp(options.localOptimizer, 'meigo-vns')
                    meigoAlgo = 'VNS';
                end
                objFunHandle = @(theta) obj_w_error_count(theta,objective_function,options.obj_type);
                Results = MEIGO(problem, options.localOptimizerOptions, meigoAlgo, objFunHandle);
                
                %TODO
                % parameters.constraints.A  ,parameters.constraints.b  ,... % linear inequality constraints
                % parameters.constraints.Aeq,parameters.constraints.beq,... % linear equality constraints
                
                parameters.MS.J(1, i) = -J_0;
                parameters.MS.logPost(i) = -Results.fbest;
                parameters.MS.par(:,i) = Results.xbest;
                parameters.MS.n_objfun(i) = Results.numeval;
                parameters.MS.n_iter(i) = size(Results.neval, 2);
                
                [~, G_opt, H_opt] = objective_function(parameters.MS.par);
                parameters.MS.hessian(:,:,i) = -H_opt;
                parameters.MS.gradient(:,i) = -G_opt;
                
                %% Output
                switch options.mode
                    case {'visual','text'}, disp(['-> Optimization FINISHED (MEIGO exit code: ' num2str(Results.end_crit) ').']);
                    case 'silent' % no output
                end
                
            elseif strcmp(options.localOptimizer, 'pswarm')
                %% Use PSwarm as local optimizer
                if ~exist('PSwarm', 'file')
                    error('PSwarm not found. This feature requires the "PSwarm" toolbox to be installed. See http://www.norg.uminho.pt/aivaz/pswarm/ for download and installation instructions.');
                end

                problem = struct();
                problem.ObjFunction= 'meigoDummy';
                problem.LB = parameters.min;
                problem.UB = parameters.max;
                problem.A = parameters.constraints.A;
                problem.b = parameters.constraints.b;
                
                objFunHandle = @(theta) obj_w_error_count(theta,objective_function,options.obj_type);
                [theta,J,RunData] = PSwarm(problem, struct('x', parameters.MS.par0(:,i)), options.localOptimizerOptions, objFunHandle);
                
                parameters.MS.logPost(i) = -J;
                parameters.MS.par(:,i) = theta;
                parameters.MS.n_objfun(i) = RunData.ObjFunCounter;
                parameters.MS.n_iter(i) = RunData.IterCounter;
                
                [~, G_opt, H_opt] = objective_function(parameters.MS.par);
                parameters.MS.hessian(:,:,i) = -H_opt;
                parameters.MS.gradient(:,i) = -G_opt;

            end
            
        end
        parameters.MS.t_cpu(i) = cputime - startTimeLocalOptimization;
        
        % Save
        if options.save
            saveResults(parameters,options,i)
        end
        
        % Output
        switch options.mode
            case 'visual', fh = plotMultiStarts(parameters,fh,options.plot_options);
            case 'text', disp(['  ' num2str(i,'%d') '/' num2str(length(options.start_index),'%d')]);
            case 'silent' % no output
        end
        
        % Abort the calculation if the waitbar is cancelled
        if getappdata(waitBar, 'canceling')
            parameters.MS.n_starts = i;
            for iWaitbarField = 1:6
                parameters.MS.(waitbarFields1{iWaitbarField}) = ...
                     parameters.MS.(waitbarFields1{iWaitbarField})(1:i, :);
            end
            for iWaitbarField = 1:5
                if (isfield(parameters.MS, waitbarFields2{iWaitbarField}))
                    parameters.MS.(waitbarFields2{iWaitbarField}) = ...
                        parameters.MS.(waitbarFields2{iWaitbarField})(:, 1:i);
                end
            end
            for iWaitbarField = 1:2
                if (isfield(parameters.MS, waitbarFields3{iWaitbarField}))
                    parameters.MS.(waitbarFields3{iWaitbarField}) = ...
                        parameters.MS.(waitbarFields3{iWaitbarField})(:, :, 1:i);
                end
            end
            
            break;
        end
        
        % update the waitbar
        stringTimePrediction = updateWaitBar((sum(parameters.MS.t_cpu(1:i)) / i) * (length(options.start_index) - i));
        waitbar(i / length(options.start_index), waitBar, stringTimePrediction);
    end
        
    % Assignment
    parameters = sortMultiStarts(parameters);
end

%% Multi-start local optimization -- PARALLEL
if strcmp(options.comp_type,'parallel')
    
    % Initialization
    par = nan(parameters.number,length(options.start_index));
    logPost0 = nan(length(options.start_index),1);
    logPost = nan(length(options.start_index),1);
    gradient = nan(parameters.number,length(options.start_index));
    hessian  = nan(parameters.number,parameters.number,length(options.start_index));
    n_objfun = nan(length(options.start_index),1);
    n_iter = nan(length(options.start_index),1);
    t_cpu = nan(length(options.start_index),1);
    exitflag = nan(length(options.start_index),1);
    
    % reset the objective function
    if(options.resetobjective)
        fun = functions(objective_function);
        s_start = strfind(fun.function,')')+1;
        s_end = strfind(fun.function,'(')-1;
        clear(fun.function(s_start(1):s_end(2)));
    end
    
    % Loop: Mutli-starts
    parfor i = options.start_index
        
        % Evaluation of objective function at starting point
        if (~strcmp(options.localOptimizerOptions.GradObj, 'on'))
            J_0 = obj(parameters.MS.par0(:,i),objective_function,options.obj_type);
        elseif (strcmp(options.localOptimizerOptions.GradObj, 'on') && ~strcmp(options.localOptimizerOptions.Hessian,'on'))
            [J_0,grad_J_0] = obj(parameters.MS.par0(:,i),objective_function,options.obj_type);
        else
            [J_0,grad_J_0,H_J_0] = obj(parameters.MS.par0(:,i),objective_function,options.obj_type);
        end
        logPost0(i) = -J_0;
        
        % Optimization
        t_cpu_fmincon = cputime;
        if J_0 < -options.init_threshold
            % Optimization using fmincon
            [theta,J_opt,exitflag(i),results_fmincon,~,gradient_opt,hessian_opt] = ...
                fmincon(@(theta) obj(theta,objective_function,options.obj_type),...  % negative log-posterior function
                parameters.MS.par0(:,i),...    % initial parameter
                parameters.constraints.A  ,parameters.constraints.b  ,... % linear inequality constraints
                parameters.constraints.Aeq,parameters.constraints.beq,... % linear equality constraints
                parameters.min,...     % lower bound
                parameters.max,...     % upper bound
                [],options.localOptimizerOptions);   % options
            
            % Assignment
            logPost(i) = -J_opt;
            par(:,i) = theta;
            gradient(:,i) = gradient_opt;
            if isempty(hessian_opt)
                if strcmp(options.localOptimizerOptions.Hessian,'on')
                    [~,~,hessian_opt] = obj(theta,objective_function,options.obj_type);
                end
            elseif max(abs(hessian_opt(:))) == 0
                if strcmp(options.localOptimizerOptions.Hessian,'on')
                    [~,~,hessian_opt] = obj(theta,objective_function,options.obj_type);
                end
            end
            hessian(:,:,i) = full(hessian_opt);
            n_objfun(i) = results_fmincon.funcCount;
            n_iter(i) = results_fmincon.iterations;
        end
        t_cpu(i) = cputime - t_cpu_fmincon;
        
        % Save
        if options.save
            saveResults(parameters,options,i)
        end
        
        % Output
        switch options.mode
            case 'text', disp(['  ' num2str(i,'%d') '/' num2str(length(options.start_index),'%d')]);
            case {'silent','visual'} % no output
        end
    end
    
    % Assignment
    parameters.MS.par0 = par0;
    parameters.MS.par = par;
    parameters.MS.logPost0 = logPost0;
    parameters.MS.logPost = logPost;
    parameters.MS.gradient = gradient;
    parameters.MS.hessian  = hessian;
    parameters.MS.n_objfun = n_objfun;
    parameters.MS.n_iter = n_iter;
    parameters.MS.t_cpu = t_cpu;
    parameters.MS.exitflag = exitflag;
    parameters = sortMultiStarts(parameters);
    
    % Output
    switch options.mode
        case 'visual', fh = plotMultiStarts(parameters,fh,options.plot_options);
        case {'text','silent'} % no output
    end
    
end

%% Output
switch options.mode
    case {'visual','text'}, disp('-> Multi-start optimization FINISHED.');
    case 'silent' % no output
end

% Clear Output Function
options.localOptimizerOptions.OutputFcn = [];

%% Nested function for storing of objective function and parameter values
    function stop = outfun_fmincon(x,optimValues,state)
        
        switch state
            case 'init'
                % do nothing
            case 'interrupt'
                % do nothing
            case 'iter'
                if(ftrace)
                    parameters.MS.par_trace(:,optimValues.iteration+1,i) = x;
                    parameters.MS.fval_trace(optimValues.iteration+1,i) = optimValues.fval;
                    parameters.MS.time_trace(optimValues.iteration+1,i) = cputime - t_cpu_fmincon;
                end
                if(ftempsave)
                    if optimValues.iteration>0
                        if(mod(optimValues.iteration,10) == 0)
                            saveResults(parameters,options,i);
                        end
                    end
                end
            case 'done'
                % do nothing
        end
        
        if error_count <= 20
            stop = false;
        else
            warning('Too many failed objective function evaluations.')
            stop = true;
        end
        
    end
end


%% Objective function interface
function varargout = obj(varargin)
% This function is used as interface to the user-provided objective
% function. It adapts the sign and supplies the correct number of outputs.
% Furthermore, it catches errors in the user-supplied objective function.
%   theta ... parameter vector
%   fun ... user-supplied objective function
%   type ... type of user-supplied objective function
%   options (optional) ... additional options, like subset for minibatch

% Catch up possible overload
switch nargin
    case {0, 1, 2}
        error('Call to objective function giving not enough inputs.')
    case 3
        theta   = varargin{1};
        fun     = varargin{2}; %#ok<NASGU>
        type    = varargin{3};
        callFct = 'fun(theta)';
    otherwise
        error('Call to objective function giving too many inputs.')
end

try
    switch nargout
        case {0,1}
            J = eval(callFct);
            switch type
                case 'log-posterior'          , varargout = {-J};
                case 'negative log-posterior' , varargout = { J};
            end
        case 2
            [J,G] = eval(callFct);
            switch type
                case 'log-posterior'          , varargout = {-J,-G};
                case 'negative log-posterior' , varargout = { J, G};
            end
        case 3
            [J,G,H] = eval(callFct);
            switch type
                case 'log-posterior'          , varargout = {-J,-G,-H};
                case 'negative log-posterior' , varargout = { J, G, H};
            end
            if(any(isnan(H)))
                error('Hessian contains NaNs')
            end
    end
    
catch error_msg
    % disp(error_msg.message)
    
    % Derive output
    switch nargout
        case {0,1}
            varargout = {inf};
        case 2
            varargout = {inf,zeros(length(theta),1)};
        case 3
            varargout = {inf,zeros(length(theta),1),zeros(length(theta))};
    end
end

end

%% Objective function interface
function varargout = obj_w_error_count(varargin)
% This function is used as interface to the user-provided objective
% function. It adapts the sign and supplies the correct number of outputs.
% Furthermore, it catches errors in the user-supplied objective function.
%   theta ... parameter vector
%   fun ... user-supplied objective function
%   type ... type of user-supplied objective function
%   options (optional) ... additional options, like subset for minibatch

global error_count

% Catch up possible overload
switch nargin
    case {0, 1, 2}
        error('Call to objective function giving not enough inputs.');
    case 3
        theta   = varargin{1};
        fun     = varargin{2};
        type    = varargin{3};
        callFct = 'fun(theta)';
    case 4
        theta   = varargin{1};
        fun     = varargin{2};
        type    = varargin{3};
        options = varargin{4};
        callFct = 'fun(theta, options)';
    otherwise
        error('Call to objective function giving too many inputs.');
end

try
    switch nargout
        case {0,1}
            J = eval(callFct);
            switch type
                case 'log-posterior'          , varargout = {-J};
                case 'negative log-posterior' , varargout = { J};
            end
        case 2
            [J,G] = eval(callFct);
            switch type
                case 'log-posterior'          , varargout = {-J,-G};
                case 'negative log-posterior' , varargout = { J, G};
            end
        case 3
            [J,G,H] = eval(callFct);
            switch type
                case 'log-posterior'          , varargout = {-J,-G,-H};
                case 'negative log-posterior' , varargout = { J, G, H};
            end
            if(any(isnan(H)))
                error('Hessian contains NaNs')
            end
    end
    % Reset error count
    error_count = 0;
catch error_msg
    % Increase error count
    error_count = error_count + 1;
    
    % Display a warning with error message
    warning(['Evaluation of likelihood failed because: ' error_msg.message]);
    
    % Derive output
    switch nargout
        case {0,1}
            varargout = {inf};
        case 2
            varargout = {inf,zeros(length(theta),1)};
        case 3
            varargout = {inf,zeros(length(theta),1),zeros(length(theta))};
    end
end

end

%% Waitbar Update
function stringTimePrediction = updateWaitBar(timePredicted)
% This function update the waitbar
%
% Parameters:
% * timePredicted: Predicted time in seconds
%   
% Return Values:
% * stringTimePrediction: String, Updating Message

    if (timePredicted < 60)
        stringTimePrediction = 'One minute or less...';
    elseif (timePredicted >= 60 && timePredicted < 3600)
        stringTimePrediction = ['About ' num2str(round(timePredicted/60)) + 1 ' minutes'];
    elseif (timePredicted >= 3600 && timePredicted < 72000)
        hours = floor(timePredicted/3600);
        minutes = round((timePredicted - 3600*hours) / 600) * 10;
        if (hours == 1)
            stringTimePrediction = ['About 1 hour'];
        else
            stringTimePrediction = ['About ' num2str(hours) ' hours'];
        end
        if (minutes == 0)
            stringTimePrediction = strcat(stringTimePrediction, '...');
        else
            stringTimePrediction = strcat(stringTimePrediction, [' and ' num2str(minutes) ' minutes...']);
        end
    elseif (timePredicted >= 72000 && timePredicted < 36 * 3600)
        stringTimePrediction = 'Roughly 1 day...';
    elseif (timePredicted >= 36 * 3600 && timePredicted < 2 * 365 * 24 * 3600)
        stringTimePrediction = ['About ' num2str(round(timePredicted / 24 * 3600)) ' days...'];
    elseif (timePredicted >= 2 * 365 * 24 * 3600 && timePredicted < 100 * 365 * 24 * 3600)
        stringTimePrediction = ['Oh boy! Quite some years... Maybe about ' num2str(round(timePredicted / 365 * 24 * 3600)) ' of them...'];
    elseif (timePredicted >= 100 * 365 * 24 * 3600 && timePredicted < 1e7 * 365 * 24 * 3600)
        stringTimePrediction = 'Well... Maybe your children, or grand-children... No, not evem them...'; 
    else
        stringTimePrediction = 'Kingdoms will rise, civilization will decline, stars will fade - but your calculation...(!) ;)';
    end
    stringTimePrediction = ['Predicted waiting time: ', stringTimePrediction];
    
end

function saveResults(parameters,options,i)
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__logPost.csv']),parameters.MS.logPost(i),'delimiter',',','precision',12);
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__logPost0.csv']),parameters.MS.logPost0(i),'delimiter',',','precision',12);
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__par.csv']),parameters.MS.par(:,i),'delimiter',',','precision',12);
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__par0.csv']),parameters.MS.par0(:,i),'delimiter',',','precision',12);
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__gradient.csv']),parameters.MS.gradient(:,i),'delimiter',',','precision',12);
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__hessian.csv']),parameters.MS.hessian(:,:,i),'delimiter',',','precision',12);
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__t_cpu.csv']),parameters.MS.t_cpu(i),'delimiter',',','precision',12);
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__n_objfun.csv']),parameters.MS.n_objfun(i),'delimiter',',','precision',12);
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__n_iter.csv']),parameters.MS.n_iter(i),'delimiter',',','precision',12);
    dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__exitflag.csv']),parameters.MS.exitflag(i),'delimiter',',','precision',12);
    if(options.trace)
        dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__par_trace.csv']),parameters.MS.par_trace(:,:,i),'delimiter',',','precision',12);
        dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__fval_trace.csv']),parameters.MS.fval_trace(:,i),'delimiter',',','precision',12);
        dlmwrite(fullfile(pwd,options.foldername ,['MS' num2str(options.start_index(i),'%d') '__time_trace.csv']),parameters.MS.time_trace(:,i),'delimiter',',','precision',12);
    end

end
