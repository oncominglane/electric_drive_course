clear; clc; close all;

%% Имя модели
model = "task3";

%% Номинальные значения
Va_nom = 420;
Vf_nom = 256.68;

%% Диапазон моментов нагрузки, Н*м
% Здесь задаём положительные значения нагрузки, в модель подаём со знаком минус
M_values = 0:2:40;

%% Настройки моделирования
StopTime = "8";          % время одного расчёта, с
settlePart = 0.2;        % берём последние 20% сигнала для усреднения

load_system(model);

%% ------------------------------------------------------------
%  1. Механические характеристики при разных Va и номинальном Vf
% ------------------------------------------------------------

Va_list = [0.1 0.5 1.0] * Va_nom;
Vf_fixed = Vf_nom;

char_Va = struct();

figure;
hold on; grid on;

for i = 1:length(Va_list)

    Va = Va_list(i);
    Vf = Vf_fixed;

    torque_points = zeros(size(M_values));
    omega_points  = zeros(size(M_values));

    for k = 1:length(M_values)

        M = M_values(k);

        simIn = Simulink.SimulationInput(model);

        simIn = simIn.setVariable("Va", Va);
        simIn = simIn.setVariable("Vf", Vf);

        simIn = simIn.setVariable("M_load", -M);

        simOut = sim(simIn);

        torque_sig = simOut.torque;
        omega_sig  = simOut.omega;

        torque_points(k) = getSteadyValue(torque_sig, settlePart);
        omega_points(k)  = getSteadyValue(omega_sig, settlePart);

    end

    % Для оси X удобнее использовать положительный момент нагрузки
    torque_plot = abs(torque_points);

    char_Va(i).Va = Va;
    char_Va(i).Vf = Vf;
    char_Va(i).M = torque_plot;
    char_Va(i).omega = omega_points;

    plot(torque_plot, omega_points, "LineWidth", 2, ...
        "DisplayName", sprintf("Va = %.0f%%, Vf = 100%%", Va / Va_nom * 100));

end

xlabel("M, Н·м");
ylabel("\omega, рад/с");
title("Механические характеристики ДПТ при изменении напряжения якоря");
legend("Location", "best");


%% ------------------------------------------------------------
%  2. Механические характеристики при разных Vf и номинальном Va
% ------------------------------------------------------------

Va_fixed = Va_nom;
Vf_list = [1.0 0.7 0.5] * Vf_nom;

char_Vf = struct();

figure;
hold on; grid on;

for i = 1:length(Vf_list)

    Va = Va_fixed;
    Vf = Vf_list(i);

    torque_points = zeros(size(M_values));
    omega_points  = zeros(size(M_values));

    for k = 1:length(M_values)

        M = M_values(k);

        simIn = Simulink.SimulationInput(model);

        simIn = simIn.setVariable("Va", Va);
        simIn = simIn.setVariable("Vf", Vf);
        simIn = simIn.setVariable("M_load", -M);

        simOut = sim(simIn);

        torque_sig = simOut.torque;
        omega_sig  = simOut.omega;

        torque_points(k) = getSteadyValue(torque_sig, settlePart);
        omega_points(k)  = getSteadyValue(omega_sig, settlePart);

    end

    torque_plot = abs(torque_points);

    char_Vf(i).Va = Va;
    char_Vf(i).Vf = Vf;
    char_Vf(i).M = torque_plot;
    char_Vf(i).omega = omega_points;

    plot(torque_plot, omega_points, "LineWidth", 2, ...
        "DisplayName", sprintf("Va = 100%%, Vf = %.0f%%", Vf / Vf_nom * 100));

end

xlabel("M, Н·м");
ylabel("\omega, рад/с");
title("Механические характеристики ДПТ при изменении напряжения возбуждения");
legend("Location", "best");



%% ------------------------------------------------------------
%  Локальная функция для снятия установившегося значения
% ------------------------------------------------------------

function y_ss = getSteadyValue(sig, settlePart)

    % Поддержка timeseries
    if isa(sig, "timeseries")
        y = sig.Data;
        t = sig.Time;

    % Поддержка timetable
    elseif istimetable(sig)
        y = sig{:,1};
        t = seconds(sig.Time - sig.Time(1));

    % Поддержка массива Nx2: [time, value]
    elseif isnumeric(sig) && size(sig,2) >= 2
        t = sig(:,1);
        y = sig(:,2);

    % Поддержка обычного массива
    elseif isnumeric(sig)
        y = sig;
        t = (1:length(y))';

    else
        error("Неизвестный формат сигнала To Workspace.");
    end

    y = squeeze(y);

    if size(y,2) > 1
        y = y(:,1);
    end

    t_start = t(end) - settlePart * (t(end) - t(1));
    idx = t >= t_start;

    y_ss = mean(y(idx));

end