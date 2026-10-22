% Auto-exported from PathGaitFeatureExtraction.mlx (code cells only).

%% Automatización de Procesamiento Biomecánico
clear; clc;

% 1. Configuración de rutas
rutas = { ...
    '<project_root>\PathologicalGait\Normal', ...
    '<project_root>\PathologicalGait\Steppage' ...
};
clases = {'Normal', 'Steppage'};

% 2. Parámetros de procesamiento
fs_obj = 30; % Frecuencia objetivo
fc = 6;      % Corte filtro pasa-bajas
[b, a] = butter(2, fc/(fs_obj/2), 'low');

tablaMaestra = table(); % Contenedor final
fprintf('Iniciando procesamiento de archivos...\n');

% --- SOLUCIÓN: Generar los nombres de las variables ANTES del bucle ---
nombres_features = cell(1, 75 * 5);
idx = 1;
for s = 1:75
    prefix = sprintf('Var%d', s);
    nombres_features{idx}   = [prefix, '_Max'];
    nombres_features{idx+1} = [prefix, '_Min'];
    nombres_features{idx+2} = [prefix, '_ROM'];
    nombres_features{idx+3} = [prefix, '_Mean'];
    nombres_features{idx+4} = [prefix, '_Std'];
    idx = idx + 5;
end

% 3. Bucle principal por clase (Normal / Steppage)
for c = 1:length(rutas)
    basePath = rutas{c};
    claseActual = clases{c};
    
    % Buscar todos los archivos .csv en todas las subcarpetas
    archivos = dir(fullfile(basePath, '**', '*.csv'));
    fprintf('Procesando %d archivos de tipo: %s\n', length(archivos), claseActual);
    
    for f = 1:length(archivos)
        nombreArchivo = archivos(f).name;
        rutaCompleta = fullfile(archivos(f).folder, nombreArchivo);
        
        % --- PASO 1: LECTURA Y REPARACIÓN DEL CSV ---
        opts = detectImportOptions(rutaCompleta);
        opts.VariableNamingRule = 'preserve';
        rawTable = readtable(rutaCompleta, opts);
        
        if size(rawTable, 2) < 10
            strData = fileread(rutaCompleta);
            dataMat = str2num(strData); 
        else
            dataMat = table2array(rawTable);
        end
        
        % --- PASO 2: SELECCIÓN DE VARIABLES (75 ejes) ---
        t_orig = dataMat(:, 1) - dataMat(1, 1);
        indices_xyz = [];
        for j = 0:24
            base_col = 3 + (j*4);
            indices_xyz = [indices_xyz, base_col:base_col+2];
        end
        senales_crudas = dataMat(:, indices_xyz); % 75 columnas
        
        % =========================================================
        % --- ¡NUEVO!: SOLUCIÓN AL ERROR DE TIEMPOS DUPLICADOS ---
        % 'stable' mantiene el orden original del tiempo
        [t_orig, idx_unique] = unique(t_orig, 'stable'); 
        
        % Filtramos la matriz de señales para que coincida
        senales_crudas = senales_crudas(idx_unique, :); 
        % =========================================================
        
        % --- PASO 3: VALIDACIÓN, INTERPOLACIÓN Y FILTRADO ---
        % Validación: Si el archivo es demasiado corto (menos de 10 frames) o tiempo corrupto
        if length(t_orig) < 10 || t_orig(end) <= 0
            fprintf('   -> Advertencia: Archivo muy corto o corrupto. Asignando NaNs: %s\n', nombreArchivo);
            fila_features = NaN(1, 375); % Llenar con NaNs para no romper la tabla
        else
            t_uni = 0 : (1/fs_obj) : t_orig(end);
            
            % Pre-asignar espacio para la fila (más rápido)
            fila_features = zeros(1, 375); 
            idx_feature = 1;
            
            for s = 1:75
                % Interpolar
                sig_interp = interp1(t_orig, senales_crudas(:, s), t_uni, 'spline');
                
                % Filtrar (filtfilt exige que la señal sea más larga que el filtro)
                if length(sig_interp) > 10
                    sig_filt = filtfilt(b, a, sig_interp);
                else
                    sig_filt = sig_interp; % Si es muy corta, se deja sin filtrar
                end
                
                % --- PASO 4: FEATURE EXTRACTION A PRUEBA DE ERRORES ---
                % Usamos (:) para forzar a que sean cálculos de un solo valor escalar
                f_max = max(sig_filt(:));
                f_min = min(sig_filt(:));
                f_rom = f_max - f_min;
                f_mean = mean(sig_filt(:), 'omitnan');
                f_std = std(sig_filt(:), 'omitnan');
                
                % Si por alguna razón los cálculos devuelven vacío, forzamos a que sea NaN
                if isempty(f_max)
                    f_max = NaN; f_min = NaN; f_rom = NaN; f_mean = NaN; f_std = NaN; 
                end
                
                fila_features(idx_feature:idx_feature+4) = [f_max, f_min, f_rom, f_mean, f_std];
                idx_feature = idx_feature + 5;
            end
        end
        
        % --- PASO 5: METADATOS Y CONSOLIDACIÓN ---
        tokens = regexp(nombreArchivo, 'human(\d+)_.*(\d+)_SkeletonData(\d+)', 'tokens');
        if ~isempty(tokens)
            SujetoID = str2double(tokens{1}{1});
            MedicionID = str2double(tokens{1}{2});
            RepeticionID = str2double(tokens{1}{3});
        else
            SujetoID=0; MedicionID=0; RepeticionID=0;
        end
        
        % --- SOLUCIÓN: Asignar los nombres al crear la tabla temporal ---
        resTmp = array2table(fila_features, 'VariableNames', nombres_features);
        
        % Añadir metadatos
        resTmp.Clase = string(claseActual);
        resTmp.SujetoID = SujetoID;
        resTmp.MedicionID = MedicionID;
        resTmp.RepeticionID = RepeticionID;
        
        % Acumular en la tabla maestra
        tablaMaestra = [tablaMaestra; resTmp];
    end
end

% Guardar resultado para el Random Forest
save('Dataset_Marcha_Procesado.mat', 'tablaMaestra');
fprintf('¡Proceso completado! Tabla generada con %d filas.\n', size(tablaMaestra, 1));
