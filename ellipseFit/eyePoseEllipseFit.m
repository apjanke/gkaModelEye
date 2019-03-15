function [eyePose, RMSE, fittedEllipse, fitAtBound, nSearches] = eyePoseEllipseFit(Xp, Yp, sceneGeometry, varargin)
% Fit an image plane ellipse by perspective projection of a pupil circle
%
% Syntax:
%  [eyePose, RMSE, fittedEllipse, fitAtBound] = eyePoseEllipseFit(Xp, Yp, sceneGeometry)
%
% Description:
%   The routine fits points on the image plane based upon the eye
%   parameters (azimuth, elevation, torsion, stop radius) that produce the
%   best fitting ellipse projected according to sceneGeometry.
%
%   The search is constrained by the upper and lower bounds of the eyePose.
%   The default values specified here represent the physical boundaries of
%   the rotation model. Tighter, biologically informed constraints may be
%   passed by the calling function.
%
% Inputs:
%   Xp, Yp                - Vector of points to be fit
%   sceneGeometry         - Structure. SEE: createSceneGeometry
%
% Optional key/value pairs:
%  'x0'                   - A 1x4 vector or an nx4 matrix that provides
%                           starting points for the search for the eyePose.
%                           If not defined, the starting point will be
%                           estimated either from the eyePoseGrid field of
%                           the sceneGeometry or from the coordinates of
%                           the ellipse center.
%                           selected within the eyePose bounds.
%  'eyePoseLB/UB'         - A 1x4 vector that provides the lower (upper)
%                           bounds on the eyePose [azimuth, elevation,
%                           torsion, stop radius]. The default values here
%                           represent the physical limits of the projection
%                           model for azimuth, elevation, and stop radius.
%                           Torsion is constrained to zero by default.
%  'rmseThresh'           - Scalar that defines the stopping point for the
%                           search. The default value allows reconstruction
%                           of eyePose within 0.1% of the veridical,
%                           simulated value.
%  'repeatSearchThresh'   - Scalar. If the RMSE output value obtained is
%                           greater than this threshold, then a repeat
%                           search across eyePose values will be conducted
%                           to account for the possibility that the
%                           solution obtained was a local minimum.
%  'nMaxSearches'         - Scalar. The maximum number of searches that the
%                           routine will conduct as it attempts to avoid
%                           local minima.
%  'searchCount'          - Scalar. The number of searches that have been
%                           conducted so far. This value is modified as
%                           eyePoseEllipseFit calls itself recursively.
%                           It should not be modified by the external
%                           calling function.
%
% Outputs:
%   eyePose               - A 1x4 vector with values for [eyeAzimuth,
%                           eyeElevation, eyeTorsion, stopRadius].
%                           Azimuth, elevation, and torsion are in units of
%                           head-centered (extrinsic) degrees, and stop
%                           radius is in mm.
%   RMSE                  - Root mean squared error of the distance of
%                           boundary point in the image to the fitted
%                           ellipse
%   fittedEllipse         - Parameters of the best fitting ellipse
%                           expressed in transparent form [1x5 vector]
%   fitAtBound            - Logical. Indicates if any of the returned
%                           eyePose parameters are at the upper or lower
%                           boundary.
%   nSearches             - The number of searches conducted.
%



%% Parse input
p = inputParser;

% Required
p.addRequired('Xp',@isnumeric);
p.addRequired('Yp',@isnumeric);
p.addRequired('sceneGeometry',@isstruct);

% Optional
p.addParameter('x0',[],@(x)(isempty(x) | isnumeric(x)));
p.addParameter('eyePoseLB',[-89,-89,0,0.1],@isnumeric);
p.addParameter('eyePoseUB',[89,89,0,4],@isnumeric);
p.addParameter('rmseThresh',1e-2,@isscalar);
p.addParameter('repeatSearchThresh',1.0,@isscalar);
p.addParameter('nMaxSearches',5,@isscalar);
p.addParameter('searchCount',1,@isscalar);

% Parse and check the parameters
p.parse(Xp, Yp, sceneGeometry, varargin{:});


% Set the return variables in the event of an error
eyePose = [nan nan nan nan];
RMSE = nan;
fittedEllipse = [nan nan nan nan nan];
fitAtBound = false;
nSearches = p.Results.searchCount;

% Issue a warning if the bounds do not fully constrain at least one eye
% rotation parameter. This is because there are multiple combinations of
% the three axis rotations that can bring an eye to a destination.
% Typically, the torsion will be constrained with upper and lower bounds of
% zero, reflecting Listing's Law.
if sum((p.Results.eyePoseUB(1:3) - p.Results.eyePoseLB(1:3))==0) < 1
    warning('eyePoseEllipseFit:underconstrainedSearch','The eye pose search across possible eye rotations is underconstrained');
end

%% Set bounds and x0
% Identify the center of projection.
eyePoseLB = p.Results.eyePoseLB;
eyePoseUB = p.Results.eyePoseUB;

% Clear the case of nans in the input
if any(isnan(eyePoseLB)) || any(isnan(eyePoseUB)) || any(any(isnan(p.Results.x0)))
    return
end


% Define an x0 guess if this was not passed
x0set = p.Results.x0;
if isempty(x0set)
    
    % Check if an eyePoseGrid has been calculated for this sceneGeometry.
    % This is a set of pre-calculated pupil ellipses for a set of eyePoses.
    % If so, we will use the best matches of these ellipses to the ellipse
    % fit to the passed perimeter points.
    if isfield(sceneGeometry,'eyePoseGrid')
        
        % Fit an ellipse to the perimeter points
        pe = pupilEllipseFit([Xp Yp]);
        
        % Find the closest matches in the eyePoseGrid to pe
        matchError = sum(...
            abs(sceneGeometry.eyePoseGrid.pupilEllipses(:,[1 2 5]) - pe([1 2 5])) ./ ...
            sceneGeometry.eyePoseGrid.maxEllipseVals([1 2 5]),2);
        
        % Set up the weights to combine closest matches from the
        % eyePoseGrid
        [sortError,indexError]=sort(matchError);
        weights = @(n) (1./sortError(1:n))./sum(1./sortError(1:n));
        
        % Assemble some x0 guesses using sets of the best matches
        x0set = [];
        for nn=[10,7,5,2,1]
            x0set(end+1,:) = sum(sceneGeometry.eyePoseGrid.eyePoses(indexError(1:nn),:).*weights(nn),1);
        end
        
    else
        % There is no eyePoseGrid. Construct an x0 guess by probing the
        % forward model. First identify the center of projection
        rotationCenterEllipse = pupilProjection_fwd([0 0 0 2], sceneGeometry);
        CoP = [rotationCenterEllipse(1),rotationCenterEllipse(2)];
        
        meanXp = mean(Xp);
        meanYp = mean(Yp);
        
        % Probe the forward model to determine how many pixels of change in
        % the location of the pupil ellipse correspond to one degree of
        % rotation.
        probeEllipse=pupilProjection_fwd([1 0 0 2],sceneGeometry);
        pixelsPerDeg = probeEllipse(1)-CoP(1);
        
        % Estimate the eye azimuth and elevation by the X and Y
        % displacement of the ellipse center from the center of projection.
        % Scale these by 75% to roughly account for refractive effects.
        % Torsion is set to zero
        x0(1) = ((meanXp - CoP(1))/pixelsPerDeg).*0.75;
        x0(2) = ((CoP(2) - meanYp)/pixelsPerDeg).*0.75;
        x0(3) = 0;
        
        % Force the angles within bounds
        x0=min([eyePoseUB(1:3); x0]);
        x0=max([eyePoseLB(1:3); x0]);
        
        % Estimate the pupil radius in pixels
        pupilRadiusPixels = max([abs(max(Xp)-min(Xp)) abs(max(Yp)-min(Yp))])/2;
        
        % Probe the forward model at the estimated pose angles to estimate
        % the pupil radius.
        probeEllipse=pupilProjection_fwd([x0(1) x0(2) x0(3) 2], sceneGeometry);
        pixelsPerMM = sqrt(probeEllipse(3)/pi)/2;
        
        % Set the initial value for pupil radius in mm
        x0(4) = pupilRadiusPixels/pixelsPerMM;
        
        % If the absolute value of an estimated angle is less than 2
        % degrees, set the value to close to zero. This is done as fmincon
        % seems to avoid solutions exactly at zero, and this kludge fixes
        % that behavior.
        x0(abs(x0(1:3))<2) = 1e-6;
        
        % Ensure that x0 lies within the bounds with a bit of headroom so
        % that the solver does not get stuck up against a bound.
        boundHeadroom = (eyePoseUB - eyePoseLB)*0.001;
        x0=min([eyePoseUB-boundHeadroom; x0]);
        x0=max([eyePoseLB+boundHeadroom; x0]);
        
        x0set = x0;
    end
else
    x0set = p.Results.x0;
end

% Handle the case of the x0 being a matrix of guesses
nGuesses = size(x0set,1);
if nGuesses>1
    if p.Results.searchCount>nGuesses
        % We are out of guesses. Return.
        return
    end
    x0 = x0set(p.Results.searchCount,:);
else
    x0 = x0set;
end


% Define variables used in the nested functions
lastFVal = nan;
bestFVal = nan;
xLast = [nan nan nan nan]; % Last place pupilProjection_fwd was called
xBest = [nan nan nan nan]; % The x with the lowest objective function value
rmseThresh = p.Results.rmseThresh;
fittedEllipseLast = [nan nan nan nan nan];
fittedEllipseBest = [nan nan nan nan nan];
objScaler = 1e6;            % Inflate the fVal to help fmincon search

% define some search options
options = optimoptions(@fmincon,...
    'Display','off', ...
    'Algorithm','interior-point',...
    'OutputFcn',@outfun);

% Turn off warnings that can arise during the search
warningState = warning;
warning('off','pupilProjection_fwd:ellipseFitFailed');
warning('off','MATLAB:nearlySingularMatrix');
warning('off','MATLAB:singularMatrix');

% Clear the warning buffer
lastwarn('');

% Perform the search with nested objfun and outfun. We place the fmincon
% search within a try-catch block, as mysterious errors rarely occur deep
% within the fmincon routine, and I can't figure out why.
try
    fmincon(@objfun, x0, [], [], [], [], eyePoseLB, eyePoseUB, [], options);
catch
    eyePose = xBest;
    RMSE = bestFVal;
    fittedEllipse = fittedEllipseBest;
    % Check if the fit is at a boundary
    fitAtBound = any([any(eyePose==eyePoseLB) any(eyePose==eyePoseUB)]);
    return
end
    function fVal = objfun(x)
        xLast = x;
        % Obtain the entrance pupil ellipse for this eyePose
        fittedEllipseLast = pupilProjection_fwd(x, sceneGeometry);
        % Check for the case in which the transparentEllipse contains nan
        % values, which can arise if there were an insufficient number of
        % pupil border points remaining after refraction to define an
        % ellipse.
        if any(isnan(fittedEllipseLast))
            fVal = nan;
        else
            % This is the RMSE of the distance values of the boundary
            % points to the ellipse fit.
            explicitEllipse = ellipse_transparent2ex(fittedEllipseLast);
            if isempty(explicitEllipse)
                fVal = nan;
            else
                if any(isnan(explicitEllipse))
                    fVal = nan;
                else
                    fVal = sqrt(nanmean(ellipsefit_distance(Xp,Yp,explicitEllipse).^2))*objScaler;
                end
            end
        end
    end % local objective function
    function stop = outfun(~,optimValues,state)
        stop = false;
        switch state
            case 'init'
                lastFVal = optimValues.fval;
            case 'iter'
                lastFVal = optimValues.fval;
                % Store the current best value for x. This is done as we
                % observe that fmincon can move away from the best solution
                % when azimuth and elevation are close to zero. This
                % behavior has been seen by others:
                %   https://groups.google.com/forum/#!topic/comp.soft-sys.matlab/SuNzbhEun1Y
                if lastFVal < bestFVal || isnan(bestFVal)
                    bestFVal = lastFVal;
                    xBest = xLast;
                    fittedEllipseBest = fittedEllipseLast;
                end
                % Test if we are done the search
                if lastFVal/objScaler < rmseThresh
                    stop = true;
                end
            case 'done'
                % Unused
            otherwise
        end
    end

% Store the best performing values
eyePose = xBest;
RMSE = bestFVal/objScaler;
fittedEllipse = fittedEllipseBest;

% Check if the fit is at a boundary for any parameter that is not locked
notLocked = eyePoseLB ~= eyePoseUB;
fitAtBound = any([any(abs(eyePose(notLocked)-eyePoseLB(notLocked))<1e-4) any(abs(eyePose(notLocked)-eyePoseUB(notLocked))<1e-4)]);

% Restore the warning state
warning(warningState);

% If a warning was received during the execution, exit here to avoid being
% stuck in a recursion loop of bad fits
[~,warnID] = lastwarn();
if ~isempty(warnID)
    % message = ['Received warning during eyePoseEllipseFit: ' warnID ' \n'];
    % fprintf(message);
    return
end

% If the solution has an RMSE that is larger than repeatSearchThresh, we
% consider the possibility that the solution represents a local minimum. We
% repeat the search. The next search will use the next available value in
% the set of x0 guesses. This process terminates when the search count
% exceeds nMaxSearches, or when we run out of guesses.
if isnan(RMSE) || RMSE > p.Results.repeatSearchThresh
    if p.Results.searchCount < p.Results.nMaxSearches
        [eyePose_r, RMSE_r, fittedEllipse_r, fitAtBound_r, nSearches_r] = ...
            eyePoseEllipseFit(Xp, Yp, sceneGeometry, ...
            'x0',x0set,...
            'eyePoseLB',p.Results.eyePoseLB,...
            'eyePoseUB',p.Results.eyePoseUB,...
            'repeatSearchThresh',p.Results.repeatSearchThresh, ...
            'searchCount', p.Results.searchCount+1);
        % Iterate the search counter
        nSearches = nSearches_r;
        % Keep this solution if it is better
        if RMSE_r < RMSE
            eyePose = eyePose_r;
            RMSE = RMSE_r;
            fittedEllipse = fittedEllipse_r;
            fitAtBound = fitAtBound_r;
        end
    end
end

% If the eyePose variable is empty, then a fit could not be found. In this 
% situation return nans for the eyePose and nan for the RMSE
if isempty(eyePose)
    eyePose = [nan nan nan nan];
    RMSE = nan;
    fittedEllipse = [nan nan nan nan nan];
    fitAtBound = false;
end

end % eyePoseEllipseFit


