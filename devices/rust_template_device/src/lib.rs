use rustler::{NifResult, Error};

#[rustler::nif]
fn hello_world() -> NifResult<String> {
    Ok("Hello from Rust NIF!".to_string())
}

#[rustler::nif]
fn add_numbers(a: i64, b: i64) -> NifResult<i64> {
    Ok(a + b)
}

#[rustler::nif]
fn echo_string(input: String) -> NifResult<String> {
    Ok(format!("Echo: {}", input))
}

rustler::init!("rust_template_device");