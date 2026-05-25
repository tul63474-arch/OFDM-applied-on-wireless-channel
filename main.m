clear all; close all; clc;

%% [Khối 1 & 2] DATA INPUT & QUANTIZATION (8-BIT)
[audio_tx, Fs] = audioread('input2.m4a');
audio_tx = audio_tx(:, 1); 
audio_scaled = round((audio_tx + 1) * 127.5);
audio_scaled(audio_scaled > 255) = 255; audio_scaled(audio_scaled < 0) = 0;
tx_bits = reshape(dec2bin(audio_scaled, 8)' - '0', [], 1);
L_bits = length(tx_bits);

%% [Khối 3 & 4] MODULATION (BPSK) & PILOT INSERTION
tx_symbols = tx_bits * 2 - 1; 
N_fft = 64; N_cp = 16; pilot_idx = [12, 26, 40, 54];
data_idx = setdiff(1:N_fft, pilot_idx); N_data = length(data_idx);

N_ofdm = ceil(length(tx_symbols) / N_data);
tx_sym_pad = [tx_symbols; zeros(N_ofdm * N_data - length(tx_symbols), 1)];

total_sym_flat = zeros(N_ofdm * N_fft, 1);
for s = 1:N_ofdm
    total_sym_flat((s-1)*N_fft + data_idx) = tx_sym_pad((s-1)*N_data + (1:N_data));
    total_sym_flat((s-1)*N_fft + pilot_idx) = 1; 
end

%% [Khối 5 -> 9] S/P -> IFFT -> INSERT CP -> P/S -> DAC
ofdm_freq_mat = reshape(total_sym_flat, N_fft, N_ofdm)'; 
ofdm_time_no_cp = ifft(ofdm_freq_mat, N_fft, 2);         
ofdm_time_cp = [ofdm_time_no_cp(:, N_fft-N_cp+1:end), ofdm_time_no_cp]; 
tx_signal = reshape(ofdm_time_cp', [], 1); 

%% [Khối 10 -> 12] MÔ PHỎNG KÊNH THỰC TẾ
h_channel = [1, 0.5, 0.3]; % Tăng độ méo đa đường
rx_sig_fading = filter(h_channel, 1, tx_signal); 

% Đặt SNR = 7 dB (Môi trường thực tế)
snr_real = 7; 
noise = sqrt((mean(abs(rx_sig_fading).^2) / 10^(snr_real/10)) / 2) * (randn(size(rx_sig_fading)) + 1i*randn(size(rx_sig_fading)));
rx_signal = rx_sig_fading + noise; 

%% [Khối 13 -> 16] S/P -> REMOVE CP -> FFT
rx_mat_cp = reshape(rx_signal(1:N_ofdm*(N_fft+N_cp)), N_fft+N_cp, N_ofdm)'; 
rx_mat_no_cp = rx_mat_cp(:, N_cp+1:end); 
rx_freq_mat = fft(rx_mat_no_cp, N_fft, 2); 

%% [Khối 17 & 18] ƯỚC LƯỢNG KÊNH THỰC TẾ (CÓ SAI SỐ DO NHIỄU ĐÈ VÀO PILOT)
% Máy thu lấy Pilot ra, nhưng bản thân Pilot này đã bị nhiễu làm méo
H_pilot = rx_freq_mat(:, pilot_idx) ./ 1; 
H_est = zeros(N_ofdm, N_fft);
for s = 1:N_ofdm
    H_est(s, :) = interp1(pilot_idx, H_pilot(s, :), 1:N_fft, 'linear', 'extrap');
end

% Cân bằng kênh Zero Forcing dựa trên thông tin kênh bị nhiễu
rx_freq_eq = rx_freq_mat ./ H_est; 
rx_sym_mat_ext = rx_freq_eq(:, data_idx);
rx_sym_vec = reshape(rx_sym_mat_ext', [], 1);
rx_sym_vec = rx_sym_vec(1:length(tx_sym_pad));

%% [Khối 19] DEMODULATION (BPSK) & RECOVER AUDIO
rx_bits = double(real(rx_sym_vec) > 0); 
rx_bits = rx_bits(1:L_bits);
rx_bits_mat = reshape(char(rx_bits + '0'), 8, [])';
audio_rx = (bin2dec(rx_bits_mat) / 127.5) - 1;
% ĐỒNG BỘ ĐỘ DÀI
N_samples_orig = length(audio_tx);
audio_rx = audio_rx(1:min(N_samples_orig, length(audio_rx)));
L_min = length(audio_rx);
% Bộ lọc trung vị bậc 5 hoặc 7 sẽ loại bỏ các điểm nhảy biên độ do lỗi bit
audio_rx_filtered = medfilt1(audio_rx, 5); 

ber_real = sum(tx_bits(1:L_bits) ~= rx_bits) / L_bits;
audiowrite('result.wav', audio_rx_filtered, Fs); % Ghi file đã lọc nhiễu

%% === ĐỒ THỊ KẾT QUẢ ===
figure('Position', [50, 50, 1100, 550], 'Name', 'Real OFDM System Progress (Non-Zero BER)');

% 1. Đồ thị Sóng Phát (Tx)
subplot(2, 2, 1); plot((0:L_min-1)/Fs, audio_tx(1:L_min), 'b', 'LineWidth', 1); grid on;
title('1. Binary Data Input -> Modulation (Tx)'); xlabel('Thoi gian (s)'); ylabel('Bien do'); ylim([-1.1 1.1]);

% 2. Đồ thị Sóng Thu (Rx) - Sửa lỗi lệch hướng ma trận hàng/cột
subplot(2, 2, 3); 

% Sử dụng toán tử (:) để ép cả X và Y chắc chắn thành vector cột 1 chiều
time_axis = ((0:L_min-1)/Fs)'; 
y_signal = audio_rx_filtered(:); % Sử dụng audio_rx_filtered đã lọc ở bước trước

plot(time_axis, y_signal, 'r', 'LineWidth', 1); 
grid on;

title(['2. Demodulation -> Received Signal | BER = ' num2str(ber_real)]); 
xlabel('Thoi gian (s)'); ylabel('Bien do'); 
ylim([-1.1 1.1]);
% 3. Đồ thị BER và mốc thực tế
subplot(2, 2, [2, 4]); 
EbNo_axis = 0:2:14;
BER_theoretical = 0.5 * erfc(sqrt(10.^(EbNo_axis/10))); 

semilogy(EbNo_axis, BER_theoretical, 'b-x', 'LineWidth', 1.5); hold on;
semilogy(snr_real, ber_real, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r'); 
grid on;
title('3. Performance Analysis: BER vs Eb/No');
xlabel('Eb/No (dB)'); ylabel('Ty le loi bit (BER)');
legend('OFDM BPSK Theoretical', ['Real Simulation Point (' num2str(snr_real) 'dB)'], 'Location', 'SouthWest');
ylim([1e-4 1]);
