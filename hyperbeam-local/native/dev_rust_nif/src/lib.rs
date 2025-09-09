use rustler::NifResult;
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
struct CalculationRequest {
    a: f64,
    b: f64,
    operation: String,
}

#[derive(Serialize)]
struct CalculationResult {
    result: f64,
    operation: String,
    inputs: (f64, f64),
    success: bool,
}

#[derive(Deserialize)]
struct BatchRequest {
    operations: Vec<Operation>,
}

#[derive(Deserialize)]
#[serde(tag = "type")]
enum Operation {
    #[serde(rename = "add")]
    Add { a: f64, b: f64 },
    #[serde(rename = "multiply")]
    Multiply { a: f64, b: f64 },
    #[serde(rename = "power")]
    Power { base: f64, exp: f64 },
    #[serde(rename = "echo")]
    Echo { text: String },
}

#[derive(Serialize)]
struct BatchResult {
    results: Vec<OperationResult>,
    total_operations: usize,
    success: bool,
}

#[derive(Serialize)]
#[serde(tag = "type")]
enum OperationResult {
    #[serde(rename = "calculation")]
    Calculation {
        result: f64,
        operation: String,
        inputs: (f64, f64),
    },
    #[serde(rename = "echo")]
    Echo {
        original: String,
        echoed: String,
    },
}

fn encode_json<T: Serialize>(data: &T) -> NifResult<String> {
    let json_string = serde_json::to_string(data)
        .map_err(|_| rustler::Error::BadArg)?;
    
    Ok(json_string)
}

#[rustler::nif]
fn hello_world_nif() -> NifResult<String> {
    Ok("Hello from Rust NIF!".to_string())
}

#[rustler::nif]
fn add_numbers_nif(a: i64, b: i64) -> NifResult<i64> {
    Ok(a + b)
}

#[rustler::nif]
fn echo_string_nif(input: String) -> NifResult<String> {
    Ok(format!("Echo: {}", input))
}

#[rustler::nif]
pub fn advanced_calculate_nif(input: String) -> NifResult<String> {
    let input_str = &input;
    let request: CalculationRequest = serde_json::from_str(input_str)
        .map_err(|_| rustler::Error::BadArg)?;

    let result = match request.operation.as_str() {
        "add" => request.a + request.b,
        "subtract" => request.a - request.b,
        "multiply" => request.a * request.b,
        "divide" => {
            if request.b == 0.0 {
                return Ok(encode_json(&CalculationResult {
                    result: f64::NAN,
                    operation: request.operation,
                    inputs: (request.a, request.b),
                    success: false,
                })?);
            }
            request.a / request.b
        },
        "power" => request.a.powf(request.b),
        "sqrt" => request.a.sqrt(),
        "log" => request.a.ln(),
        _ => return Err(rustler::Error::BadArg),
    };

    let response = CalculationResult {
        result,
        operation: request.operation,
        inputs: (request.a, request.b),
        success: !result.is_nan(),
    };

    encode_json(&response)
}

#[rustler::nif]
pub fn batch_operations_nif(input: String) -> NifResult<String> {
    let input_str = &input;
    let request: BatchRequest = serde_json::from_str(input_str)
        .map_err(|_| rustler::Error::BadArg)?;

    let mut results = Vec::new();
    
    for operation in request.operations {
        let result = match operation {
            Operation::Add { a, b } => OperationResult::Calculation {
                result: a + b,
                operation: "add".to_string(),
                inputs: (a, b),
            },
            Operation::Multiply { a, b } => OperationResult::Calculation {
                result: a * b,
                operation: "multiply".to_string(),
                inputs: (a, b),
            },
            Operation::Power { base, exp } => OperationResult::Calculation {
                result: base.powf(exp),
                operation: "power".to_string(),
                inputs: (base, exp),
            },
            Operation::Echo { text } => OperationResult::Echo {
                original: text.clone(),
                echoed: format!("Rust NIF Echo: {}", text),
            },
        };
        results.push(result);
    }

    let response = BatchResult {
        total_operations: results.len(),
        results,
        success: true,
    };

    encode_json(&response)
}

#[rustler::nif]
pub fn hash_string_nif(input: String) -> NifResult<String> {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    
    let mut hasher = DefaultHasher::new();
    input.hash(&mut hasher);
    let hash = hasher.finish();
    
    Ok(format!("0x{:x}", hash))
}

#[rustler::nif]
pub fn fibonacci_nif(n: u32) -> NifResult<u64> {
    if n == 0 {
        return Ok(0);
    } else if n == 1 {
        return Ok(1);
    }
    
    let mut a = 0u64;
    let mut b = 1u64;
    
    for _ in 2..=n {
        let temp = a.checked_add(b).ok_or(rustler::Error::BadArg)?;
        a = b;
        b = temp;
    }
    
    Ok(b)
}

#[rustler::nif]
pub fn is_prime_nif(n: u64) -> NifResult<bool> {
    if n < 2 {
        return Ok(false);
    }
    if n == 2 {
        return Ok(true);
    }
    if n % 2 == 0 {
        return Ok(false);
    }
    
    let sqrt_n = (n as f64).sqrt() as u64;
    for i in (3..=sqrt_n).step_by(2) {
        if n % i == 0 {
            return Ok(false);
        }
    }
    
    Ok(true)
}

rustler::init!("dev_rust_nif", [
    hello_world_nif,
    add_numbers_nif, 
    echo_string_nif,
    advanced_calculate_nif,
    batch_operations_nif,
    hash_string_nif,
    fibonacci_nif,
    is_prime_nif
]);