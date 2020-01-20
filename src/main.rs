#![feature(proc_macro_hygiene)] // enable expanding macros into expressions

use warp::Filter;
use gettext_macros::{ init_i18n, i18n, compile_i18n, include_i18n }; //macros must be called in the same order as listed here

init_i18n!("wbooks", en, fr);

#[tokio::main]
async fn main() {
    let catalog = i18ncat();

    let default = warp::fs::dir("public/");
    let hello = warp::path!("hello" / String).map(move |name| format!("{}", i18n!(catalog.clone(), "Hello, {}!"; name)));
    let routes = warp::get()
        .and( warp::path("api")
              .and(hello)
        )
        .or(default);

    warp::serve(routes).run(([127, 0, 0, 1], 3030)).await;
}

compile_i18n!();

fn i18ncat() -> gettext::Catalog {
    include_i18n!()[0].1.clone()
}
