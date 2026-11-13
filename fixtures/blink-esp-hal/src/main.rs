//! Smoke fixture: blink one LED on bare-metal esp-hal.
//!
//! Only compiled and linked in CI, never flashed. The pin is each board's usual user LED:
//!
//! | Feature | Board | LED |
//! |:--|:--|:--|
//! | `esp32` | ESP32 DevKit V1 | GPIO2 |
//! | `esp32s3` | Heltec WiFi LoRa 32 V3 | GPIO35 |
//! | `esp32c3` | ESP32-C3-DevKit-RUST-1 | GPIO7 |
//! | `esp32c6` | Seeed XIAO ESP32C6 | GPIO15 |

#![no_std]
#![no_main]

#[cfg(not(any(
    feature = "esp32",
    feature = "esp32s3",
    feature = "esp32c3",
    feature = "esp32c6"
)))]
compile_error!("enable exactly one chip feature: esp32, esp32s3, esp32c3 or esp32c6");

use blink::Blinker;
use esp_hal::delay::Delay;
use esp_hal::gpio::{Level, Output, OutputConfig};
use esp_hal::main;

esp_bootloader_esp_idf::esp_app_desc!();

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    esp_hal::system::software_reset()
}

#[main]
fn main() -> ! {
    let peripherals = esp_hal::init(esp_hal::Config::default());

    #[cfg(feature = "esp32")]
    let led_pin = peripherals.GPIO2;
    #[cfg(feature = "esp32s3")]
    let led_pin = peripherals.GPIO35;
    #[cfg(feature = "esp32c3")]
    let led_pin = peripherals.GPIO7;
    #[cfg(feature = "esp32c6")]
    let led_pin = peripherals.GPIO15;

    let led = Output::new(led_pin, Level::Low, OutputConfig::default());
    let mut blinker = Blinker::new(led, Delay::new());

    esp_println::println!("blink-esp-hal: up");
    loop {
        // `Output` is infallible.
        let Ok(()) = blinker.blink(1, 1_000);
    }
}
