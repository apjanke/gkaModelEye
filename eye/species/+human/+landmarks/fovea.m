function fovea = fovea( eye )
% Returns the fovea landmark sub-field of an eye model structure
%
% Syntax
%  fovea = human.landmarks.fovea( eye )
%
% Description:
%   Calculates the position on the retinal surface of the fovea.
%
% Inputs
%   eye                   - Structure.
%
% Outputs
%   fovea                 - Structure with the subfields degField,
%                           geodetic, and coords
%
% Examples:
%{
    % Plot the retinal surface and the positions of the fovea
    eye = modelEyeParameters('sphericalAmetropia',-1.5,'calcLandmarkFovea',true,'calcLandmarkOpticDisc',true);
    S = eye.retina.S;
    boundingBox = eye.retina.boundingBox;
    figure
    quadric.plotSurface(S,boundingBox,[0.9 0.9 0.9],0.8,'b','g');
    camlight
    lighting gouraud
    hold on

    % Add the retinal landmarks
    plot3(eye.landmarks.vertex.coords(1),eye.landmarks.vertex.coords(2),eye.landmarks.vertex.coords(3),'+m','MarkerSize',10);
    plot3(eye.landmarks.fovea.coords(1),eye.landmarks.fovea.coords(2),eye.landmarks.fovea.coords(3),'+r','MarkerSize',10);
    plot3(eye.landmarks.opticDisc.coords(1),eye.landmarks.opticDisc.coords(2),eye.landmarks.opticDisc.coords(3),'+k','MarkerSize',10);

    % Add the geodetic path
    [geoDistance,~,~,geodeticPathCoords] = quadric.panouGeodesicDistance(S,eye.landmarks.fovea.geodetic,eye.landmarks.opticDisc.geodetic);
    plot3(geodeticPathCoords(:,1),geodeticPathCoords(:,2),geodeticPathCoords(:,3),'-y','MarkerSize',10);
%}
%{
    % ETTBSkip -- This takes about 15 minutes to run.
    % Calculate the projective distance between the optic disc and fovea for
    % a range of spherical refractive errors
    SRvals = -10:1:2;
    for ii = 1:length(SRvals)
        eye = modelEyeParameters('sphericalAmetropia',SRvals(ii),'calcLandmarkFovea',true,'calcLandmarkOpticDisc',true);
        odf(ii) = sqrt(sum((eye.landmarks.fovea.coords(2:3) - eye.landmarks.opticDisc.coords(2:3)).^2));
    end
    figure
    plot(SRvals,odf,'-*r');
    hold on
    % Compare these model values to the measurements reported by Jonas 2015
    % PloS One
    axialLengthFromSR = @(SR) 23.58-(SR.*0.299);
    odf_jonas = @(SR) 0.04 + 0.2.*(axialLengthFromSR(SR));
    plot(SRvals,odf_jonas(SRvals),'*b')
%}



% The location of the fovea on the retina is determined by first specifying
% the angle alpha, which is the angle between the optical and visual axes
% of the eye. The visual axis is defined by the nodal ray that originates
% at the fovea.
%
% The angle alpha has been proposed to vary with spherical refractive
% error:
%
%   Tabernero, Juan, et al. "Mechanism of compensation of aberrations in
%   the human eye." JOSA A 24.10 (2007): 3274-3283.
%
%   Mathur, Ankit, Julia Gehrmann, and David A. Atchison. "Pupil shape as
%   viewed along the horizontal visual field." Journal of vision 13.6
%   (2013): 3-3.
%
% In each case, there is monotonic decrease in alpha with more negative
% spherical ametropia. The precise form of this is difficult to determine
% across studies. As a practical matter, I set the horizontal alpha value
% following the approach given in Figure 14 of Tabernero:
%
%{
    alpha0 = 5.8;
    L = @(SR) 16.5 / (16.5 - 0.299*SR );
    taberneroAlpha = @(SR) atand(L(SR)*tand(alpha0));
%}
%
% where SR is spherical refractive error in diopters and alpha0 is the
% alpha value for an emmetropic eye. The alpha0 value is 5.4, which is
% the value given by Mathur 2013. For the vertical alpha, I assume an
% elevation of 2.5 degrees in the emmetropic eye.
%
a0 = [5.45 2.5 0];
L = @(SR) 16.5 / (16.5 - 0.299*SR );
alpha = @(SR) atand(L(SR).*tand(a0));
fovea.degField = alpha(eye.meta.sphericalAmetropia);
switch eye.meta.eyeLaterality
    case 'Right'
        % No change needed
    case 'Left'
        fovea.degField(1) = -fovea.degField(1);
    otherwise
        error('eye laterality not defined')
end

% The calculation of the position of the retinal landmarks is based upon
% empirical measurements of visual field position. These measurements are
% done with the eye at resting accommodation (1.5 Diopeters), in the
% visible spectrum, with the eye and targets in air. It is also assumed
% that the position of the retinal landmarks were fixed at the point of
% maturity of the visual system. Therefore, the meta values of the passed
% eye structure are changed here to reflect these circumstances for this
% calculation.
eye.meta.spectralDomain = 'vis';
eye.meta.ageYears = 18;
eye.meta.accommodationDiopters = 1.5;
cameraMedium = 'air';

% Update the lens field for these values
eye.lens = human.lens(eye);

% Now calculate the location on the retina corresponding to this visual
% angle wrt the optical axis.
[fovea.geodetic,fovea.coords] = calcRetinaFieldPoint( eye, fovea.degField, cameraMedium );

% Transposing to get the values in the right row-column orientation
fovea.geodetic=fovea.geodetic';
fovea.coords=fovea.coords';

end
