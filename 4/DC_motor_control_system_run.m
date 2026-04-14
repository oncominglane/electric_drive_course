%% Построение предельной характеристики Mmax(w) для модели DC_motor_control_system
% Версия с бинарным поиском по моменту нагрузки

clear; clc;

model = 'DC_motor_control_system';
load_system(model);

% -----------------------------
% Параметры перебора
% -----------------------------
w_vec = linspace(0, 380, 50);    % рад/с
t_stop = 200;                      % с

speed_tol = 4;                    % допустимая ошибка по скорости, рад/с
steady_window = 0.2;              % последние 20% сигнала
dw_tol = 1.4;                     % допустимая средняя скорость изменения, рад/с^2

% -----------------------------
% Параметры бинарного поиска
% -----------------------------
M_min_global = 0;                 % нижняя граница поиска момента, Н*м
M_max_global = 20;                % верхняя граница поиска момента, Н*м
M_tol = 0.05;                     % точность поиска по моменту, Н*м
max_iter = 20;                    % максимум итераций бинарного поиска

M_max_vec = zeros(size(w_vec));

% -----------------------------
% Основной цикл по скорости
% -----------------------------
for i = 1:numel(w_vec)
    w_ref = w_vec(i);

    fprintf('Проверка для w_ref = %.1f рад/с\n', w_ref);

    % Начальные границы бинарного поиска
    M_low = M_min_global;
    M_high = M_max_global;

    % -------------------------
    % Сначала проверим, держит ли вообще верхнюю границу
    % -------------------------
    ok_high = check_point(model, w_ref, M_high, t_stop, steady_window, speed_tol, dw_tol);

    if ok_high
        % Если даже верхнюю границу держит, то максимум не найден в диапазоне
        M_found = M_high;
        fprintf('  Найденный момент: %.2f Н*м (упёрлись в верхнюю границу поиска)\n', M_found);
        M_max_vec(i) = M_found;
        continue;
    end

    % -------------------------
    % Проверим нижнюю границу
    % -------------------------
    ok_low = check_point(model, w_ref, M_low, t_stop, steady_window, speed_tol, dw_tol);

    if ~ok_low
        % Если даже нулевую нагрузку не удерживает
        M_found = 0;
        fprintf('  Найденный момент: %.2f Н*м (даже нижняя граница не удерживается)\n', M_found);
        M_max_vec(i) = M_found;
        continue;
    end

    % -------------------------
    % Бинарный поиск
    % -------------------------
    for iter = 1:max_iter
        M_mid = 0.5 * (M_low + M_high);

        ok_mid = check_point(model, w_ref, M_mid, t_stop, steady_window, speed_tol, dw_tol);

        if ok_mid
            M_low = M_mid;   % момент ещё держится, можно поднимать
        else
            M_high = M_mid;  % уже не держится, уменьшаем
        end

        if (M_high - M_low) <= M_tol
            break;
        end
    end

    M_found = M_low;
    M_max_vec(i) = M_found;

    fprintf('  Найденный момент: %.2f Н*м\n', M_found);
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


%% ============================
% Локальная функция проверки точки
% ============================
function ok = check_point(model, w_ref, M_load, t_stop, steady_window, speed_tol, dw_tol)

    assignin('base', 'w_ref', w_ref);
    assignin('base', 'M_load', M_load);

    simOut = sim(model, ...
        'StopTime', num2str(t_stop), ...
        'ReturnWorkspaceOutputs', 'on');

    % Сигналы из To Workspace
    w_data = simOut.w;

    if ~isa(w_data, 'timeseries')
        error('simOut.w должен быть timeseries');
    end

    t = w_data.Time(:);
    w = w_data.Data(:);

    % Анализ конца переходного процесса
    idx0 = round((1 - steady_window) * numel(w));
    idx0 = max(idx0, 2);

    t_end = t(idx0:end);
    w_end_vec = w(idx0:end);

    w_end = mean(w_end_vec);

    % Оценка успокоенности по производной скорости
    dw = diff(w_end_vec) ./ diff(t_end);
    dw_end = mean(abs(dw));

    % Критерий удержания скорости
    speed_ok = abs(w_end - w_ref) <= speed_tol;
    steady_ok = dw_end <= dw_tol;

    ok = speed_ok && steady_ok;
end