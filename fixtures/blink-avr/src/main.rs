//! Smoke fixture: blink one LED on the ATmega328P with avr-hal.
//!
//! Only compiled and linked in CI, never flashed.
//! The pin is the on-board LED of the Arduino Nano and Uno: D13 (PB5).

#![no_std]
#![no_main]

use blink::Blinker;

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[arduino_hal::entry]
fn main() -> ! {
    // `take` only fails on a second call; `main` is the only caller.
    let Some(dp) = arduino_hal::Peripherals::take() else {
        panic!("peripherals taken twice");
    };
    let pins = arduino_hal::pins!(dp);

    let led = pins.d13.into_output();
    let mut blinker = Blinker::new(led, arduino_hal::Delay::new());

    loop {
        // avr-hal output pins are infallible.
        let Ok(()) = blinker.blink(1, 1_000);
    }
}
