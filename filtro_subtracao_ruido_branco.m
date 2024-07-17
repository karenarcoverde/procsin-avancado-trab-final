% Carregar o sinal de áudio puro
[sinal_puro, fs] = audioread('Dubal-fala.wav');  % Sinal de voz puro

% Definir nova taxa de amostragem desejada
nova_fs = 48000;

% Aumentar a taxa de amostragem do sinal de entrada
sinal_puro = resample(sinal_puro, nova_fs, fs);
fs_antiga = fs; 
fs = nova_fs;  % Atualizar taxa de amostragem


ruido_puro = 0.05 * randn(1, length(sinal_puro));  % Ruído branco gaussiano com amplitude ajustada

% Ajustar os sinais para terem o mesmo comprimento
min_comprimento = min(length(sinal_puro), length(ruido_puro));
sinal_puro = sinal_puro(1:min_comprimento);
ruido_puro = ruido_puro(1:min_comprimento);

% Gerar sinal de voz com ruído
sinal_com_ruido = sinal_puro + ruido_puro;

% Salvar o sinal contaminado com ruido 
audiowrite('sinal_contaminado_ruido_branco.wav', sinal_com_ruido, fs);

% Parâmetros da janela
tamanho_quadro = 26;           % Tamanho do quadro (número de amostras)
sobreposicao = tamanho_quadro / 2;  % Sobreposição entre os quadros
janela = hamming(tamanho_quadro);   % Janela de Hamming

% Função para calcular o espectro de potência
espectro_potencia = @(x) abs(fft(x .* janela)).^2;

% Estimação do ruído
num_quadros = ceil((length(sinal_com_ruido) - sobreposicao) / (tamanho_quadro - sobreposicao));
espectro_ruido = zeros(tamanho_quadro, 1);

% Parâmetros para estimação do ruído
alpha1 = 0.95;  % Parâmetro para atualização rápida
alpha2 = 0.9;   % Parâmetro para atualização lenta

for n = 0:num_quadros-1
    inicio_idx = n * (tamanho_quadro - sobreposicao) + 1;
    fim_idx = min(inicio_idx + tamanho_quadro - 1, length(sinal_com_ruido));

    % Extrair o quadro atual do sinal ruidoso
    quadro = sinal_com_ruido(inicio_idx:fim_idx);

    % Se o quadro for menor que o tamanho da janela, completar com zeros
    if length(quadro) < tamanho_quadro
        quadro = [quadro, zeros(1, tamanho_quadro - length(quadro))];
    end

    % Calcular o espectro de potência do quadro atual
    espectro_ruidoso = espectro_potencia(quadro);

    % Média cumulativa do espectro de potência do ruído
    if n == 0
        espectro_ruido = espectro_ruidoso;
    else
        % Atualização do espectro de ruído com parâmetros alpha1 e alpha2
        for k = 1:tamanho_quadro
            if espectro_ruidoso(k) >= espectro_ruido(k)
                espectro_ruido(k) = alpha1 * espectro_ruido(k) + (1 - alpha1) * espectro_ruidoso(k);
            else
                espectro_ruido(k) = alpha2 * espectro_ruido(k) + (1 - alpha2) * espectro_ruidoso(k);
            end
        end
    end
end

% Inicializar o sinal de saída e contador
sinal_limpo = zeros(1, length(sinal_com_ruido));
contador = zeros(1, length(sinal_com_ruido));

% Processamento em blocos (frame-by-frame)
for n = 0:num_quadros-1
    inicio_idx = n * (tamanho_quadro - sobreposicao) + 1;
    fim_idx = min(inicio_idx + tamanho_quadro - 1, length(sinal_com_ruido));

    % Extrair o quadro atual do sinal ruidoso
    quadro = sinal_com_ruido(inicio_idx:fim_idx);

    % Se o quadro for menor que o tamanho da janela, completar com zeros
    if length(quadro) < tamanho_quadro
        quadro = [quadro, zeros(1, tamanho_quadro - length(quadro))];
    end

    % Calcular o espectro de potência do quadro atual
    espectro_ruidoso = espectro_potencia(quadro);

    % Subtração espectral
    espectro_subtraido = max(espectro_ruidoso - espectro_ruido, 0);

    % Recuperar a magnitude do espectro de voz
    magnitude_espectro = sqrt(espectro_subtraido);

    % Manter a fase do sinal ruidoso
    fft_ruidoso = fft(quadro .* janela);
    fase = angle(fft_ruidoso);
    fft_reconstruida = magnitude_espectro .* exp(1j * fase);

    % Transformada inversa de Fourier
    quadro_reconstruido = real(ifft(fft_reconstruida));

    % Se o quadro for menor que o tamanho da janela, truncar os zeros adicionados
    quadro_reconstruido = quadro_reconstruido(1:length(quadro));
    
    % Overlap-add para construir o sinal de saída
     % Verifica se os índices são válidos e se as dimensões coincidem
    tamanho = fim_idx - inicio_idx + 1;
    if tamanho > length(quadro_reconstruido)
        quadro_reconstruido = [quadro_reconstruido, zeros(1, tamanho - length(quadro_reconstruido))];
    else
        quadro_reconstruido = quadro_reconstruido(1:tamanho);
    end
    sinal_limpo(inicio_idx:fim_idx) = sinal_limpo(inicio_idx:fim_idx) + quadro_reconstruido(1:tamanho);
    %sinal_limpo(inicio_idx:fim_idx) = sinal_limpo(inicio_idx:fim_idx) + quadro_reconstruido(1, length(quadro_reconstruido));
    contador(inicio_idx:fim_idx) = contador(inicio_idx:fim_idx) + 1;
end

% Normalizar pelo contador para evitar divisão por zero
contador(contador == 0) = 1;
sinal_limpo = sinal_limpo ./ contador;

% Normalizar o sinal de saída
sinal_limpo = sinal_limpo / max(abs(sinal_limpo));


% Retomando para a taxa de amostragem antiga
ruido_puro = resample(ruido_puro, fs_antiga, fs);
sinal_puro = resample(sinal_puro, fs_antiga, fs);
sinal_limpo = resample(sinal_limpo, fs_antiga, fs);

% Salvar o sinal de saída (opcional)
audiowrite('sinal_limpo_ruido_branco.wav', sinal_limpo, fs_antiga);

% Plotar os sinais e seus espectrogramas para comparação
t = (0:length(sinal_com_ruido)-1) / fs;

figure;
subplot(4,2,1);
plot(t, sinal_puro(1:length(sinal_com_ruido)));
title('Sinal de voz puro');
xlabel('Tempo (s)');
ylabel('Amplitude');

subplot(4,2,2);
spectrogram(sinal_puro(1:length(sinal_com_ruido)), janela, sobreposicao, tamanho_quadro, fs, 'yaxis');
title('Espectrograma do sinal de voz puro');

subplot(4,2,3);
plot(t, ruido_puro(1:length(sinal_com_ruido)));
title('Ruído branco');
xlabel('Tempo (s)');
ylabel('Amplitude');

subplot(4,2,4);
spectrogram(ruido_puro(1:length(ruido_puro)), janela, sobreposicao, tamanho_quadro, fs, 'yaxis');
title('Espectrograma do ruído branco');

subplot(4,2,5);
plot(t, sinal_com_ruido);
title('Sinal de voz com ruído');
xlabel('Tempo (s)');
ylabel('Amplitude');


subplot(4,2,6);
spectrogram(sinal_com_ruido, janela, sobreposicao, tamanho_quadro, fs, 'yaxis');
title('Espectrograma do sinal de voz com ruído');

subplot(4,2,7);
plot(t, sinal_limpo(1:length(ruido_puro)));
title('Sinal de voz limpo');
xlabel('Tempo (s)');
ylabel('Amplitude');

subplot(4,2,8);
spectrogram(sinal_limpo(1:length(sinal_com_ruido)), janela, sobreposicao, tamanho_quadro, fs, 'yaxis');
title('Espectrograma do sinal de voz limpo');


