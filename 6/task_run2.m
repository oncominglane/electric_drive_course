clear;
clc;

modelPath = "C:\dev\electric_drive_course\6\task.slx";
modelName = "task";

load_system(modelPath);

% временно отключаем warning-и
oldWarningState = warning;
warning("off", "all");

oldAlgLoopSetting = get_param(modelName, "AlgebraicLoopMsg");
set_param(modelName, "AlgebraicLoopMsg", "none");

cleanupObj = onCleanup(@() restoreWarnings(modelName, oldWarningState, oldAlgLoopSetting));

% параметры
p = 3;

omega = 750 * 2*pi / 60;   % 750 об/мин = 78.54 рад/с

% диапазоны токов
Id_start = -170;
Id_stop  = -500;
Id_step  = -10;

Iq_start = 900;
Iq_stop  = 1300;
Iq_step  = 5;

current_error_limit = 0.05;   % A
simTime = 5;                 % seconds

assignin("base", "omega", omega);

results = [];

fprintf("Id_ref\t Iq_ref\t Id_avg\t\t Iq_avg\t\t Torque_avg\t Error\t\t OK\n");

bestTorque = -inf;
bestRow = [];

for Id_ref = Id_start:Id_step:Id_stop

    assignin("base", "Id_ref", Id_ref);

    for Iq_ref = Iq_start:Iq_step:Iq_stop

        assignin("base", "Iq_ref", Iq_ref);

        simOut = sim(modelName, ...
            "StopTime", num2str(simTime), ...
            "ReturnWorkspaceOutputs", "on");

        Id_data = simOut.Id;
        Iq_data = simOut.Iq;
        T_data  = simOut.torque;

        [t_Id, Id_values] = getSignalData(Id_data, simTime);
        [t_Iq, Iq_values] = getSignalData(Iq_data, simTime);
        [t_T,  T_values]  = getSignalData(T_data,  simTime);

        t_start_avg = 0.8 * simTime;

        Id_tail = Id_values(t_Id >= t_start_avg);
        Iq_tail = Iq_values(t_Iq >= t_start_avg);
        T_tail  = T_values(t_T  >= t_start_avg);

        Id_avg = mean(Id_tail);
        Iq_avg = mean(Iq_tail);
        T_avg  = mean(T_tail);

        current_error = max(abs(Id_avg - Id_ref), abs(Iq_avg - Iq_ref));
        ok = current_error < current_error_limit;

        results = [results; Id_ref, Iq_ref, Id_avg, Iq_avg, T_avg, current_error, ok];

        fprintf("%7.1f\t %6.1f\t %8.4f\t %8.4f\t %10.4f\t %8.4f\t %d\n", ...
            Id_ref, Iq_ref, Id_avg, Iq_avg, T_avg, current_error, ok);

        if ok && T_avg > bestTorque
            bestTorque = T_avg;
            bestRow = [Id_ref, Iq_ref, Id_avg, Iq_avg, T_avg, current_error, ok];
        end
    end
end

resultsTable = array2table(results, ...
    "VariableNames", ["Id_ref", "Iq_ref", "Id_avg", "Iq_avg", ...
                      "Torque_avg", "Current_error", "OK"]);

disp(resultsTable);

if ~isempty(bestRow)
    fprintf("\nМаксимальный допустимый момент найден:\n");
    fprintf("Id_ref = %.2f A\n", bestRow(1));
    fprintf("Iq_ref = %.2f A\n", bestRow(2));
    fprintf("Id_avg = %.4f A\n", bestRow(3));
    fprintf("Iq_avg = %.4f A\n", bestRow(4));
    fprintf("Torque_avg = %.4f Nm\n", bestRow(5));
else
    fprintf("\nДопустимых точек не найдено.\n");
end


function [t, values] = getSignalData(signalData, simTime)

    if isa(signalData, "timeseries")
        t = signalData.Time;
        values = squeeze(signalData.Data);
    else
        if size(signalData, 2) >= 2
            t = signalData(:,1);
            values = signalData(:,2);
        else
            values = squeeze(signalData);
            t = linspace(0, simTime, length(values))';
        end
    end

    t = t(:);
    values = values(:);
end

function restoreWarnings(modelName, oldWarningState, oldAlgLoopSetting)
    warning(oldWarningState);
    set_param(modelName, "AlgebraicLoopMsg", oldAlgLoopSetting);
end