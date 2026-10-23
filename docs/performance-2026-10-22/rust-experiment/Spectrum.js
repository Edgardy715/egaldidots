// Validate the whole frame before publishing any audio state.
function parse(line, count) {
    var parts = line.trim().split(/\s+/)
    if (parts.length !== count) return null
    var samples = []
    for (var i = 0; i < count; i++) {
        var value = Number(parts[i])
        if (!isFinite(value) || value < 0 || value > 65535) return null
        // Fixed perceptual range; silence stays zero and gain never chases quiet audio.
        var magnitude = value / 65535
        samples.push(magnitude > 0 ? Math.max(0, Math.min(1,
            (20 * Math.log(magnitude) / Math.LN10 + 72) / 60)) : 0)
    }
    return samples.map(function (value, i) {
        return (samples[Math.max(0, i - 1)] + 2 * value
            + samples[Math.min(count - 1, i + 1)]) / 4
    })
}

function advance(current, target, dt) {
    return current.map(function (value, i) {
        var goal = target[i] || 0
        // Monotone response: 65 ms attack, 210 ms release; no spring or overshoot.
        var blend = 1 - Math.exp(-Math.max(0, dt) / (goal > value ? 0.065 : 0.210))
        var next = value + (goal - value) * blend
        return next < 0.0001 ? 0 : next
    })
}

function band(values, index, count) {
    var start = Math.floor(index * values.length / count)
    var end = Math.max(start + 1, Math.floor((index + 1) * values.length / count))
    var sum = 0
    for (var i = start; i < end; i++) sum += Math.pow(values[i] || 0, 2)
    return Math.sqrt(sum / (end - start))
}
