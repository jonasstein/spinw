function spectra = sw_egrid(spectra, varargin)
% creates energy for spectrum color plot
%
% spectra = SW_EGRID(spectra, 'Option1', Value1, ...) 
%
% It creates a grid along energy and stores the requested correlation
% function component(s) binned in energy using the grid.
%
% Input:
%
% spectra   Input structure, contains calculated correlation functions.
%
% Options:
%
% component Selects which correlation function component to be binned in
%           energy. The possible options are:
%               'Sperp' bins the magnetic neutron scattering intensity
%                       (<Sperp * Sperp> expectation value).
%                       Default.
%               'Sab'   bins the selected components of the spin-spin
%                       correlation function. Letter a and b can be 'x',
%                       'y' or 'z'. For example: 'Sxx' will convolute the
%                       xx component of the correlation function with the
%                       dispersion. xyz is the standard coordinate system,
%                       see online documentation of sw.
%               'Mab'   bins the selected components of the spin-spin
%                       correlation function. Letter a and b can be 'x',
%                       'y' or 'z'. For example: 'Mxx' will convolute the
%                       xx component of the correlation function with the
%                       dispersion. The coordinates here are in the
%                       Blume-Maleev coordinate system, see below.
%               'Pab'   bins the selected element of the polarisation
%                       matrix. Letter a and b can be 'x', 'y' or 'z'. For
%                       example: 'Pyy' will convolute the yy component of
%                       the polarisation matrix with the dispersion. The
%                       coordinates used are in the Blume-Maleev coordinate
%                       system, see below.
%               'Pa'    bins the intensity of the simulated polarised
%                       neutron scattering, with inciden polarisation of
%                       Pa. Letter a can be 'x', 'y' or 'z'. For example:
%                       'Py' will convolute the scattering intensity
%                       simulated for incident polarisation Pi || y. The
%                       used coordinates are in the Blume-Maleev coordinate
%                       system, see below.
%               'fName' where fName is one of the field names of the input
%                       structure spectra. This field should contain a
%                       matrix with size [nMode nHkl].
%           Any linear combination of the above are allowed, for example:
%           'Sxx+2*Syy' bins the linear combination of the xx component of
%           the spin-spin correlation function with the yy component.
%           Several cross section can be convoluted and stored
%           independently, if component is a cell array containing strings
%           each containing any linear combination of cross sections as
%           above, the cell array needs to have size [1 nCell].
%
% Evect     Vector, defines the center/edge of the energy bins of the
%           calculated output, dimensions are is [1 nE]. The energy units
%           are defined by the unit.kB property of the sw object. Default
%           value is an edge bin: linspace(0,1.1*maxOmega,501).
% binType   String, determines the type of bin give, possible options:
%               'cbin'    Center bin, the center of each energy bin is given.
%               'ebin'    Edge bin, the edges of each bin is given.
%           Default is 'ebin'.
% T         Temperature, used to calculate the Bose factor in units
%           depending on the Boltzmann constant (sw.unit.kB). Default
%           temperature is taken from obj.single_ion.T. The Bose factor is
%           included in swConv field of the output.
% sumtwin   If true, the spectra of the different twins will be summed
%           together weighted with the normalized volume fractions. Default
%           is true.
% modeIdx   Select certain spin wave modes from the 2*nMagAtom number of
%           modes to include in the output. Default is 1:2*nMagAtom to
%           include all modes.
% epsilon   Error limit, used to determine whether a given energy bin is
%           uniform or not. Default is 1e-5.
% autoEmin  Due to the finite numerical precision, the spin wave energies
%           can contain small imaginary energies. These can ruin the
%           convoluted spectrum at low energies. To improve the spectrum,
%           the lowest energy bin should start above the imaginary part of
%           the spin wave energy. If 'autoEmin' is set to true, it
%           calculates the bottom of the first energy bin automatically and
%           overwrites the given value. Only works if the input energy bin
%           starts with zero. Default is false.
% imagChk   Checks that the imaginary part of the spin wave dispersion is
%           smaller than the energy bin size. Default is true.
%
% The Blume-Maleev coordinate system is a cartesian coordinate system
% with (xBM, yBM and zBM) basis vectors as follows:
%           xBM    parallel to the momentum transfer Q,
%           yBM    perpendicular to xBM in the scattering plane,
%           zBM    perpendicular to the scattering plane.
%
%
% Output:
%
% spectra contains the following additional fields beside the input:
%
% swConv    Stores the selected cross section binned along energy, size is
%           [nE nHkl]. Includes the Bose factor.
% swInt     Stores the selected cross sections for every mode, size is
%           [nMode nHkl].
% T         Input temperature.
% component Cell that contains the input component selector strings.
% Evect     Input energy bin vector, defines the energy bin edge positions
%           (converted from the given bin centers if necessary).
% param     All the other input parameters.
%
% If 'component' parameter is a cell array or the spectra of multiple
% twins are convoluted separately, swConv and swInt will be packaged into
% a cell. The dimensions of the cell are [nConv nTwin].
%
% Example:
%
% spectra = sw_egrid(spectra,'component',{'Sxx+Syy' 'Szz'},'Evect',linspace(0,5,51));
%
% The line will create an energy bin, with steps of 0.1 and bins the
% spin-spin correlation function. Two different matrices will be
% calculated, first using the sum of the Sxx and Syy components, second
% will contain the Szz component of the correlation function.
%
% See also SW.SPINWAVE, SW_NEUTRON.
%

if nargin == 0
    help sw_egrid;
    return;
end

if isfield(spectra,'obj')
    T0 = spectra.obj.single_ion.T;
else
    T0 = 0;
end

% use Evect if defined in spectra
if isfield(spectra,'Evect')
    E0 = spectra.Evect;
else
    E0 = [];
end

inpForm.fname  = {'Evect' 'T'   'component' 'sumtwin' 'modeIdx'  'epsilon'};
inpForm.defval = {E0      T0    'Sperp'     true      zeros(1,0) 1e-5     };
inpForm.size   = {[1 -1]  [1 1] [1 -2]      [1 1]     [1 -4]     [1 1]    };
inpForm.soft   = {true    false false       false     false      false    };

inpForm.fname  = [inpForm.fname  {'autoEmin' 'imagChk' 'binType'}];
inpForm.defval = [inpForm.defval {false       true       'ebin'  }];
inpForm.size   = [inpForm.size   {[1 1]      [1 1]      [1 -5]  }];
inpForm.soft   = [inpForm.soft   {false      false      false   }];

param = sw_readparam(inpForm, varargin{:});

switch param.binType
    case 'ebin'
        eBin = true;
        param.binType = 1;
    case 'cbin'
        eBin = false;
        param.binType = 2;
    otherwise
        error('sw_egrid:WrongInput','Wrong energy bin type!')
end

if isempty(param.Evect)
    if iscell(spectra.omega)
        omegaTemp = cell2mat(spectra.omega);
        Emax = max(real(omegaTemp(:)));
        clear('omegaTemp');
    else
        Emax = max(real(spectra.omega(:)));
    end
    if Emax == 0
        Emax = 1;
    end
    
    param.Evect = linspace(0,1.1*Emax,501);
    eBin = true;
end

% parse the component string
if iscell(param.component)
    nConv = numel(param.component);
    parsed = cell(1,nConv);
    for ii = 1:numel(param.component)
        parsed{ii} = sw_parstr(param.component{ii});
    end
elseif isstruct(param.component)
    nConv  = 1;
    parsed = {param.component};
    param.component = {parsed{1}.string};
else
    nConv = 1;
    parsed = {sw_parstr(param.component)};
    param.component = {param.component};
end

% get all the used type of correlation functions
parType = [];
for ii = 1:numel(parsed)
    for jj = 1:numel(parsed{ii}.type)
        parType = [parType parsed{ii}.type{jj}(1)]; %#ok<AGROW>
    end
end
parType = ismember(1:5,parType);

if parType(1)
    if ~isfield(spectra,'Sperp') || isempty(spectra.Sperp)
        % auto produce neutron scattering cross section
        
        spectra = sw_neutron(spectra);
        %error('sw_egrid:WrongInput',['Reference to non-existent field ''Sperp'','...
        %    ' use ''sw_neutron'' to produce the neutron scattering cross sections,'...
        %    ' before binning in energy!'])
    end
    Sperp = spectra.Sperp;
else
    Sperp = [];
end

if parType(3)
    if isfield(spectra,'Mab') && ~isempty(spectra.Mab)
        Mab = spectra.Mab;
    else
        error('sw_egrid:WrongInput',['Reference to non-existent field ''Mab'','...
            ' use ''sw_neutron(''pol'',true)'' to produce the polarised neutron scattering cross sections,'...
            ' before binning with energy transfer!'])
    end
else
    Mab = [];
end

if parType(4)
    if isfield(spectra,'Pab') && ~isempty(spectra.Pab)
        Pab = spectra.Pab;
    else
        error('sw_egrid:WrongInput',['Reference to non-existent field ''Pab'','...
            ' use ''sw_neutron(''pol'',true)'' to produce the polarised neutron scattering cross sections,'...
            ' before binning with energy transfer!'])
    end
else
    Pab = [];
end

if parType(5)
    if isfield(spectra,'intP') && ~isempty(spectra.intP)
        intP = spectra.intP;
    else
        error('sw_egrid:WrongInput',['Reference to non-existent field ''intP'','...
            ' use ''sw_neutron(''pol'',true)'' to produce the polarised neutron scattering cross sections,'...
            ' before binning with energy transfer!'])
    end
else
    intP = [];
end

% pack all cross section into a cell for easier looping
if isfield(spectra,'omega')
    if iscell(spectra.omega)
        nTwin = numel(spectra.omega);
        omega = spectra.omega;
        Sab   = spectra.Sab;
    else
        nTwin = 1;
        omega = {spectra.omega};
        Sab   = {spectra.Sab};
        intP  = {intP};
        Pab   = {Pab};
        Mab   = {Mab};
        Sperp = {Sperp};
    end
else
    nTwin = 1;
    omega = {};
    Sab   = {spectra.Sab2};
end

% extract the requested cross section
if isfield(spectra,'omega')
    nMode = size(omega{1},1);
    nHkl  = size(omega{1},2);
else
    nMode = size(spectra.Sab2,3);
    nHkl = size(spectra.Sab2,4);
end

% Default value of the modeIdx vector selects all modes for output
if isempty(param.modeIdx)
    param.modeIdx = 1:nMode;
end

% DSF stores the intensity that is going to be convoluted
DSF = cell(nConv,nTwin);

for tt = 1:nTwin
    for ii = 1:numel(parsed)
        par0 = parsed{ii};
        DSF{ii,tt} = zeros(nMode, nHkl);
        for jj = 1:length(par0.type)
            switch par0.type{jj}(1)
                case 1
                    DSF{ii,tt} = DSF{ii,tt} + par0.preFact(jj)*Sperp{tt};
                case 2
                    DSF{ii,tt} = DSF{ii,tt} + par0.preFact(jj)*permute(Sab{tt}(par0.type{jj}(2),par0.type{jj}(3),:,:),[3 4 1 2]);
                case 3
                    DSF{ii,tt} = DSF{ii,tt} + par0.preFact(jj)*permute(Mab{tt}(par0.type{jj}(2),par0.type{jj}(3),:,:),[3 4 1 2]);
                case 4
                    DSF{ii,tt} = DSF{ii,tt} + par0.preFact(jj)*permute(Pab{tt}(par0.type{jj}(2),par0.type{jj}(3),:,:),[3 4 1 2]);
                case 5
                    DSF{ii,tt} = DSF{ii,tt} + par0.preFact(jj)*permute(intP{tt}(par0.type{jj}(2),:,:),[2 3 1]);
                otherwise
                    DSF{ii,tt} = DSF{ii,tt} + par0.preFact(jj)*spectra.(par0.type{jj});
            end
        end
    end
end

% save the edge bins
Evect   = sort(param.Evect);
if eBin
    eEvect = Evect;
else
    dE = diff(Evect);
    eEvect = [Evect-[dE(1) dE]/2 Evect(end)+dE(end)/2];
end

if isfield(spectra,'omega')
    % Create vector for energy values, and put extra value below minimum and
    % above maximum for easy indexing swConv.
    epsilon = 1e-8;
    
    if eBin
        Evect  = (Evect(2:end)+Evect(1:(end-1)))/2; 
    end
    % energy bin parameters
    nE       = numel(Evect);
    dE       = diff(Evect);
    
    if param.imagChk
        % find the maximum of the imaginary part of the spin wave energies
        % checks only the first twin!
        ioMax = max(abs(imag(omega{1}(:))));
        
        if ioMax > max(abs(dE(:)))
            error('sw:egrid:BadSolution',['The imaginary part of the spin '...
                'wave energes is larger than the bin size! Improve '...
                'your calculation or disable imagChk option!']);
        end
    end
    
    if param.autoEmin && abs(Evect(1)-dE(1)/2)<epsilon
        if ~exist('ioMax','var')
            ioMax = max(abs(imag(omega{1}(:))));
        end
        Evect(1) = Evect(1)+ioMax+2*epsilon;
        eEvect(1)= eEvect(1)+ioMax+2*epsilon;
        dE(1)    = dE(1)-(ioMax+2*epsilon);
    end
    
    
    % if the energy bin is equally spaced a faster intexing of the
    % modes can be used
    isequalE = sum(abs(dE-dE(1))<param.epsilon) == (nE-1);
    E0 = Evect(1);
    
    if ~isempty(Evect)
        Evect = [Evect(1)-dE(1)-epsilon; Evect(:); Evect(end)+dE(end)+epsilon];
    else
        Evect = [-epsilon; epsilon];
    end
    
    dE = dE(1);
    
    % Create indices in the matrix by searching for the closest value, size
    % nMode x nHkl. Put all the modes to the positive side for magnon creation.
    % The negative side will be the same, however with different Bose factor
    % for non-zero temperature.
    idxE = cell(1,nTwin);
    

    for tt = 1:nTwin
        % put the modes that are not in the modeIdx parameter above the
        % energy bin vector
        omega{tt}(~ismember(1:nMode,param.modeIdx),:) = Evect(end);
        
        % faster binning
        if isequalE
            idxE{tt} = floor((real(omega{tt})-E0)/dE)+2;
            idxE{tt}(idxE{tt}<2) = 1;
            idxE{tt}(idxE{tt}>nE+2) = nE+2;
        else
            % memory intensive binnin, bad for large numel(omega)
            [~, idxE{tt}] = min(abs(repmat(real(omega{tt}),[1 1 nE+2])-repmat(permute(Evect,[2 3 1]),[nMode nHkl 1])),[],3);
        end
        
        % Creates indices in the swConv matrix.
        idxE{tt} = idxE{tt} + repmat((0:nHkl-1).*(nE+2),[nMode 1]);
        idxE{tt} = idxE{tt}(:);
    end
    
    % Sums up the intensities in DSF into swConv.
    swConv = cell(nConv,nTwin);
    
    for tt = 1:nTwin
        for ii = 1:nConv
            swConv{ii,tt} = reshape(accumarray(idxE{tt},DSF{ii,tt}(:),[(nE+2)*nHkl 1]),[(nE+2) nHkl]);
        end
    end
    
    % Calculate Bose temperature factor for magnons
    if param.T==0
        nBose = double(Evect(2:(end-1))>=0);
    else
        nBose = 1./(exp(abs(Evect(2:(end-1)))./(spectra.obj.unit.kB*param.T))-1)+double(Evect(2:(end-1))>=0);
    end
    
    % Multiply the intensities with the Bose factor.
    for tt = 1:nTwin
        for ii = 1:nConv
            swConv{ii,tt} = bsxfun(@times,swConv{ii,tt}(2:(end-1),:),nBose);
            swConv{ii,tt}(isnan(swConv{ii,tt})) = 0;
        end
    end
    
else
    swConv = DSF;
end

% sum up twin spectra if requested
if param.sumtwin
    % normalised volume fractions of the twins
    if isfield(spectra,'obj')
        vol = spectra.obj.twin.vol/sum(spectra.obj.twin.vol);
    else
        vol = 1;
    end
    swConvT = cell(nConv,1);
    DSFT    = cell(nConv,1);
    for ii = 1:nConv
        swConvT{ii} = swConv{ii,1}*vol(1);
        DSFT{ii}    = DSF{ii,1}*vol(1);
        for tt = 2:nTwin
            swConvT{ii} = swConvT{ii} + swConv{ii,tt}*vol(tt);
            DSFT{ii}    = DSFT{ii} + DSF{ii,tt}*vol(tt);
        end
    end
    swConv = swConvT;
    DSF    = DSFT;
end


spectra.T     = param.T;
spectra.Evect = eEvect;

if isfield(spectra,'swRaw')
    spectra = rmfield(spectra,'swRaw');
end

if numel(swConv) == 1
    spectra.swConv    = swConv{1};
    spectra.swInt     = DSF{1};
    spectra.component = param.component{1};
else
    spectra.swConv    = swConv;
    spectra.swInt     = DSF;
    spectra.component = param.component;
end

spectra.param.sumtwin  = param.sumtwin;

end