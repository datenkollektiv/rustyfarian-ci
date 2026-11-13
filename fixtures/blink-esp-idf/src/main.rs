//! Smoke fixture: blink one LED on ESP-IDF (std) with `esp-idf-hal`.
//!
//! Only compiled and linked in CI, never flashed. The pin is each board's usual user LED,
//! chosen by the target the build is for:
//!
//! | `MCU` | Board | LED |
//! |:--|:--|:--|
//! | `esp32` | ESP32 DevKit V1 | GPIO2 |
//! | `esp32s3` | Heltec WiFi LoRa 32 V3 | GPIO35 |
//! | `esp32c3` | ESP32-C3-DevKit-RUST-1 | GPIO7 |
//! | `esp32c6` | Seeed XIAO ESP32C6 | GPIO15 |

use blink::Blinker;
use esp_idf_hal::delay::FreeRtos;
use esp_idf_hal::gpio::PinDriver;
use esp_idf_hal::peripherals::Peripherals;
use esp_idf_hal::sys::EspError;

fn main() -> Result<(), EspError> {
    // Links the esp-idf-sys runtime patches; see esp-rs/esp-idf-template#71.
    esp_idf_hal::sys::link_patches();

    let pins = Peripherals::take()?.pins;

    #[cfg(esp32)]
    let led_pin = pins.gpio2;
    #[cfg(esp32s3)]
    let led_pin = pins.gpio35;
    #[cfg(esp32c3)]
    let led_pin = pins.gpio7;
    #[cfg(esp32c6)]
    let led_pin = pins.gpio15;

    let led = PinDriver::output(led_pin)?;
    let mut blinker = Blinker::new(led, FreeRtos);

    println!("blink-esp-idf: up");
    loop {
        blinker.blink(1, 1_000).map_err(|e| e.cause())?;
    }
}
