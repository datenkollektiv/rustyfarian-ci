//! Smoke fixture: blink one LED through the `embedded-hal` 1.0 traits.
//!
//! The firmware fixtures (`blink-esp-hal`, `blink-esp-idf`, `blink-avr`) wire one GPIO
//! into [`Blinker`], so every target in the family links the same code.

#![cfg_attr(not(test), no_std)]

use embedded_hal::delay::DelayNs;
use embedded_hal::digital::OutputPin;

/// Drives one output pin high and low with a delay provider.
pub struct Blinker<P, D> {
    pin: P,
    delay: D,
}

impl<P: OutputPin, D: DelayNs> Blinker<P, D> {
    /// Wraps an output pin and a delay provider.
    pub fn new(pin: P, delay: D) -> Self {
        Self { pin, delay }
    }

    /// Blinks `times` times; each blink is on for half of `period_ms`, then off for the rest.
    ///
    /// The pin is left low. Stops at the first pin error.
    pub fn blink(&mut self, times: u32, period_ms: u32) -> Result<(), P::Error> {
        let on_ms = period_ms / 2;
        let off_ms = period_ms - on_ms;
        for _ in 0..times {
            self.pin.set_high()?;
            self.delay.delay_ms(on_ms);
            self.pin.set_low()?;
            self.delay.delay_ms(off_ms);
        }
        Ok(())
    }

    /// Returns the pin and the delay provider.
    pub fn release(self) -> (P, D) {
        (self.pin, self.delay)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use core::convert::Infallible;
    use embedded_hal::digital::{Error, ErrorKind, ErrorType};

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    enum Event {
        High,
        Low,
        DelayNs(u32),
    }

    /// Records pin levels and delays into one shared timeline.
    #[derive(Default)]
    struct Recorder {
        events: std::cell::RefCell<Vec<Event>>,
    }

    struct MockPin<'a> {
        recorder: &'a Recorder,
        fail_after: Option<usize>,
    }

    #[derive(Debug, PartialEq, Eq)]
    struct PinFault;

    impl Error for PinFault {
        fn kind(&self) -> ErrorKind {
            ErrorKind::Other
        }
    }

    impl ErrorType for MockPin<'_> {
        type Error = PinFault;
    }

    impl MockPin<'_> {
        fn record(&mut self, event: Event) -> Result<(), PinFault> {
            match self.fail_after {
                Some(0) => Err(PinFault),
                Some(ref mut left) => {
                    *left -= 1;
                    self.recorder.events.borrow_mut().push(event);
                    Ok(())
                }
                None => {
                    self.recorder.events.borrow_mut().push(event);
                    Ok(())
                }
            }
        }
    }

    impl OutputPin for MockPin<'_> {
        fn set_high(&mut self) -> Result<(), Self::Error> {
            self.record(Event::High)
        }

        fn set_low(&mut self) -> Result<(), Self::Error> {
            self.record(Event::Low)
        }
    }

    struct MockDelay<'a> {
        recorder: &'a Recorder,
    }

    impl DelayNs for MockDelay<'_> {
        fn delay_ns(&mut self, ns: u32) {
            self.recorder.events.borrow_mut().push(Event::DelayNs(ns));
        }
    }

    fn blinker(
        recorder: &Recorder,
        fail_after: Option<usize>,
    ) -> Blinker<MockPin<'_>, MockDelay<'_>> {
        Blinker::new(
            MockPin {
                recorder,
                fail_after,
            },
            MockDelay { recorder },
        )
    }

    fn ms(ms: u32) -> Event {
        Event::DelayNs(ms * 1_000_000)
    }

    #[test]
    fn blinks_high_then_low_with_half_periods() {
        let recorder = Recorder::default();
        blinker(&recorder, None).blink(2, 500).unwrap();
        assert_eq!(
            *recorder.events.borrow(),
            [
                Event::High,
                ms(250),
                Event::Low,
                ms(250),
                Event::High,
                ms(250),
                Event::Low,
                ms(250)
            ]
        );
    }

    #[test]
    fn odd_period_gives_the_spare_millisecond_to_off() {
        let recorder = Recorder::default();
        blinker(&recorder, None).blink(1, 3).unwrap();
        assert_eq!(
            *recorder.events.borrow(),
            [Event::High, ms(1), Event::Low, ms(2)]
        );
    }

    #[test]
    fn zero_times_touches_nothing() {
        let recorder = Recorder::default();
        blinker(&recorder, None).blink(0, 500).unwrap();
        assert!(recorder.events.borrow().is_empty());
    }

    #[test]
    fn stops_at_first_pin_error() {
        let recorder = Recorder::default();
        assert_eq!(blinker(&recorder, Some(1)).blink(3, 10), Err(PinFault));
        assert_eq!(*recorder.events.borrow(), [Event::High, ms(5)]);
    }

    #[test]
    fn release_returns_the_parts() {
        struct NoopPin;
        impl ErrorType for NoopPin {
            type Error = Infallible;
        }
        impl OutputPin for NoopPin {
            fn set_high(&mut self) -> Result<(), Infallible> {
                Ok(())
            }
            fn set_low(&mut self) -> Result<(), Infallible> {
                Ok(())
            }
        }
        let recorder = Recorder::default();
        let (NoopPin, delay) = Blinker::new(
            NoopPin,
            MockDelay {
                recorder: &recorder,
            },
        )
        .release();
        assert!(core::ptr::eq(delay.recorder, &recorder));
    }
}
