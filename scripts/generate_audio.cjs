/* Original, deterministic audio for Slopyard Wars; preserves the recorded hinges.
 * Run: node scripts/generate_audio.cjs
 * PCM WAV, 44.1 kHz / 16 bit. Music and engine loops are periodic at the seam.
 */
const fs = require('node:fs');
const path = require('node:path');
const OUT = path.resolve(__dirname, '../assets/audio');
const RATE = 44100, TAU = 2 * Math.PI;
fs.mkdirSync(OUT, {recursive: true});
let seed = 0x51a0f01d;
function random() { seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5; return (seed >>> 0) / 4294967296; }
const noise = () => random() * 2 - 1;
const hz = note => 440 * 2 ** ((note - 69) / 12);
const sine = (f, t) => Math.sin(TAU * f * t);
const smooth = x => { x = Math.max(0, Math.min(1, x)); return x * x * (3 - 2 * x); };
const manifest = [];

function write(name, left, right = null, loop = false) {
  const channels = right ? 2 : 1, frames = left.length;
  let peak = 0, sum = 0, renderedPeak = 0;
  for (let i = 0; i < frames; i++) peak = Math.max(peak, Math.abs(left[i]), right ? Math.abs(right[i]) : 0);
  const gain = 0.72 / Math.max(peak, 0.000001);
  const pcm = Buffer.alloc(frames * channels * 2);
  for (let i = 0; i < frames; i++) {
    const fade = loop ? 1 : Math.min(1, i / (RATE * 0.001), (frames - 1 - i) / (RATE * 0.012));
    for (let channel = 0; channel < channels; channel++) {
      const value = (channel ? right[i] : left[i]) * gain * fade;
      renderedPeak = Math.max(renderedPeak, Math.abs(value));
      sum += value * value;
      pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, value)) * 32767), (i * channels + channel) * 2);
    }
  }
  const header = Buffer.alloc(44);
  header.write('RIFF'); header.writeUInt32LE(36 + pcm.length, 4); header.write('WAVEfmt ', 8);
  header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(RATE, 24); header.writeUInt32LE(RATE * channels * 2, 28);
  header.writeUInt16LE(channels * 2, 32); header.writeUInt16LE(16, 34); header.write('data', 36);
  header.writeUInt32LE(pcm.length, 40);
  fs.writeFileSync(path.join(OUT, name + '.wav'), Buffer.concat([header, pcm]));
  manifest.push({file: name + '.wav', seconds: frames / RATE, channels, sample_rate: RATE, loop,
    peak_db: Math.round(200 * Math.log10(renderedPeak)) / 10,
    rms_db: Math.round(200 * Math.log10(Math.sqrt(sum / (frames * channels)))) / 10});
}
function effect(name, duration, sample, loop = false) {
  const audio = new Float32Array(Math.round(duration * RATE));
  for (let i = 0; i < audio.length; i++) audio[i] = sample(i / RATE, i / audio.length, i);
  write(name, audio, null, loop);
}
function chime(name, notes, spacing, duration) {
  effect(name, duration, t => notes.reduce((sum, note, index) => {
    const x = t - index * spacing;
    return x < 0 ? sum : sum + smooth(x / 0.006) * Math.exp(-x * 5) *
      (sine(hz(note), x) + 0.2 * sine(hz(note) * 2.005, x) * Math.exp(-x * 7));
  }, 0));
}

effect('ui_click', 0.075, t => Math.exp(-t * 75) * (0.6 * sine(1250, t) + 0.4 * noise()));
effect('feedback', 0.22, t => smooth(t / 0.005) * Math.exp(-t * 18) *
  (sine(t < 0.075 ? 280 : 220, t) + 0.15 * sine(440, t)));
effect('screen_crack', 0.64, t => {
  let value = 0.18 * sine(145, t) * Math.exp(-t * 15);
  const fractures = [0, 0.012, 0.031, 0.058, 0.091, 0.146, 0.21, 0.31];
  fractures.forEach((start, index) => {
    const x = t - start;
    if (x >= 0) value += (1 - index * 0.085) * Math.exp(-x * (60 + index * 9)) *
      (noise() * 0.9 + 0.23 * sine(2150 + index * 571, x) + 0.14 * sine(4900 + index * 233, x));
  });
  return value;
});
// Preserve the random-stream position so replacing the hinges does not change
// any existing music or other effects. The recordings are never overwritten.
for (let i = 0; i < 2 * Math.round(1.15 * RATE); i++) noise();
for (const name of ['hinge_open', 'hinge_close']) manifest.push(recordedHinge(name));
for (const [name, upward] of [['phone_out', true], ['phone_away', false]]) {
  let air = 0;
  effect(name, 0.25, (t, x) => {
    air = air * 0.89 + noise() * 0.11;
    return air * Math.sin(Math.PI * x) ** 1.6 + 0.06 * sine(upward ? 170 + 80 * x : 250 - 80 * x, t) * Math.sin(Math.PI * x);
  });
}
for (const [name, pitch] of [['step_a', 100], ['step_b', 118]]) {
  let low = 0;
  effect(name, 0.15, t => { low = low * 0.88 + noise() * 0.12;
    return (low + 0.12 * sine(pitch, t)) * Math.exp(-t * 35) + noise() * Math.exp(-t * 120) * 0.1; });
}
effect('door', 0.32, t => 0.4 * sine(115, t) * Math.exp(-t * 25) + noise() * Math.exp(-t * 45) +
  (t > 0.1 ? noise() * 0.15 * Math.exp(-(t - 0.1) * 45) : 0));
effect('snap', 0.11, t => (noise() + 0.3 * sine(1700, t)) * Math.exp(-t * 80));
effect('screw', 0.15, t => {
  const pulse = (t % 0.038);
  return (noise() * 0.7 + sine(1800, t) * 0.2) * Math.exp(-pulse * 180) * Math.exp(-t * 10);
});
effect('paste', 0.19, t => Math.exp(-t * 20) * (sine(135 + 100 * Math.exp(-t * 25), t) + noise() * 0.15));
effect('damage', 0.24, t => (noise() * 0.7 + 0.25 * sine(510, t)) * Math.exp(-t * 35));
effect('failure', 0.85, t => Math.exp(-t * 7) * (0.6 * noise() + 0.25 * sine(68, t)) +
  0.3 * Math.exp(-t * 4) * sine(460 * Math.exp(-t * 4), t));
effect('car_start', 0.7, t => smooth(t / 0.04) * Math.exp(-t * 3) *
  (sine(50, t) + 0.4 * sine(100, t) + 0.2 * Math.sin(TAU * 150 * t + 2 * Math.sin(t * 71)) + 0.1 * noise()));
effect('engine_loop', 0.8, t => (sine(50, t) + 0.3 * sine(100, t) + 0.12 * sine(150, t)) *
  (0.8 + 0.2 * sine(2.5, t)) + 0.06 * sine(425, t), true);
chime('message', [78, 85], 0.1, 0.55);
chime('send', [69, 76], 0.045, 0.28);
chime('cash', [85, 90, 97], 0.075, 0.68);
chime('activity', [74, 81, 86], 0.16, 1.25);
chime('success', [62, 66, 69], 0.065, 0.65);
chime('match_end', [62, 66, 69, 73, 76], 0.17, 1.8);

// Original 16-bar, 80 BPM downtempo arrangement: Rhodes-like keys, warm pads,
// rounded bass, soft brushed drums and a sparse pentatonic melody.
const BEAT = 60 / 80, BAR = BEAT * 4, LENGTH = 16 * BAR;
const N = Math.round(LENGTH * RATE), left = new Float32Array(N), right = new Float32Array(N);
function voice(at, duration, sample, gain, pan = 0) {
  const offset = Math.round(at * RATE), count = Math.round(duration * RATE);
  const l = Math.sqrt((1 - pan) / 2) * gain, r = Math.sqrt((1 + pan) / 2) * gain;
  for (let i = 0; i < count; i++) {
    const index = (offset + i + N) % N, value = sample(i / RATE, i / count);
    left[index] += value * l; right[index] += value * r;
  }
}
const chords = [[50, 57, 61, 64, 66], [47, 54, 57, 61, 62], [43, 54, 57, 59, 62], [45, 52, 54, 59, 61]];
const roots = [38, 35, 31, 33];
for (let bar = 0; bar < 16; bar++) {
  const at = bar * BAR, chord = chords[bar % 4];
  for (let k = 0; k < chord.length; k++) {
    const f = hz(chord[k]);
    voice(at, BAR + 1.4, (t, x) => smooth(t / 0.45) * smooth((1 - x) * 4) *
      (sine(f * 0.999, t) * 0.65 + sine(f * 1.001, t) * 0.25 + sine(f * 2, t) * 0.1), 0.065, (k - 2) * 0.22);
  }
  for (const [step, index] of [[0, 1], [1.55, 3], [2.5, 2], [3.5, 4]]) {
    const f = hz(chord[index] + 12);
    voice(at + step * BEAT + 0.012, 2.2, t => smooth(t / 0.004) * Math.exp(-t * 2.9) *
      Math.sin(TAU * f * t + 1.6 * Math.exp(-t * 6) * sine(f * 2, t)), 0.16, index % 2 ? -0.22 : 0.2);
  }
  for (const step of [0, 2.5]) {
    const f = hz(roots[bar % 4]);
    voice(at + step * BEAT, 1.25 * BEAT, (t, x) => smooth(t / 0.015) * smooth((1 - x) * 5) *
      (sine(f, t) + sine(f * 2, t) * 0.16), 0.2);
  }
  for (const step of [0, 2]) voice(at + step * BEAT, 0.24,
    t => sine(50, t + 0.018 * (1 - Math.exp(-t * 45))) * Math.exp(-t * 24), 0.19);
  for (const step of [1, 3]) {
    let low = 0;
    voice(at + step * BEAT + 0.015, 0.16, t => { const n = noise(); low = low * 0.5 + n * 0.5;
      return (low * 0.6 + sine(180, t) * 0.12) * Math.exp(-t * 30); }, 0.075, 0.12);
  }
  for (let step = 0; step < 8; step++) {
    let previous = 0;
    voice(at + step * BEAT / 2 + (step % 2 ? 0.025 : 0), 0.075, t => {
      const n = noise(), value = n - previous; previous = n; return value * Math.exp(-t * 90);
    }, step % 2 ? 0.012 : 0.017, step % 2 ? 0.35 : -0.3);
  }
  if (bar % 2 === 0) {
    const melody = [78, 76, 73, 76, 81, 78, 76, 73];
    const f = hz(melody[bar / 2]);
    voice(at + 2.75 * BEAT, 2.5, t => smooth(t / 0.02) * Math.exp(-t * 2.2) *
      (sine(f, t) + sine(f * 2.002, t) * 0.15), 0.07, Math.sin(bar) * 0.4);
  }
}
const dryL = left.slice(), dryR = right.slice();
for (let i = 0; i < N; i++) {
  for (const [delay, gain] of [[0.1875, 0.12], [0.375, 0.085], [0.612, 0.045]]) {
    const index = (i - Math.round(delay * RATE) + N) % N;
    left[i] += dryR[index] * gain; right[i] += dryL[index] * gain;
  }
  left[i] = Math.tanh(left[i] * 1.1); right[i] = Math.tanh(right[i] * 1.1);
}
write('slopyard_afterhours', left, right, true);
fs.writeFileSync(path.join(OUT, 'manifest.json'), JSON.stringify({generator: 'scripts/generate_audio.cjs', assets: manifest}, null, 2) + '\n');
console.log('Generated ' + (manifest.length - 2) + ' original WAV assets; preserved 2 recorded hinges; music loop: ' + LENGTH + ' seconds.');

function recordedHinge(name) {
  const wav = fs.readFileSync(path.join(OUT, name + '.wav'));
  let offset = 12, pcm, rate, channels;
  while (offset < wav.length - 8) {
    const tag = wav.toString('ascii', offset, offset + 4), size = wav.readUInt32LE(offset + 4);
    if (tag === 'fmt ') { channels = wav.readUInt16LE(offset + 10); rate = wav.readUInt32LE(offset + 12); }
    if (tag === 'data') pcm = wav.subarray(offset + 8, offset + 8 + size);
    offset += 8 + size + (size % 2);
  }
  let peak = 0, energy = 0;
  for (let i = 0; i < pcm.length; i += 2) {
    const value = pcm.readInt16LE(i) / 32768;
    peak = Math.max(peak, Math.abs(value)); energy += value * value;
  }
  return {file: name + '.wav', seconds: pcm.length / (channels * 2 * rate), channels,
    sample_rate: rate, loop: false, peak_db: Math.round(200 * Math.log10(peak)) / 10,
    rms_db: Math.round(200 * Math.log10(Math.sqrt(energy / (pcm.length / 2)))) / 10,
    origin: 'Recorded hinge, edited from chonkdonk / Freesound 619819', license: 'CC0-1.0',
    source_url: 'https://freesound.org/people/chonkdonk/sounds/619819/'};
}
