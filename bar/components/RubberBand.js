.pragma library

function rubberBand(x, L, c) {
    if (L <= 0) return 0;
    const magnitude = (1 - 1 / (Math.abs(x) * c / L + 1)) * L;
    return magnitude * (x < 0 ? -1 : 1);
}
