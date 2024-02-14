fn ownership() {
    let s1 = String::from("hello");
    let s2 = s1.clone();
    println!("{}", s2);
    println!("{}", s1);
}

//
fn main_call_01() {
    let s = String::from("hello");
    takes_ownership(s.clone());
    println!("{}", s);

    let x: u32 = 65;
    makes_copy(x);
    println!("{}", x);
}

fn takes_ownership(some_string: String) {
    println!("{}", some_string)
}

fn makes_copy(some_interger: u32) {
    println!("{}", some_interger);
}
