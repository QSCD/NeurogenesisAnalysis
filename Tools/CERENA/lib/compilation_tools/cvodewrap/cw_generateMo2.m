% generateM generates the matlab wrapper for the mex files which simplifies the calling of the mex simulation file
%
% USAGE:
% ======
% generateC( modelname, modelstruct)
% 
% INPUTS:
% =======
% modelname ... specifies the name of the model which will be later used for the naming of the simualation file
% modelstruct ... is the struct generated by parseModel
function cw_generateMo2( filename, struct, structo2 )
    %GENERATEM Summary of this function goes here
    %   Detailed explanation goes here
    
    [odewrap_path,~,~]=fileparts(which('cw_compileC.m'));
    
    nx = length(structo2.sym.x);
    ny = length(structo2.sym.y);
    np = length(structo2.sym.p);
    nk = length(structo2.sym.k);
    nu = length(structo2.sym.u);
    ndisc = struct.ndisc;
    nr = length(struct.sym.root)-ndisc;
    nxtrue = nx/(np+1);
    nytrue = ny/(np+1);
    
    fid = fopen(fullfile(odewrap_path,'models',filename,['simulate_',filename,'.m']),'w');
    fprintf(fid,['%% simulate_' filename '.m is the matlab interface to the cvodes mex\n'...
    '%%   which simulates the ordinary differential equation and respective\n'...
    '%%   sensitivities according to user specifications.\n'...
    '%%\n'...
    '%% USAGE:\n'...
    '%% ======\n'...
    '%% [sol] = simulate_' filename '_o2(tout,theta)\n'...
    '%% [sol] = simulate_' filename '_o2(tout,theta,kappa,options)\n'...
    '%%\n'...
    '%% INPUTS:\n'...
    '%% =======\n'...
    '%% tout ... 1 dimensional vector of timepoints at which a solution to the ODE is desired\n'...
    '%% theta ... 1 dimensional parameter vector of parameters for which sensitivities are desired.\n'...
    '%%           this corresponds to the specification in model.sym.p\n'...
    '%% kappa ... 1 dimensional parameter vector of parameters for which sensitivities are not desired.\n'...
    '%%           this corresponds to the specification in model.sym.k\n'...
    '%% options_cvode.sens_ind ... 1 dimensional vector of indexes for which sensitivities must be computed.\n'...
    '%%           default value is 1:length(theta).\n'...
    '%% options ... additional options to pass to the cvodes solver. Refer to the cvodes guide for more documentation.\n'...
    '%%    .sensi ... number of derivatives to compute.\n'...
    '%%    .cvodes_atol ... absolute tolerance for the solver. default is specified in the user-provided syms function.\n'...
    '%%    .cvodes_rtol ... relative tolerance for the solver. default is specified in the user-provided syms function.\n'...
    '%%    .cvodes_maxsteps    ... maximal number of integration steps. default is specified in the user-provided syms function.\n'...
    '%%    .tstart    ... start of integration. for all timepoints before this, values will be set to initial value.\n'...
    '%%    .sens_ind ... 1 dimensional vector of indexes for which sensitivities must be computed.\n'...
    '%%    .lmm    ... linear multistep method for forward problem.\n'...
    '%%        1: Adams-Bashford\n'...
    '%%        2: BDF (DEFAULT)\n'...
    '%%    .iter    ... iteration method for linear multistep.\n'...
    '%%        1: Functional\n'...
    '%%        2: Newton (DEFAULT)\n'...
    '%%    .linsol   ... linear solver module.\n'...
    '%%        direct solvers:\n'...
    '%%        1: Dense (DEFAULT)\n'...
    '%%        2: Band (not implented)\n'...
    '%%        3: LAPACK Dense (not implented)\n'...
    '%%        4: LAPACK Band  (not implented)\n'...
    '%%        5: Diag (not implented)\n'...
    '%%        implicit krylov solvers:\n'...
    '%%        6: SPGMR\n'...
    '%%        7: SPBCG\n'...
    '%%        8: SPTFQMR\n'...
    '%%        sparse solvers:\n'...
    '%%        9: KLU\n'...
    '%%    .stldet   ... flag for stability limit detection. this should be turned on for stiff problems.\n'...
    '%%        0: OFF\n'...
    '%%        1: ON (DEFAULT)\n'...
    '%%    .qPositiveX   ... vector of 0 or 1 of same dimension as state vector. 1 enforces positivity of states.\n'...
    '%%    .sensi_meth   ... method for sensitivity computation.\n'...
    '%%        1: Forward Sensitivity Analysis (DEFAULT)\n'...
    '%%        2: Adjoint Sensitivity Analysis\n'...
    '%%    .ism   ... only available for sensi_meth == 1. Method for computation of forward sensitivities.\n'...
    '%%        1: Simultaneous (DEFAULT)\n'...
    '%%        2: Staggered\n'...
    '%%        3: Staggered1\n'...
    '%%    .Nd   ... only available for sensi_meth == 2. Number of Interpolation nodes for forward solution. \n'...
    '%%              Default is 1000. \n'...
    '%%    .interpType   ... only available for sensi_meth == 2. Interpolation method for forward solution.\n'...
    '%%        1: Hermite (DEFAULT)\n'...
    '%%        2: Polynomial\n'...
    '%%    .lmmB   ... only available for sensi_meth == 2. linear multistep method for backward problem.\n'...
    '%%        1: Adams-Bashford\n'...
    '%%        2: BDF (DEFAULT)\n'...
    '%%    .iterB   ... only available for sensi_meth == 2. iteration method for linear multistep.\n'...
    '%%        1: Functional\n'...
    '%%        2: Newton (DEFAULT)\n'...
    '%%\n'...
    '%% Outputs:\n'...
    '%% ========\n'...
    '%% sol.status ... flag for status of integration. generally status<0 for failed integration\n'...
    '%% sol.tout ... vector at which the solution was computed\n'...
    '%% sol.x ... time-resolved state vector\n'...
    '%% sol.y ... time-resolved output vector\n'...
    '%% sol.sx ... time-resolved state sensitivity vector\n'...
    '%% sol.sy ... time-resolved output sensitivity vector\n'...
    '%% sol.s2x ... time-resolved state sensitivity vector\n'...
    '%% sol.s2y ... time-resolved output sensitivity vector\n'...
    '%% sol.xdot time-resolved right-hand side of differential equation\n'...
    '%% sol.rootval value of root at end of simulation time\n'...
    '%% sol.srootval value of root at end of simulation time\n'...
    '%% sol.s2rootval value of root at end of simulation time\n'...
    '%% sol.root time of events\n'...
    '%% sol.sroot value of root at end of simulation time\n'...
    '%% sol.s2root value of root at end of simulation time\n'...
    ]);
    fprintf(fid,['function sol = simulate_' filename '(varargin)\n\n']);
    fprintf(fid,['%% DO NOT CHANGE ANYTHING IN THIS FILE UNLESS YOU ARE VERY SURE ABOUT WHAT YOU ARE DOING\n']);
    fprintf(fid,['%% MANUAL CHANGES TO THIS FILE CAN RESULT IN WRONG SOLUTIONS AND CRASHING OF MATLAB\n']);
    fprintf(fid,['if(nargin<2)\n']);
    fprintf(fid,['    error(''Not enough input arguments.'');\n']);
    fprintf(fid,['else\n']);
    fprintf(fid,['    tout=varargin{1};\n']);
    fprintf(fid,['    phi=varargin{2};\n']);
    fprintf(fid,['end\n']);
    
    fprintf(fid,['if(nargin>=3)\n']);
    fprintf(fid,['    kappa=varargin{3};\n']);
    fprintf(fid,['else\n']);
    fprintf(fid,['    kappa=[];\n']);
    fprintf(fid,['end\n']);
    
    fprintf(fid,['if(nargout>1)\n']);
    fprintf(fid,['    if(nargout>6)\n']);
    fprintf(fid,['        options_cvode.sensi = 2;\n']);
    fprintf(fid,['    elseif(nargout>4)\n']);
    fprintf(fid,['        options_cvode.sensi = 1;\n']);
    fprintf(fid,['    else\n']);
    fprintf(fid,['        options_cvode.sensi = 0;\n']);
    fprintf(fid,['    end\n']);
    fprintf(fid,['end\n']);
    
    if(isfield(structo2,'param'))
        switch(structo2.param)
            case 'log'
                fprintf(fid,'theta = exp(phi);\n\n');
            case 'log10'
                fprintf(fid,'theta = 10.^(phi);\n\n');
            case 'lin'
                fprintf(fid,'theta = phi;\n\n');
            otherwise
                disp('No valid parametrisation chosen! Valid options are "log","log10" and "lin". Using linear parametrisation (default)!')
                fprintf(fid,'theta = phi;\n\n');
        end
    else
        disp('No parametrisation chosen! Using linear parametrisation (default)!')
        fprintf(fid,'theta = phi;\n\n');
    end
    if(nk==0)
        fprintf(fid,'if(nargin==2)\n');
        fprintf(fid,'    kappa = [];\n');
        fprintf(fid,'end\n');
    end
    
    fprintf(fid,['options_cvode.cvodes_atol = ' num2str(structo2.atol) ';\n']);
    fprintf(fid,['options_cvode.cvodes_rtol = ' num2str(structo2.atol) ';\n']);
    fprintf(fid,['options_cvode.cvodes_maxsteps = ' num2str(structo2.maxsteps) ';\n']);
    fprintf(fid,['options_cvode.sens_ind = 1:' num2str(np) ';\n']);
    fprintf(fid,['options_cvode.nr = ' num2str(nr) '; %% MUST NOT CHANGE THIS VALUE\n']);
    fprintf(fid,['options_cvode.ndisc = ' num2str(ndisc) '; %% MUST NOT CHANGE THIS VALUE\n']);
    fprintf(fid,['options_cvode.np = length(options_cvode.sens_ind); %% MUST NOT CHANGE THIS VALUE\n']);
    fprintf(fid,['options_cvode.tstart = ' num2str(structo2.t0) ';\n']);
    fprintf(fid,['options_cvode.lmm = 2;\n']);
    fprintf(fid,['options_cvode.iter = 2;\n']);
    fprintf(fid,['options_cvode.linsol = 9;\n']);
    fprintf(fid,['options_cvode.stldet = 1;\n']);
    fprintf(fid,['options_cvode.Nd = 1000;\n']);
    fprintf(fid,['options_cvode.interpType = 1;\n']);
    fprintf(fid,['options_cvode.lmmB = 2;\n']);
    fprintf(fid,['options_cvode.iterB = 2;\n']);
    fprintf(fid,['options_cvode.ism = 1;\n']);
    fprintf(fid,['options_cvode.sensi_meth = 1;\n\n']);
    fprintf(fid,['options_cvode.nmaxroot = 100;\n\n']);
    fprintf(fid,['options_cvode.ubw = ' num2str(structo2.ubw) ';\n\n']);
    fprintf(fid,['options_cvode.lbw = ' num2str(structo2.lbw)  ';\n\n']);
    
    
    fprintf(fid,['options_cvode.qPositiveX = zeros(length(tout),' num2str(nx) ');\n']);

    fprintf(fid,['\n']);

    fprintf(fid,['sol.status = 0;\n']);
    fprintf(fid,['sol.t = tout;\n']);
    fprintf(fid,['sol.root = NaN(options_cvode.nmaxroot,' num2str(nr) ');\n']);
    fprintf(fid,['sol.rootval = NaN(options_cvode.nmaxroot,' num2str(nr) ');\n']);
    fprintf(fid,['sol.numsteps = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numrhsevals = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numlinsolvsetups = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numerrtestfails = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.order = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numnonlinsolviters = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numjacevals = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numliniters = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numconvfails = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numprecevals = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numprecsolves = zeros(length(tout),1);\n\n']);
    fprintf(fid,['sol.numjtimesevals = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numstepsS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numrhsevalsS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numlinsolvsetupsS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numerrtestfailsS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.orderS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numnonlinsolvitersS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numjacevalsS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numlinitersS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numconvfailsS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numprecevalsS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numprecsolvesS = zeros(length(tout),1);\n']);
    fprintf(fid,['sol.numjtimesevalsS = zeros(length(tout),1);\n']);
    fprintf(fid,'\n');
    fprintf(fid,'plist = options_cvode.sens_ind-1;\n');
    fprintf(fid,'pbar = ones(size(theta));\n');
    fprintf(fid,'pbar(pbar==0) = 1;\n');
    fprintf(fid,'xscale = [];\n');
    
    fprintf(fid,['if(nargin>=4)\n']);
    fprintf(fid,['    options_cvode = cw_setdefault(varargin{4},options_cvode);\n']);
    fprintf(fid,['end\n']);
    fprintf(fid,'if(options_cvode.sensi<2)\n');
    fprintf(fid,['    options_cvode.nx = ' num2str(nxtrue) '; %% MUST NOT CHANGE THIS VALUE\n']);
    fprintf(fid,['    options_cvode.ny = ' num2str(nytrue) '; %% MUST NOT CHANGE THIS VALUE\n']);
    fprintf(fid,['    options_cvode.nnz = ' num2str(struct.nnz) '; %% MUST NOT CHANGE THIS VALUE\n']);
    fprintf(fid,['    sol.x = zeros(length(tout),' num2str(nxtrue) ');\n']);
    fprintf(fid,['    sol.y = zeros(length(tout),' num2str(nytrue) ');\n']);
    fprintf(fid,['    sol.xdot = zeros(length(tout),' num2str(nxtrue) ');\n']);
    fprintf(fid,['    sol.J = zeros(length(tout),' num2str(nxtrue) ',' num2str(nxtrue) ');\n']);
    fprintf(fid,['    sol.dxdotdp = zeros(length(tout),' num2str(nxtrue) ',options_cvode.np);\n']);
    fprintf(fid,'else\n');
    fprintf(fid,['    options_cvode.nx = ' num2str(nx) '; %% MUST NOT CHANGE THIS VALUE\n']);
    fprintf(fid,['    options_cvode.ny = ' num2str(ny) '; %% MUST NOT CHANGE THIS VALUE\n']);
    fprintf(fid,['    options_cvode.nnz = ' num2str(structo2.nnz) '; %% MUST NOT CHANGE THIS VALUE\n']);
    fprintf(fid,['    sol.x = zeros(length(tout),' num2str(nx) ');\n']);
    fprintf(fid,['    sol.y = zeros(length(tout),' num2str(ny) ');\n']);
    fprintf(fid,['    sol.xdot = zeros(length(tout),' num2str(nx) ');\n']);
    fprintf(fid,['    sol.J = zeros(length(tout),' num2str(nx) ',' num2str(nx) ');\n']);
    fprintf(fid,['    sol.dxdotdp = zeros(length(tout),' num2str(nx) ',options_cvode.np);\n']);
    fprintf(fid,'end\n');
    fprintf(fid,'if(options_cvode.sensi>0)\n');
    fprintf(fid,['    sol.xS = zeros(length(tout),' num2str(nxtrue) ',length(options_cvode.sens_ind));\n']);
    fprintf(fid,['    sol.yS = zeros(length(tout),' num2str(nytrue) ',length(options_cvode.sens_ind));\n']);
    fprintf(fid,['    sol.rootS =  NaN(options_cvode.nmaxroot,' num2str(nr) ',length(options_cvode.sens_ind));\n']);
    fprintf(fid,['    sol.rootvalS =  NaN(options_cvode.nmaxroot,' num2str(nr) ',length(options_cvode.sens_ind));\n']);
    fprintf(fid,'end\n');
    fprintf(fid,'if(options_cvode.sensi>1)\n');
    fprintf(fid,['    sol.xS = zeros(length(tout),' num2str(nx) ',length(options_cvode.sens_ind));\n']);
    fprintf(fid,['    sol.yS = zeros(length(tout),' num2str(ny) ',length(options_cvode.sens_ind));\n']);
    fprintf(fid,['    sol.rootS2 =  NaN(options_cvode.nmaxroot,' num2str(nr) ',length(options_cvode.sens_ind),length(options_cvode.sens_ind));\n']);
    fprintf(fid,['    sol.rootvalS2 =  NaN(options_cvode.nmaxroot,' num2str(nr) ',length(options_cvode.sens_ind),length(options_cvode.sens_ind));\n']);
    fprintf(fid,'end\n');
    fprintf(fid,['if(max(options_cvode.sens_ind)>' num2str(np) ')\n']);
    fprintf(fid,['    error(''Sensitivity index exceeds parameter dimension!'')\n']);
    fprintf(fid,['end\n']);
    fprintf(fid,'if(options_cvode.sensi<2)\n');
    fprintf(fid,['   cw_' filename '(sol,tout,theta(options_cvode.sens_ind),kappa(1:' num2str(nk) '),options_cvode,plist,pbar,xscale);\n']);
    fprintf(fid,'else\n');
    fprintf(fid,['   cw_' filename '_o2(sol,tout,theta(options_cvode.sens_ind),kappa(1:' num2str(nk) '),options_cvode,plist,pbar,xscale);\n']);
    fprintf(fid,'end\n');
    fprintf(fid,'if(options_cvode.sensi<2)\n');
    fprintf(fid,['    rt = [' num2str(struct.rt) '];\n']);
    fprintf(fid,'else\n');
    fprintf(fid,['    rt = [' num2str(structo2.rt) '];\n']);
    fprintf(fid,'end\n');
    fprintf(fid,['sol.x = sol.x(:,rt);\n']);
    fprintf(fid,['sol.xdot = sol.xdot(:,rt);\n']);
    fprintf(fid,'if(options_cvode.sensi>0)\n');
    fprintf(fid,['    sol.xS = sol.xS(:,rt,:);\n']);
    fprintf(fid,'end\n');
    fprintf(fid,'if(options_cvode.sensi == 1)\n');
    if(isfield(structo2,'param'))
        switch(structo2.param)
            case 'log'
                fprintf(fid,['    sol.sx = bsxfun(@times,sol.xS,permute(theta(options_cvode.sens_ind),[3,2,1]));\n']);
                fprintf(fid,['    sol.sy = bsxfun(@times,sol.yS,permute(theta(options_cvode.sens_ind),[3,2,1]));\n']);
                fprintf(fid,['    sol.sroot = bsxfun(@times,sol.rootS,permute(theta(options_cvode.sens_ind),[3,2,1]));\n']);
                fprintf(fid,['    sol.srootval = bsxfun(@times,sol.rootvalS,permute(theta(options_cvode.sens_ind),[3,2,1]));\n']);
            case 'log10'
                fprintf(fid,['    sol.sx = bsxfun(@times,sol.xS,permute(theta(options_cvode.sens_ind),[3,2,1])*log(10));\n']);
                fprintf(fid,['    sol.sy = bsxfun(@times,sol.yS,permute(theta(options_cvode.sens_ind),[3,2,1])*log(10));\n']);
                fprintf(fid,['    sol.sroot = bsxfun(@times,sol.rootS,permute(theta(options_cvode.sens_ind),[3,2,1])*log(10));\n']);
                fprintf(fid,['    sol.srootval = bsxfun(@times,sol.rootvalS,permute(theta(options_cvode.sens_ind),[3,2,1])*log(10));\n']);
            case 'lin'
                fprintf(fid,'    sol.sx = sol.xS;\n');
                fprintf(fid,'    sol.sy = sol.yS;\n');
                fprintf(fid,'    sol.sroot = sol.rootS;\n');
                fprintf(fid,'    sol.srootval = sol.rootvalS;\n');
            otherwise
                fprintf(fid,'    sol.sx = sol.xS;\n');
                fprintf(fid,'    sol.sy = sol.yS;\n');
                fprintf(fid,'    sol.sroot = sol.rootS;\n');
                fprintf(fid,'    sol.srootval = sol.rootvalS;\n');
        end
    else
        fprintf(fid,'    sol.sx = sol.xS;\n');
        fprintf(fid,'    sol.sy = sol.yS;\n');
        fprintf(fid,'    sol.sroot = sol.rootS;\n');
        fprintf(fid,'    sol.srootval = sol.rootvalS;\n');
    end
    fprintf(fid,'end\n');
    fprintf(fid,'if(options_cvode.sensi == 2)\n');
    fprintf(fid,['    sx = reshape(sol.x(:,' num2str(nxtrue+1) ':end),length(tout),' num2str(nxtrue) ',length(theta(options_cvode.sens_ind)));\n']);
    fprintf(fid,['    sy = sol.yS(:,1:' num2str(nytrue) ',:);\n']);
    fprintf(fid,['    s2x = reshape(sol.xS(:,' num2str(nxtrue+1) ':end,:),length(tout),' num2str(nxtrue) ',length(theta(options_cvode.sens_ind)),length(theta(options_cvode.sens_ind)));\n']);
    fprintf(fid,['    s2y = reshape(sol.yS(:,' num2str(nytrue+1) ':end,:),length(tout),' num2str(nytrue) ',length(theta(options_cvode.sens_ind)),length(theta(options_cvode.sens_ind)));\n']);
    fprintf(fid,['    sol.x = sol.x(:,1:' num2str(nxtrue) ');\n']);
    fprintf(fid,['    sol.y = sol.y(:,1:' num2str(nytrue) ');\n']);
    if(isfield(structo2,'param'))
        switch(structo2.param)
            case 'log'
                fprintf(fid,['    sol.sx = bsxfun(@times,sx,permute(theta(options_cvode.sens_ind),[3,2,1]));\n']);
                fprintf(fid,['    sol.s2x = bsxfun(@times,s2x,permute(theta(options_cvode.sens_ind)*transpose(theta(options_cvode.sens_ind)),[4,3,2,1])) + bsxfun(@times,sx,permute(diag(theta(options_cvode.sens_ind).*ones(length(theta(options_cvode.sens_ind)),1)),[4,3,2,1]));\n']);
                fprintf(fid,['    sol.sy = bsxfun(@times,sy,permute(theta(options_cvode.sens_ind),[3,2,1]));\n']);
                fprintf(fid,['    sol.s2y = bsxfun(@times,s2y,permute(theta(options_cvode.sens_ind)*transpose(theta(options_cvode.sens_ind)),[4,3,2,1])) + bsxfun(@times,sy,permute(diag(theta(options_cvode.sens_ind).*ones(length(theta(options_cvode.sens_ind)),1)),[4,3,2,1]));\n']);
                fprintf(fid,['    sol.sroot = bsxfun(@times,sol.rootS,permute(theta(options_cvode.sens_ind),[3,2,1]));\n']);
                fprintf(fid,['    sol.s2root = bsxfun(@times,sol.rootS2,permute(theta(options_cvode.sens_ind)*transpose(theta(options_cvode.sens_ind)),[4,3,2,1])) + bsxfun(@times,sol.rootS,permute(diag(theta(options_cvode.sens_ind).*ones(length(theta(options_cvode.sens_ind)),1)),[4,3,2,1]));\n']);
                fprintf(fid,['    sol.srootval = bsxfun(@times,sol.rootvalS,permute(theta(options_cvode.sens_ind),[3,2,1]));\n']);
                fprintf(fid,['    sol.s2rootval = bsxfun(@times,sol.rootvalS2,permute(theta(options_cvode.sens_ind)*transpose(theta(options_cvode.sens_ind)),[4,3,2,1])) + bsxfun(@times,sol.rootvalS,permute(diag(theta(options_cvode.sens_ind).*ones(length(theta(options_cvode.sens_ind)),1)),[4,3,2,1]));\n']);
            case 'log10'
                fprintf(fid,['    sol.sx = bsxfun(@times,sx,permute(theta(options_cvode.sens_ind),[3,2,1])*log(10));\n']);
                fprintf(fid,['    sol.s2x = bsxfun(@times,s2x,permute(theta(options_cvode.sens_ind)*transpose(theta(options_cvode.sens_ind))*(log(10)^2),[4,3,2,1])) + bsxfun(@times,sx,permute(diag(log(10)^2*theta(options_cvode.sens_ind).*ones(length(theta(options_cvode.sens_ind)),1)),[4,3,2,1]));\n']);
                fprintf(fid,['    sol.sy = bsxfun(@times,sy,permute(theta(options_cvode.sens_ind),[3,2,1])*log(10));\n']);
                fprintf(fid,['    sol.s2y = bsxfun(@times,s2y,permute(theta(options_cvode.sens_ind)*transpose(theta(options_cvode.sens_ind))*(log(10)^2),[4,3,2,1])) + bsxfun(@times,sy,permute(diag(log(10)^2*theta(options_cvode.sens_ind).*ones(length(theta(options_cvode.sens_ind)),1)),[4,3,2,1]));\n']);
                fprintf(fid,['    sol.sroot = bsxfun(@times,sol.rootS,permute(theta(options_cvode.sens_ind),[3,2,1])*log(10));\n']);
                fprintf(fid,['    sol.s2root = bsxfun(@times,sol.rootS2,permute(theta(options_cvode.sens_ind)*transpose(theta(options_cvode.sens_ind))*(log(10)^2),[4,3,2,1])) + bsxfun(@times,sol.rootS,permute(diag(log(10)^2*theta(options_cvode.sens_ind).*ones(length(theta(options_cvode.sens_ind)),1)),[4,3,2,1]));\n']);
                fprintf(fid,['    sol.srootval = bsxfun(@times,sol.rootvalS,permute(theta(options_cvode.sens_ind),[3,2,1])*log(10));\n']);
                fprintf(fid,['    sol.s2root = bsxfun(@times,sol.rootS2,permute(theta(options_cvode.sens_ind)*transpose(theta(options_cvode.sens_ind))*(log(10)^2),[4,3,2,1])) + bsxfun(@times,sol.rootS,permute(diag(log(10)^2*theta(options_cvode.sens_ind).*ones(length(theta(options_cvode.sens_ind)),1)),[4,3,2,1]));\n']);
                fprintf(fid,['    sol.s2rootval = bsxfun(@times,sol.rootvalS2,permute(theta(options_cvode.sens_ind)*transpose(theta(options_cvode.sens_ind))*(log(10)^2),[4,3,2,1])) + bsxfun(@times,sol.rootvalS,permute(diag(log(10)^2*theta(options_cvode.sens_ind).*ones(length(theta(options_cvode.sens_ind)),1)),[4,3,2,1]));\n']);
            case 'lin'
                fprintf(fid,'    sol.sx = sx;\n');
                fprintf(fid,'    sol.s2x = s2x;\n');
                fprintf(fid,'    sol.sy = sx;\n');
                fprintf(fid,'    sol.s2y = s2y;\n');
                fprintf(fid,'    sol.sroot = sol.rootS;\n');
                fprintf(fid,'    sol.s2root = sol.rootS2;\n');
                fprintf(fid,'    sol.srootval = sol.rootvalS;\n');
                fprintf(fid,'    sol.s2rootval = sol.rootvalS2;\n');
            otherwise
                fprintf(fid,'    sol.sx = sx;\n');
                fprintf(fid,'    sol.s2x = s2x;\n');
                fprintf(fid,'    sol.sy = sx;\n');
                fprintf(fid,'    sol.s2y = s2y;\n');
                fprintf(fid,'    sol.sroot = sol.rootS;\n');
                fprintf(fid,'    sol.s2root = sol.rootS2;\n');
                fprintf(fid,'    sol.srootval = sol.rootvalS;\n');
                fprintf(fid,'    sol.s2rootval = sol.rootvalS2;\n');
        end
    else
        fprintf(fid,'    sol.sx = sx;\n');
        fprintf(fid,'    sol.s2x = s2x;\n');
        fprintf(fid,'    sol.sy = sx;\n');
        fprintf(fid,'    sol.s2y = s2y;\n');
        fprintf(fid,'    sol.sroot = sol.rootS;\n');
        fprintf(fid,'    sol.s2root = sol.rootS2;\n');
        fprintf(fid,'    sol.srootval = sol.rootvalS;\n');
        fprintf(fid,'    sol.s2rootval = sol.rootvalS2;\n');
    end
    fprintf(fid,'end\n');

    fprintf(fid,['if(nargout>1)\n']);
    fprintf(fid,['    varargout{1} = sol.status;\n']);
    fprintf(fid,['    varargout{2} = sol.t;\n']);
    fprintf(fid,['    varargout{3} = sol.x;\n']);
    fprintf(fid,['    varargout{4} = sol.y;\n']);
    fprintf(fid,['    if(nargout>4)\n']);
    fprintf(fid,['        varargout{5} = sol.sx;\n']);
    fprintf(fid,['        varargout{6} = sol.sy;\n']);
    fprintf(fid,['    end\n']);
    fprintf(fid,['    if(nargout>6)\n']);
    fprintf(fid,['        varargout{7} = sol.s2x;\n']);
    fprintf(fid,['        varargout{8} = sol.s2y;\n']);
    fprintf(fid,['    end\n']);
    fprintf(fid,['else\n']);
    fprintf(fid,['    varargout{1} = sol;\n']);
    fprintf(fid,['end\n']);
    fprintf(fid,'end\n');
    fclose(fid);
end

    
