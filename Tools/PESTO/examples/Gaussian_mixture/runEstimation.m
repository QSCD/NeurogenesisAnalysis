% Main file for the Gaussian mixture example.
%
% Model of ... 
%
% This example demonstrates the use of:
% * getParameterSamples()
% * plotParameterSamples()

clear all;
close all;
clc;

%% DEFINITION OF PARAMETER ESTIMATION PROBLEM
% Parameters
parameters.name = {'x_1','x_2'};
parameters.min = [-2,-2];
parameters.max = [ 12, 12];
parameters.number = length(parameters.name);

% Likelihood, prior and objective
rng(5);
mu = rand(2,20)*10;
sig = 0.05;
logP = @(theta) simulate_Gauss_LLH(theta,mu,sig);

% options = PestoOptions();
% options.fmincon   = optimoptions('fmincon',...
%     'SpecifyObjectiveGradient', false,...
%     'Display', 'iter-detailed', ...
%     'MaxIterations', 500);
% options.obj_type = 'negative log-posterior';
% options.n_starts = 20;
% options.comp_type = 'sequential';
% options.mode = 'visual';
% 
% parameters = getMultiStarts(parameters, logP, options);

%% MARKOV CHAIN MONTE-CARLO SAMPLING
% Sample size
options = PestoOptions();
options.MCMC.nsimu_warmup = 1e4;
options.MCMC.nsimu_run    = 1e4;

% Transition kernels
options.SC.proposal_scheme = 'AM';% 'MH';
options.MCMC.sampling_scheme = 'single-chain'; 
options.MCMC.swapStrategy  = 'PTEE';
% options.MC.swapStrategy  = 'all_adjacents';

% Adaptation of temperature
% options.AM.adapt_temperatures = false;
% options.AM.start_iter_temp_adaption = 1e4;

% Adaptation ot the number of temperatures
% options.MCMC.n_temps = 5;
% options.AM.adapt_temperature_value = true;
% options.AM.start_iter_temp_adaption = 5e3;

% Adaptation of the number of temperatures
% options.AM.adapt_temperature_number = true;
% options.AM.adapt_temperature_number_inter_update_time = 1e3;

% In-chain adaptation
options.SC.AM.proposal_scaling_scheme = 'Lacki';
% options.AM.proposal_scaling_scheme = 'Haario';
options.SC.AM.adaption_interval = 1;

% Reporting
options.mode = 'visual';  
options.MCMC.report_interval = 100;

% Initialization
options.MCMC.initialization = 'user-provided';
options.plot_options.MCMC = 'user-provided';
parameters.user.theta_0 = [0;0];
parameters.user.Sigma_0 = 1e-4 * diag([1,1]);

% Output options

% MCMC sampling
tic
parameters = getParameterSamples(parameters,logP,options);
toc

%% Visualiztaion
% Histograms
options.plot_options.S.bins = 50;
options.plot_options.add_points.par = mu;

% Scatter plots
plotParameterSamples(parameters,'1D',[],[],options.plot_options);
plotParameterSamples(parameters,'2D',[],[],options.plot_options);

%% Chain statistics
chainstats(parameters.S.par');
