import wave
import math
import struct
import os

def generate_move_sound(filename):
    sample_rate = 44100
    duration = 0.12  # seconds
    num_samples = int(duration * sample_rate)
    
    # Frequency corresponding to a wooden tap
    freq = 280.0
    
    data = bytearray()
    for i in range(num_samples):
        t = i / sample_rate
        # Quick exponential decay for wood tap
        env = math.exp(-35 * t)
        
        # Sound waveform: fundamental plus subtle octave overtone
        val = math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(2 * math.pi * 2 * freq * t)
        val = val / 1.25
        
        sample = int(val * env * 28000) # Soft, clean volume
        data.extend(struct.pack('<h', sample))
        
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(data)

def generate_capture_sound(filename):
    sample_rate = 44100
    duration = 0.12  # seconds
    num_samples = int(duration * sample_rate)
    
    # Sharp capture tap: higher pitch and faster decay
    freq1 = 440.0
    freq2 = 1000.0
    
    data = bytearray()
    for i in range(num_samples):
        t = i / sample_rate
        
        env1 = math.exp(-40 * t)
        env2 = math.exp(-150 * t) # Sharp snap click
        
        val = (math.sin(2 * math.pi * freq1 * t) * env1) + (0.5 * math.sin(2 * math.pi * freq2 * t) * env2)
        val = val / 1.5
        
        sample = int(val * 28000)
        data.extend(struct.pack('<h', sample))
        
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(data)

if __name__ == '__main__':
    sound_dir = 'assets/sounds'
    generate_move_sound(os.path.join(sound_dir, 'move.wav'))
    generate_capture_sound(os.path.join(sound_dir, 'capture.wav'))
    print("Sound assets successfully generated in assets/sounds/.")
