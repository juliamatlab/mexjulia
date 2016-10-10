%% Creating the MATLAB Logo
% This example shows how to create and display the MATLAB(R) logo.

% Copyright 2014 The MathWorks, Inc.

%%
% Use the |membrane| command to generate the surface data for the logo.

[x,y,z] = sphere(100);

%%
% Create a figure and an axes to display the logo.  Then, create a surface
% for the logo using the points from the |membrane| command. Turn off the
% lines in the surface.

f = figure;
axis equal;
hold on;

s1 = surface(x-1,y,z);
s2 = surface(x+1,y,z);
s3 = surface(x,y+2*sqrt(3/4),z);
ss = [s1, s2, s3];

for s = ss
  s.EdgeColor = 'none';
end
view(3)

l1 = light;
l1.Position = [160 400 80];
l1.Style = 'local';
l1.Color = [1 1 1];
 
l2 = light;
l2.Position = [.5 -1 .4];
l2.Color = [1 1 1];

jred = [211,79,73]/255;
jgreen = [78,153,67]/255;
jpurple = [150,107,178]/255;

s1.FaceColor = jred;
s2.FaceColor = jpurple;
s3.FaceColor = jgreen;

for s = ss
s.FaceLighting = 'gouraud';
s.AmbientStrength = 0.3;
s.DiffuseStrength = 0.6; 
s.BackFaceLighting = 'lit';

s.SpecularStrength = 1;
s.SpecularColorReflectance = 1;
s.SpecularExponent = 7;
end

axis off
f.Color = 'black';
