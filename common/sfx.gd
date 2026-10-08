class_name Sfx
extends RefCounted

## Procedural retro sound generator, so the project needs no audio assets.
## A sound is an array of segments: [start_freq, end_freq, duration, wave, volume]
## where wave is "square", "sine" or "noise". Segments are played back to back.

const RATE := 22050


static func build(segments: Array) -> AudioStreamWAV:
    var data := PackedByteArray()
    for seg in segments:
        var f0: float = seg[0]
        var f1: float = seg[1]
        var n := int(float(seg[2]) * RATE)
        var wave: String = seg[3]
        var vol: float = seg[4]
        var phase := 0.0
        for i in n:
            var t := float(i) / n
            phase += lerpf(f0, f1, t) / RATE
            var s := 0.0
            match wave:
                "square":
                    s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
                "sine":
                    s = sin(TAU * phase)
                "noise":
                    s = randf() * 2.0 - 1.0
            s *= vol * (1.0 - t)  # linear decay envelope
            data.resize(data.size() + 2)
            data.encode_s16(data.size() - 2, int(clampf(s, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = RATE
    stream.stereo = false
    stream.data = data
    return stream
