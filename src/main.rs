use warp::Filter;

#[tokio::main]
async fn main() {
    let default = warp::fs::dir("public/");
    let hello = warp::path!("hello" / String).map(|name| format!("Hello {}", name));
    let routes = warp::get()
        .and( warp::path("api")
              .and(hello)
        )
        .or(default);

    warp::serve(routes).run(([127, 0, 0, 1], 3030)).await;
}
