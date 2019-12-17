clear; close all; clc;

addpath('../../config')
addpath('../../data/workspace_files')
addpath('../../libs/cdpr_model')
addpath('../../libs/export_utilities')
addpath('../../libs/numeric')
addpath('../../libs/orientation_geometry')
addpath('../../libs/under_actuated')
addpath('../../libs/prototype_log_parser')
addpath('../../libs/prototype_log_parser/msgs')
folder = '../../data';

[cdpr_parameters, cdpr_variables, ws_parameters, cdpr_outputs, record, utilities] =...
  LoadConfigAndInit("config_calib","Homing");

tension_limits = [40 100];
start = SimulateGoToStartProcedureErroneous...
  (cdpr_parameters, cdpr_variables, ws_parameters, record, utilities, tension_limits);
home = SimulateGoToStartProcedureIdeal...
  (cdpr_parameters, cdpr_variables, start.pose, record, utilities, tension_limits);

% Here automatic initial guess for the homing algorithm is generated,
% making use of banal extimation of the workspace center (geometrical
% property  of the robot) and acquired data. No need for user interaction.

[imported_data_coarse, ~] = parseCableRobotLogFile('data.log');
%[imported_data_coarse, ~] = parseCableRobotLogFile('/tmp/cable-robot-logs/data.log');
[delta_l, delta_sw] = Reparse(imported_data_coarse.actuator_status.values,...
  cdpr_parameters);
init_guess = GenerateInitialGuess(cdpr_parameters, cdpr_variables, delta_l,...
  home, record, utilities);

init_guess = [start.l; start.sw; init_guess];
[sol, resnorm, residual, exitflag, output] = lsqnonlin(@(v)HomingOptimizationFunction...
  (cdpr_parameters, record, delta_l, delta_sw, v), init_guess, [], [],...
  utilities.lsqnonlin_options_grad);
l0 = sol(1:cdpr_parameters.n_cables, 1);
s0 = sol(cdpr_parameters.n_cables + 1 : 2 * cdpr_parameters.n_cables, 1);
[pose0, resnormp, residualp, exitflagp, outputp] = lsqnonlin(@(v)FunDkGsSwL...
  (cdpr_parameters, l0, s0, v, record), start.pose, [], [],...
  utilities.lsqnonlin_options_grad);

j_struct.init_pose = pose0;
json.startup
json.write(j_struct, 'results.json')
fprintf('Results dumped in %s\n', strcat(pwd, '/results.json'))
