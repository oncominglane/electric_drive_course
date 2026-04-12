%% Анализ токов из модели task1_1phase_thyristor_rectifier
clear; clc;

model = 'task1_1phase_thyristor_rectifier';

% Запуск модели
simOut = sim(model);

% Для удобства
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

    % Переменная составляющая
    i_ac = i_last - Iavg;

    % RMS пульсации
    Iripple_rms = sqrt(trapz(t_last, i_ac.^2) / (t_last(end) - t_last(1)));

    % Сохраняем
    results.(name).label       = label;
    results.(name).Iavg        = Iavg;
    results.(name).Iripple_rms = Iripple_rms;

    % Вывод
    fprintf('%s (%s)\n', name, label);
    fprintf('  I_avg         = %.6f A\n', Iavg);
    fprintf('  I_ripple_rms  = %.6f A\n\n', Iripple_rms);
end

%% Сводная таблица
labels        = strings(numel(signalNames),1);
Iavg_all      = zeros(numel(signalNames),1);
Iripple_all   = zeros(numel(signalNames),1);

for k = 1:numel(signalNames)
    name = signalNames{k};
    labels(k)      = results.(name).label;
    Iavg_all(k)    = results.(name).Iavg;
    Iripple_all(k) = results.(name).Iripple_rms;
end

T_results = table(labels, Iavg_all, Iripple_all, ...
    'VariableNames', {'Case','I_avg_A','I_ripple_rms_A'});

disp('=== Сводная таблица ===');
disp(T_results);

%% Короткое сравнение R и R-L
fprintf('\n=== Сравнение случаев R и R-L ===\n\n');

fprintf('alpha = 0 deg:\n');
fprintf('  I_avg:       R = %.6f A,   R-L = %.6f A\n', results.i_1.Iavg, results.i_3.Iavg);
fprintf('  I_ripple_rms R = %.6f A,   R-L = %.6f A\n\n', results.i_1.Iripple_rms, results.i_3.Iripple_rms);

fprintf('alpha = 60 deg:\n');
fprintf('  I_avg:       R = %.6f A,   R-L = %.6f A\n', results.i_2.Iavg, results.i_4.Iavg);
fprintf('  I_ripple_rms R = %.6f A,   R-L = %.6f A\n\n', results.i_2.Iripple_rms, results.i_4.Iripple_rms);