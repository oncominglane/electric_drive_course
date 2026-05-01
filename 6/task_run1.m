clear;
clc;

modelPath = "C:\dev\electric_drive_course\6\task.slx";
modelName = "task";

load_system(modelPath);

% временно отключаем warning-и
oldWarningState = warning;
warning("off", "all");

% также отключаем диагностическое сообщение Simulink про algebraic loop
oldAlgLoopSetting = get_param(modelName, "AlgebraicLoopMsg");
set_param(modelName, "AlgebraicLoopMsg", "none");

cleanupObj = onCleanup(@() restoreWarnings(modelName, oldWarningState, oldAlgLoopSetting));

p = 3;

omega_start = 230;
omega_stop  = 250;
omega_step  = 1;

Iq_limit = 0.05;     % A
simTime = 20;        % seconds

results = [];

assignin("base", "Id_ref", 0);
assignin("base", "Iq_ref", 0);

fprintf("omega_rad_s\t rpm\t\t f_Hz\t\t Iq_avg_tail\t OK\n");

for omega = omega_start:omega_step:omega_stop

    assignin("base", "omega", omega);

    simOut = sim(modelName, ...
        "StopTime", num2str(simTime), ...
        "ReturnWorkspaceOutputs", "on");

    Iq_data = simOut.Iq;

    if isa(Iq_data, "timeseries")
        t = Iq_data.Time;
        Iq_values = squeeze(Iq_data.Data);
    else
        if size(Iq_data, 2) >= 2
            t = Iq_data(:,1);
            Iq_values = Iq_data(:,2);
        else
            Iq_values = squeeze(Iq_data);
            t = linspace(0, simTime, length(Iq_values))';
        end
    end

    t_start_avg = 0.8 * simTime;
    idx = t >= t_start_avg;

    Iq_tail = Iq_values(idx);
    Iq_avg_tail = mean(abs(Iq_tail));

    rpm = omega * 60 / (2*pi);
    f_Hz = p * omega / (2*pi);

    ok = Iq_avg_tail < Iq_limit;

    results = [results; omega, rpm, f_Hz, Iq_avg_tail, ok];

    fprintf("%10.2f\t %8.1f\t %8.2f\t %12.5f\t %d\n", ...
        omega, rpm, f_Hz, Iq_avg_tail, ok);

    if ~ok
        fprintf("\nПорог нарушен при omega = %.2f rad/s\n", omega);
        fprintf("Предыдущая рабочая скорость примерно omega = %.2f rad/s\n", omega - omega_step);
        break;
    end
end

resultsTable = array2table(results, ...
    "VariableNames", ["omega_rad_s", "rpm", "f_Hz", "Iq_avg_tail", "OK"]);

disp(resultsTable);

function restoreWarnings(modelName, oldWarningState, oldAlgLoopSetting)
    warning(oldWarningState);
    set_param(modelName, "AlgebraicLoopMsg", oldAlgLoopSetting);
end