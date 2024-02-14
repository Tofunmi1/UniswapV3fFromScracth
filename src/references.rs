fn main() {
    let mut s = String::from("hello");
    let r1 = &s; //possible
    let r2 = &s; // possible
    /// let r3 = &mut s; // impossible (only possible after using the immutable references created first, r1 and r2)
    println!("{}, {}", r1, r2); // can only read or use once , else an error would be thrown
    let r3 = &mut s; // can only create a mutable reference after using the first immutable references created
    print!("{}", r3) // can use r3 here
}

/// Example use of mutable refernces (&)
fn change(some_string: &mut String) {
    some_string.push(", pushed_string");
}
