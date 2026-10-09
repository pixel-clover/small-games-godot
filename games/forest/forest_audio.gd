class_name ForestAudio
extends RefCounted

## Procedural ambient audio for the forest walk: wind, crickets, birdsong,
## owl, footsteps, a slow evolving pad and pentatonic plucks with echo.

const RATE := 22050


static func _to_stream(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
    var data := PackedByteArray()
    data.resize(samples.size() * 2)
    for i in samples.size():
        data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
    var s := AudioStreamWAV.new()
    s.format = AudioStreamWAV.FORMAT_16_BITS
    s.mix_rate = rate
    s.stereo = false
    s.data = data
    if loop:
        s.loop_mode = AudioStreamWAV.LOOP_FORWARD
        s.loop_begin = 0
        s.loop_end = samples.size()
    return s


static func _normalize(a: PackedFloat32Array, peak: float) -> void:
    var m := 0.0001
    for v in a:
        m = maxf(m, absf(v))
    for i in a.size():
        a[i] = a[i] / m * peak


static func wind(biome: int=0) -> AudioStreamWAV:
    var rng := RandomNumberGenerator.new()
    rng.seed = 700 + biome
    var n := RATE * 4
    var x := RATE / 2  # crossfade length for a seamless loop
    var raw := PackedFloat32Array()
    raw.resize(n + x)
    var lp1 := 0.0
    var lp2 := 0.0
    for i in n + x:
        lp1 += ((rng.randf() * 2.0 - 1.0) - lp1) * (0.04 + biome * 0.015)
        lp2 += (lp1 - lp2) * 0.07
        raw[i] = lp2
    var out := PackedFloat32Array()
    out.resize(n)
    for i in n:
        var v := raw[i]
        if i < x:
            var u := float(i) / x
            v = raw[i] * u + raw[n + i] * (1.0 - u)
        var m := 0.65 + 0.25 * sin(TAU * i / n) + 0.1 * sin(TAU * 2.0 * i / n + 1.0)
        out[i] = v * m
    _normalize(out, 0.6)
    return _to_stream(out, RATE, true)


static func crickets() -> AudioStreamWAV:
    var n := RATE * 2
    var out := PackedFloat32Array()
    out.resize(n)
    for i in n:
        var t := float(i) / RATE
        var v := 0.0
        for c in [[4200.0, 0.5, 0.0], [3900.0, 0.4, 0.13]]:
            var period: float = c[1]
            var local := fposmod(t - float(c[2]), period)
            for k in 3:
                var d := local - k * 0.07
                if d >= 0.0 and d < 0.04:
                    v += sin(TAU * float(c[0]) * t) * sin(PI * d / 0.04) * 0.25
        out[i] = v
    return _to_stream(out, RATE, true)


static func _silence(out: PackedFloat32Array, dur: float) -> void:
    for i in int(dur * RATE):
        out.append(0.0)


static func _chirp(out: PackedFloat32Array, f0: float, f1: float, dur: float, vol: float,
    vib: float=0.0) -> void:
    var n := int(dur * RATE)
    var ph := 0.0
    for i in n:
        var t := float(i) / n
        ph += lerpf(f0, f1, t) * (1.0 + vib * sin(t * TAU * 6.0)) / RATE
        out.append(sin(TAU * ph) * vol * sin(PI * t))


static func birds() -> Array:
    var tweet := PackedFloat32Array()
    for i in 3:
        _chirp(tweet, 3000.0 + i * 300.0, 4200.0, 0.08, 0.3)
        _silence(tweet, 0.05)
    var trill := PackedFloat32Array()
    for i in 9:
        _chirp(trill, 4600.0, 3600.0, 0.035, 0.28)
        _silence(trill, 0.022)
    var whistle := PackedFloat32Array()
    _chirp(whistle, 2300.0, 3100.0, 0.28, 0.3, 0.015)
    _silence(whistle, 0.06)
    _chirp(whistle, 3100.0, 2000.0, 0.4, 0.3, 0.02)
    var cuckoo := PackedFloat32Array()
    _chirp(cuckoo, 700.0, 680.0, 0.22, 0.35)
    _silence(cuckoo, 0.08)
    _chirp(cuckoo, 540.0, 520.0, 0.3, 0.35)
    var out: Array = []
    for a in [tweet, trill, whistle, cuckoo]:
        out.append(_to_stream(a, RATE, false))
    return out


static func owl() -> AudioStreamWAV:
    var a := PackedFloat32Array()
    _chirp(a, 400.0, 360.0, 0.4, 0.4)
    _silence(a, 0.25)
    _chirp(a, 400.0, 350.0, 0.25, 0.4)
    _silence(a, 0.1)
    _chirp(a, 380.0, 330.0, 0.5, 0.4)
    return _to_stream(a, RATE, false)


static func footsteps() -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = 810
    var out: Array = []
    for terrain in 3:
        var n := int(0.14 * RATE)
        var a := PackedFloat32Array()
        a.resize(n)
        var lp := 0.0
        for i in n:
            var t := float(i) / n
            var noise := rng.randf() * 2.0 - 1.0
            lp += (noise - lp) * [0.08, 0.65, 0.2][terrain]
            var sample := lp + sin(TAU * 75.0 * i / RATE) * 0.6
            if terrain == 1:
                sample = noise - lp
            elif terrain == 2:
                sample = lp + sin(TAU * (220.0 - 140.0 * t) * i / RATE) * sin(t * PI) * 0.5
            a[i] = sample * pow(1.0 - t, 2.5)
        _normalize(a, 0.5)
        out.append(_to_stream(a, RATE, false))
    return out


static func plucks() -> Array:
    var out: Array = []
    for f in [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]:
        var n := int(3.2 * RATE)
        var a := PackedFloat32Array()
        a.resize(n)
        var base := int(1.2 * RATE)
        for i in base:
            var t := float(i) / RATE
            var env := minf(t / 0.005, 1.0) * exp(-t * 3.6)
            a[i] = (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) * exp(-t * 3.0)) * env * 0.5
        for echo in [[0.43, 0.45], [0.86, 0.22], [1.29, 0.1]]:
            var off := int(float(echo[0]) * RATE)
            for i in base:
                if i + off < n:
                    a[i + off] += a[i] * float(echo[1])
        out.append(_to_stream(a, RATE, false))
    return out


## Slow four-chord pad (Cmaj7 - Am7 - Fmaj7 - G6) with overlapping windows, looped seamlessly.
static func pad(biome: int=0) -> AudioStreamWAV:
    var rate := 6000
    var chord_len := 4 * rate
    var total := chord_len * 4
    var out := PackedFloat32Array()
    out.resize(total)
    var chords := [
        [130.81, 164.81, 196.0, 246.94],
        [110.0, 130.81, 164.81, 196.0],
        [87.31, 110.0, 130.81, 164.81],
        [98.0, 123.47, 146.83, 164.81],
    ]
    for c in 4:
        var window := chord_len * 2
        for note in chords[c]:
            var step := TAU * float(note) * pow(2.0, [0, -5, -3, 2, 5][biome] / 12.0) / rate
            for k in window:
                var u := float(k) / window
                var env := sin(PI * u)
                env *= env
                var idx := (c * chord_len + k) % total
                out[idx] += sin(step * k) * env * 0.5
    _normalize(out, 0.55)
    return _to_stream(out, rate, true)


## Soft three-note bell used when something is discovered.
static func chime() -> AudioStreamWAV:
    var n := int(1.8 * RATE)
    var a := PackedFloat32Array()
    a.resize(n)
    for note in [[1318.5, 0.0, 1.0], [1760.0, 0.13, 0.8], [2093.0, 0.27, 0.6]]:
        var off := int(float(note[1]) * RATE)
        var f: float = note[0]
        for i in n - off:
            var t := float(i) / RATE
            var env := minf(t / 0.004, 1.0) * exp(-t * 2.8)
            var v := sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.76 * t) * exp(-t * 6.0)
            a[i + off] += v * env * 0.3 * float(note[2])
    for i in range(int(0.3 * RATE), n):
        a[i] += a[i - int(0.3 * RATE)] * 0.28
    return _to_stream(a, RATE, false)


## Quick rising plink for collecting lamp-moss.
static func collect() -> AudioStreamWAV:
    var n := int(0.9 * RATE)
    var a := PackedFloat32Array()
    a.resize(n)
    var k := 0
    for f in [659.25, 880.0, 1174.7]:
        var off := int(k * 0.07 * RATE)
        for i in n - off:
            var t := float(i) / RATE
            a[i + off] += sin(TAU * f * t) * minf(t / 0.003, 1.0) * exp(-t * 7.0) * 0.35
        k += 1
    return _to_stream(a, RATE, false)


## Wing flutter: bursts of high-passed noise.
static func flutter() -> AudioStreamWAV:
    var n := int(0.45 * RATE)
    var a := PackedFloat32Array()
    a.resize(n)
    var lp := 0.0
    for i in n:
        var t := float(i) / RATE
        var r := randf() * 2.0 - 1.0
        lp += (r - lp) * 0.5
        var hp := r - lp
        var env := pow(absf(sin(t * TAU * 9.0)), 1.5) * exp(-t * 5.0) * minf(t / 0.01, 1.0)
        a[i] = hp * env
    _normalize(a, 0.5)
    return _to_stream(a, RATE, false)
