//! In-process peak reduction; routing and the envelope remain in Python.

fn peak(samples: &[f32]) -> f32 {
    samples
        .iter()
        .copied()
        .filter(|v| v.is_finite())
        .fold(0.0_f32, |maximum, value| maximum.max(value.abs()))
}

/// Maximum finite absolute sample, or zero for an empty buffer.
///
/// # Safety
/// For nonempty buffers, `samples` must point to `length` aligned, initialized
/// f32 values that remain alive and unmodified for the duration of this call.
#[no_mangle]
pub unsafe extern "C" fn isla_peak_f32_v1(samples: *const f32, length: usize) -> f32 {
    if length == 0
        || samples.is_null()
        || !samples.is_aligned()
        || length > isize::MAX as usize / std::mem::size_of::<f32>()
    {
        return 0.0;
    }
    // The Python caller retains its owned array throughout the synchronous call.
    peak(unsafe { std::slice::from_raw_parts(samples, length) })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finite_peak_ignores_invalid_samples() {
        assert_eq!(peak(&[]), 0.0);
        assert_eq!(peak(&[f32::NAN, f32::INFINITY, f32::NEG_INFINITY]), 0.0);
        assert_eq!(peak(&[-0.0, -0.75, 0.25, f32::NAN]), 0.75);
        assert_eq!(peak(&[-f32::MAX]), f32::MAX);
        assert_eq!(peak(&[f32::from_bits(1)]), f32::from_bits(1));
    }

    #[test]
    fn ffi_accepts_owned_arrays_and_rejects_obvious_invalid_buffers() {
        let samples = [0.25, -0.5];
        unsafe {
            assert_eq!(isla_peak_f32_v1(samples.as_ptr(), samples.len()), 0.5);
            assert_eq!(isla_peak_f32_v1(std::ptr::null(), 0), 0.0);
            assert_eq!(isla_peak_f32_v1(std::ptr::null(), 10), 0.0);
            assert_eq!(isla_peak_f32_v1(samples.as_ptr(), usize::MAX), 0.0);
            let unaligned = samples.as_ptr().cast::<u8>().wrapping_add(1).cast::<f32>();
            assert_eq!(isla_peak_f32_v1(unaligned, 1), 0.0);
        }
    }
}
