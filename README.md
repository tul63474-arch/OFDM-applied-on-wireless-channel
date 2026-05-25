# OFDM-applied-on-wireless-channel
A system using OFDM method (BPSK) to transmit signal on wireless channel
The system is divides into 6 progresses/stages
Stage 1: Read input audio file (in .wav or .mp3), quantization it in 8-bit intergers and turning it into binarry bits
Stage 2: Modulate the bits into BPSK symbols and insert pilot symbols
Stage 3: Convert Serial data to Parallel (S/P), applies IFFT to move the signal to the time domain, and adds a Cyclic Prefix (CP) to prevent ISI (Inter-Symbol Interference).
Stage 4: Simulates a real-world environment by adding Multipath Fading (signal distortion) and AWGN (background noise).
Stage 5: Receiver Side: Removes CP, applies FFT, estimates the channel using Pilot symbols.
Stage 6: Demodulates BPSK symbols back to bits, recovers the audio data, uses a Median Filter to remove click noise, and calculates the Bit Error Rate (BER).
