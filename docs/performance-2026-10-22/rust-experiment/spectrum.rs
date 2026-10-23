use std::time::{Duration, Instant};

const PERIOD: Duration = Duration::from_nanos(16_666_667);

fn js_space(c: char) -> bool {
    matches!(c, '\u{0009}'..='\u{000d}' | '\u{0020}' | '\u{00a0}' | '\u{1680}' | '\u{2000}'..='\u{200a}' | '\u{2028}' | '\u{2029}' | '\u{202f}' | '\u{205f}' | '\u{3000}' | '\u{feff}')
}

fn number(token: &str) -> Option<f64> {
    if token.is_empty() {
        return Some(0.0);
    }
    for (prefixes, radix) in [(["0x", "0X"], 16), (["0o", "0O"], 8), (["0b", "0B"], 2)] {
        if prefixes.iter().any(|prefix| token.starts_with(prefix)) {
            return u64::from_str_radix(&token[2..], radix)
                .ok()
                .map(|n| n as f64);
        }
    }
    token.parse().ok()
}

pub fn parse(line: &str, count: usize) -> Option<Vec<f64>> {
    let trimmed = line.trim_matches(js_space);
    let parts: Vec<_> = if trimmed.is_empty() {
        vec![""]
    } else {
        trimmed.split(js_space).filter(|s| !s.is_empty()).collect()
    };
    if parts.len() != count {
        return None;
    }
    let samples: Option<Vec<_>> = parts
        .iter()
        .map(|s| {
            let value = number(s)?;
            if !value.is_finite() || !(0.0..=65535.0).contains(&value) {
                return None;
            }
            let magnitude = value / 65535.0;
            Some(if magnitude > 0.0 {
                ((20.0 * magnitude.ln() / std::f64::consts::LN_10 + 72.0) / 60.0).clamp(0.0, 1.0)
            } else {
                0.0
            })
        })
        .collect();
    let samples = samples?;
    Some(
        samples
            .iter()
            .enumerate()
            .map(|(i, v)| {
                (samples[i.saturating_sub(1)] + 2.0 * v + samples[(i + 1).min(count - 1)]) / 4.0
            })
            .collect(),
    )
}

pub fn advance(current: &mut [f64], target: &[f64], dt: f64) {
    for (i, value) in current.iter_mut().enumerate() {
        let goal = target.get(i).copied().unwrap_or(0.0);
        let blend = 1.0 - (-dt.max(0.0) / if goal > *value { 0.065 } else { 0.210 }).exp();
        let next = *value + (goal - *value) * blend;
        *value = if next < 0.0001 { 0.0 } else { next };
    }
}

pub struct Smoother {
    current: Vec<f64>,
    target: Vec<f64>,
    received: Instant,
    last: Instant,
    pub deadline: Option<Instant>,
    published: bool,
}
impl Smoother {
    pub fn new() -> Self {
        let now = Instant::now();
        Self {
            current: vec![0.0; 24],
            target: Vec::new(),
            received: now,
            last: now,
            deadline: None,
            published: false,
        }
    }
    pub fn ingest(&mut self, line: &[u8]) {
        if let Some(target) = std::str::from_utf8(line).ok().and_then(|s| parse(s, 24)) {
            self.target = target;
            self.received = Instant::now();
            if self.deadline.is_none() && (!self.published || self.target.iter().any(|v| *v > 0.0))
            {
                self.last = self.received;
                self.deadline = Some(self.received + PERIOD);
            }
        }
    }
    pub fn tick(&mut self, now: Instant) -> Option<Vec<u8>> {
        if self.deadline.is_none_or(|deadline| now < deadline) {
            return None;
        }
        let fresh = now.duration_since(self.received) < Duration::from_millis(250);
        let previous = self.current.clone();
        advance(
            &mut self.current,
            if fresh { &self.target } else { &[] },
            now.duration_since(self.last).as_secs_f64().min(0.05),
        );
        self.last = now;
        // Skip missed ticks: never emit a burst after a stalled reader or scheduler.
        self.deadline = if self.current.iter().any(|v| *v > 0.0)
            || (fresh && self.target.iter().any(|v| *v > 0.0))
        {
            Some(if self.deadline.unwrap() + PERIOD > now {
                self.deadline.unwrap() + PERIOD
            } else {
                now + PERIOD
            })
        } else {
            None
        };
        if self.published && previous == self.current {
            return None;
        }
        self.published = true;
        let mut frame = self
            .current
            .iter()
            .map(ToString::to_string)
            .collect::<Vec<_>>()
            .join(" ")
            .into_bytes();
        frame.push(b'\n');
        Some(frame)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;
    fn floats(v: &Value) -> Vec<f64> {
        v.as_array()
            .unwrap()
            .iter()
            .map(|n| n.as_f64().unwrap())
            .collect()
    }
    fn equal(actual: &[f64], expected: &[f64]) {
        assert_eq!(actual.len(), expected.len());
        for (a, e) in actual.iter().zip(expected) {
            assert!((a - e).abs() <= 2e-14, "{a} != {e}");
        }
    }
    #[test]
    fn javascript_vectors() {
        let data: Value = serde_json::from_str(include_str!("../vectors.json")).unwrap();
        for v in data["parse"].as_array().unwrap() {
            let result = parse(
                v["line"].as_str().unwrap(),
                v["count"].as_u64().unwrap() as usize,
            );
            if v["expected"].is_null() {
                assert!(result.is_none());
            } else {
                equal(&result.unwrap(), &floats(&v["expected"]));
            }
        }
        for v in data["advance"].as_array().unwrap() {
            let mut current = floats(&v["current"]);
            advance(
                &mut current,
                &floats(&v["target"]),
                v["dt"].as_f64().unwrap(),
            );
            equal(&current, &floats(&v["expected"]));
        }
    }
    #[test]
    fn stalled_clock_skips_missed_ticks() {
        let mut s = Smoother::new();
        s.ingest(["65535"; 24].join(" ").as_bytes());
        let delayed = s.received + Duration::from_millis(100);
        assert!(s.tick(delayed).is_some());
        assert!(s.tick(delayed + Duration::from_millis(1)).is_none());
        assert_eq!(s.deadline, Some(delayed + PERIOD));
    }

    #[test]
    fn cadence_stale_release_silence_and_resume() {
        let mut s = Smoother::new();
        s.ingest(["65535"; 24].join(" ").as_bytes());
        let start = s.received;
        assert!(s.tick(start).is_none());
        let first = s.tick(start + PERIOD).unwrap();
        assert!(parse(std::str::from_utf8(&first).unwrap(), 24).is_some());
        assert!(s.tick(start + PERIOD).is_none());
        for i in 2..180 {
            s.tick(start + PERIOD * i);
        }
        assert!(s.current.iter().all(|v| *v == 0.0));
        assert!(s.deadline.is_none());
        s.ingest(["65535"; 24].join(" ").as_bytes());
        assert!(s.deadline.is_some());
    }
}
