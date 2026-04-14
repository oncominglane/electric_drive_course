%% Построение предельной характеристики Mmax(w) для модели DC_motor_control_system

clear; clc;

model = 'DC_motor_control_system';
load_system(model);

% -----------------------------
% Параметры перебора
% -----------------------------
w_vec = linspace(10, 380, 25);    % рад/с
M_vec = linspace(0, 20, 81);      % Н*м
t_stop = 20;                      % с

speed_tol = 5;                    % допустимая ошибка по скорости, рад/с
steady_window = 0.2;              % последние 20% сигнала
dw_tol = 1.0;                     % допустимая средняя скорость изменения, рад/с^2

M_max_vec = zeros(size(w_vec));

% -----------------------------
% Основной цикл
% -----------------------------
for i = 1:numel(w_vec)
    w_ref = w_vec(i);
    max_ok_M = 0;

    fprintf('Проверка для w_ref = %.1f рад/с\n', w_ref);

    for j = 1:numel(M_vec)
        M_load = M_vec(j);

        assignin('base', 'w_ref', w_ref);
        assignin('base', 'M_load', M_load);

        simOut = sim(model, ...
            'StopTime', num2str(t_stop), ...
            'ReturnWorkspaceOutputs', 'on');

        % Сигналы из To Workspace
        w_data = simOut.w;
        M_data = simOut.M;

        if ~isa(w_data, 'timeseries')
            error('simOut.w должен быть timeseries');
        end
        if ~isa(M_data, 'timeseries')
            error('simOut.M должен быть timeseries');
        end

        t = w_data.Time(:);
        w = w_data.Data(:);
        M = M_data.Data(:);

        % Анализ конца переходного процесса
        idx0 = round((1 - steady_window) * numel(w));
        idx0 = max(idx0, 2);

        t_end = t(idx0:end);
        w_end_vec = w(idx0:end);
        M_end_vec = M(idx0:end);

        w_end = mean(w_end_vec);
        M_end = mean(M_end_vec);

        % Оценка "успокоенности" по производной скорости
        dw = diff(w_end_vec) ./ diff(t_end);
        dw_end = mean(abs(dw));

        % Критерий удержания скорости
        speed_ok = abs(w_end - w_ref) <= speed_tol;
        steady_ok = dw_end <= dw_tol;

        if speed_ok && steady_ok
            max_ok_M = M_load;
        else
            break;
        end
    end

    M_max_vec(i) = max_ok_M;
    fprintf('  Найденный момент: %.2f Н*м\n', max_ok_M);
end

% -----------------------------
% Теоретическая характеристика
% -----------------------------
Umax = 420;
Imax = 15;
Ra = 2.56;
kE = 1.11;
kT = 1.11;

w_base = (Umax - Ra * Imax) / kE;
w_max0 = Umax / kE;
T_max_const = kT * Imax;

w_theory = linspace(0, w_max0, 300);
T_theory = zeros(size(w_theory));

for k = 1:numel(w_theory)
    if w_theory(k) <= w_base
        T_theory(k) = T_max_const;
    else
        T_theory(k) = kT * (Umax - kE * w_theory(k)) / Ra;
        T_theory(k) = max(T_theory(k), 0);
    end
end

% -----------------------------
% График
% -----------------------------
figure;
plot(w_vec, M_max_vec, 'o-', 'LineWidth', 1.5, 'DisplayName', 'По модели');
hold on;
plot(w_theory, T_theory, '--', 'LineWidth', 1.5, 'DisplayName', 'Теория');
grid on;
xlabel('\omega, рад/с');
ylabel('M_{max}, Н\cdotм');
title('Предельная механическая характеристика ДПТ');
legend('Location', 'best');

fprintf('\nТеоретические значения:\n');
fprintf('Базовая скорость: %.2f рад/с\n', w_base);
fprintf('Максимальная скорость холостого хода: %.2f рад/с\n', w_max0);
fprintf('Максимальный момент: %.2f Н*м\n', T_max_const);