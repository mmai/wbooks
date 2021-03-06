#![feature(proc_macro_hygiene)] // enable expanding macros into expressions

use warp::Filter;
use gettext_macros::{ init_i18n, i18n, compile_i18n, include_i18n }; //macros must be called in the same order as listed here

init_i18n!("wbooks", en, fr);



#[tokio::main]
async fn main() {

    let catalogs: Vec<(&'static str, gettext::Catalog)> = i18ncat();


    let default = warp::fs::dir("public/");

    let hello = 
        warp::path!("hello" / String)
        .and(warp::header("Accept-Language"))
        .map(move |name: String, lang: String| {
            let (_stcat, catalog) = match lang.as_str() {
                "fr" => &catalogs[1],
                _ => &catalogs[0],
            };
            format!("{}", i18n!(catalog, "Hello, {}!"; name))
    });

    let routes = warp::get()
        .and( warp::path("api")
              .and(hello)
        )
        .or(default);

    warp::serve(routes).run(([127, 0, 0, 1], 3030)).await;
}

compile_i18n!();

fn i18ncat() ->  Vec<(&'static str, gettext::Catalog)> {
    include_i18n!()
}
