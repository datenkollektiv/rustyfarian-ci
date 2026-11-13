fn main() {
    // esp-idf-sys sets one chip cfg (from MCU) that main.rs uses to pick the LED pin.
    println!("cargo::rustc-check-cfg=cfg(esp32, esp32s3, esp32c3, esp32c6)");
    embuild::espidf::sysenv::output();
}
