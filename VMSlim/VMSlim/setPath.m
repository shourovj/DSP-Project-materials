
function setPath()

err = 0;

mpath = mfilename('fullpath');
HOME = fileparts(mpath);

vmpath = fullfile(HOME,'vm');


addpath(HOME);
addpath(fullfile(HOME,'matlabPyrTools'));
addpath(vmpath);
addpath(fullfile(vmpath,'vmcompute'));
addpath(fullfile(vmpath,'vmget'));
end