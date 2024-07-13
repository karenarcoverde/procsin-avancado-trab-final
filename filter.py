import numpy as np
import matplotlib.pyplot as plt
from scipy.io import wavfile
from scipy.signal import wiener, spectrogram

# Função para normalizar o sinal
def normalize_signal(signal):
    return signal / np.max(np.abs(signal))

# Função para converter estéreo para mono
def stereo_to_mono(signal):
    if signal.ndim == 2:
        return signal.mean(axis=1)
    return signal

# Função para plotar o espectrograma
def plot_spectrogram(signal, fs, title):
    f, t, Sxx = spectrogram(signal, fs, window="hann", nperseg=4096, noverlap=3072)
    plt.pcolormesh(t, f, 10 * np.log10(Sxx), shading='gouraud')
    plt.ylabel('Frequência [Hz]')
    plt.ylim([0, 2000])
    plt.xlabel('Tempo [s]')
    #plt.xlim([10, 15])
    plt.title(title)
    plt.colorbar(label='Intensidade [dB]')

# Carregar sinal de voz (arquivo WAV)
fs_voz, sinal_voz = wavfile.read('Dubal-fala.wav')
sinal_voz = stereo_to_mono(sinal_voz)
sinal_voz = normalize_signal(sinal_voz)

# Carregar ruído de avião (arquivo WAV)
fs_ruido, ruido_aviao = wavfile.read('ruido_aviao.wav')
ruido_aviao = stereo_to_mono(ruido_aviao)
ruido_aviao = normalize_signal(ruido_aviao)

# Certificar-se de que ambos os sinais têm o mesmo comprimento
min_len = min(len(sinal_voz), len(ruido_aviao))
sinal_voz = sinal_voz[:min_len]
ruido_aviao = np.divide(ruido_aviao[:min_len], 8)

# Sinal de voz com ruído
sinal_voz_ruido = sinal_voz + ruido_aviao
sinal_voz_ruido = normalize_signal(sinal_voz_ruido)

# Salvar sinal com ruído
wavfile.write("sinal_contaminado.wav", fs_voz, sinal_voz_ruido)

# Aplicar filtro de Wiener
sinal_limpo = wiener(sinal_voz_ruido, 164)

# Salvar sinal limpo
wavfile.write("sinal_limpo.wav", fs_voz, sinal_limpo)

# Plotar os sinais e seus espectrogramas
plt.figure(figsize=(12, 12))

plt.subplot(3, 2, 1)
plt.plot(sinal_voz, color='blue')
plt.title('Sinal de voz')
plt.xlabel('Amostras')
plt.ylabel('Amplitude')

plt.subplot(3, 2, 2)
plot_spectrogram(sinal_voz, fs_voz, 'Espectrograma do sinal de voz')

plt.subplot(3, 2, 3)
plt.plot(sinal_voz_ruido, color='black')
plt.title('Sinal de voz + ruído')
plt.xlabel('Amostras')
plt.ylabel('Amplitude')

plt.subplot(3, 2, 4)
plot_spectrogram(sinal_voz_ruido, fs_voz, 'Espectrograma do sinal de voz + ruído')

plt.subplot(3, 2, 5)
plt.plot(sinal_limpo, color='red')
plt.title('Sinal limpo')
plt.xlabel('Amostras')
plt.ylabel('Amplitude')

plt.subplot(3, 2, 6)
plot_spectrogram(sinal_limpo, fs_voz, 'Espectrograma do sinal limpo')

plt.tight_layout()
plt.show()