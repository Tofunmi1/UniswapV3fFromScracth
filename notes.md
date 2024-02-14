- double free error :- rust frees memory twice here

```rust
    let s1 = String::from("hello");
    let s2 = s1;
    println!("{}", s2);
    println!("{}", s1);
```
