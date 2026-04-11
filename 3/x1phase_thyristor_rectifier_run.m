%% Анализ токов из модели x1phase_thyristor_rectifier
clear; clc;

model = 'x1phase_thyristor_rectifier';

% Запуск модели
simOut = sim(model);

% Если outputs сохранены в объекте out
out = simOut;

% Период сети 50 Гц
T = 0.02;   % c

% Имена сигналов и подписи
signalNames = {'i_1','i_2','i_3','i_4'};
signalLabels = { ...
    'alpha = 0 deg, R', ...
    'alpha = 60 deg, R', ...
    'alpha = 0 deg, R-L', ...
    'alpha = 60 deg, R-L'};

fprintf('\n=== Результаты для модели %s ===\n\n', model);

results = struct();

for k = 1:numel(signalNames)
    name  = signalNames{k};
    label = signalLabels{k};

    % Достаём сигнал
    sig = out.(name);

    % Обработка нескольких возможных форматов
    if isa(sig, 'timeseries')
        t = sig.Time;
        i = sig.Data;
    elseif isstruct(sig) && isfield(sig, 'time') && isfield(sig, 'signals')
        t = sig.time;
        i = sig.signals.values;
    else
        error('Неизвестный формат сигнала "%s".', name);
    end

    % Вектор-столбец
    t = t(:);
    i = i(:);

    % Берём последний период для установившегося режима
    t2 = t(end);
    t1 = t2 - T;
    idx = (t >= t1) & (t <= t2);

    if nnz(idx) < 2
        error('Для сигнала "%s" слишком мало точек на последнем периоде.', name);
    end

    t_last = t(idx);
    i_last = i(idx);

    % Среднее по времени
    Iavg = trapz(t_last, i_last) / (t_last(end) - t_last(1));

    % Обычные экстремумы
    Imin = min(i_last);
    Imax = max(i_last);
    dI_pp = Imax - Imin;   % полный размах, чувствителен к выбросам

    % Переменная составляющая
    i_ac = i_last - Iavg;

    % RMS тока
    Irms = sqrt(trapz(t_last, i_last.^2) / (t_last(end) - t_last(1)));

    % RMS пульсации (переменной составляющей)
    Iripple_rms = sqrt(trapz(t_last, i_ac.^2) / (t_last(end) - t_last(1)));

    % Устойчивый размах без влияния узких выбросов: 1% ... 99%
    i_sorted = sort(i_last);
    n = numel(i_sorted);
    idx01 = max(1, round(0.01 * n));
    idx99 = min(n, round(0.99 * n));
    I01 = i_sorted(idx01);
    I99 = i_sorted(idx99);
    dI_robust = I99 - I01;

    % Сохраняем
    results.(name).label        = label;
    results.(name).Iavg         = Iavg;
    results.(name).Imin         = Imin;
    results.(name).Imax         = Imax;
    results.(name).dI_pp        = dI_pp;
    results.(name).dI_robust    = dI_robust;
    results.(name).Iripple_rms  = Iripple_rms;
    results.(name).Irms         = Irms;

    % Вывод
    fprintf('%s (%s)\n', name, label);
    fprintf('  I_avg         = %.6f A\n', Iavg);
    fprintf('  I_min         = %.6f A\n', Imin);
    fprintf('  I_max         = %.6f A\n', Imax);
    fprintf('  Delta I_pp    = %.6f A\n', dI_pp);
    fprintf('  Delta I_1_99  = %.6f A\n', dI_robust);
    fprintf('  I_ripple_rms  = %.6f A\n', Iripple_rms);
    fprintf('  I_rms         = %.6f A\n\n', Irms);
end

%% Сводная таблица
labels        = strings(numel(signalNames),1);
Iavg_all      = zeros(numel(signalNames),1);
Imin_all      = zeros(numel(signalNames),1);
Imax_all      = zeros(numel(signalNames),1);
dIpp_all      = zeros(numel(signalNames),1);
dIrob_all     = zeros(numel(signalNames),1);
Iripple_all   = zeros(numel(signalNames),1);
Irms_all      = zeros(numel(signalNames),1);

for k = 1:numel(signalNames)
    name = signalNames{k};
    labels(k)      = results.(name).label;
    Iavg_all(k)    = results.(name).Iavg;
    Imin_all(k)    = results.(name).Imin;
    Imax_all(k)    = results.(name).Imax;
    dIpp_all(k)    = results.(name).dI_pp;
    dIrob_all(k)   = results.(name).dI_robust;
    Iripple_all(k) = results.(name).Iripple_rms;
    Irms_all(k)    = results.(name).Irms;
end

T_results = table(labels, Iavg_all, Imin_all, Imax_all, dIpp_all, dIrob_all, Iripple_all, Irms_all, ...
    'VariableNames', {'Case','I_avg_A','I_min_A','I_max_A','Delta_I_pp_A','Delta_I_1_99_A','I_ripple_rms_A','I_rms_A'});

disp('=== Сводная таблица ===');
disp(T_results);

%% Короткое сравнение R и R-L
fprintf('\n=== Сравнение случаев R и R-L ===\n\n');

fprintf('alpha = 0 deg:\n');
fprintf('  I_avg:       R = %.6f A,   R-L = %.6f A\n', results.i_1.Iavg, results.i_3.Iavg);
fprintf('  Delta I_1_99 R = %.6f A,   R-L = %.6f A\n', results.i_1.dI_robust, results.i_3.dI_robust);
fprintf('  I_ripple_rms R = %.6f A,   R-L = %.6f A\n\n', results.i_1.Iripple_rms, results.i_3.Iripple_rms);

fprintf('alpha = 60 deg:\n');
fprintf('  I_avg:       R = %.6f A,   R-L = %.6f A\n', results.i_2.Iavg, results.i_4.Iavg);
fprintf('  Delta I_1_99 R = %.6f A,   R-L = %.6f A\n', results.i_2.dI_robust, results.i_4.dI_robust);
fprintf('  I_ripple_rms R = %.6f A,   R-L = %.6f A\n\n', results.i_2.Iripple_rms, results.i_4.Iripple_rms);