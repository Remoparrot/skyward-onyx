//! Lays a page out the way the browser does and draws it, for looking at
//! without flashing an image.
//!
//!   webpaint <out-dir> <MiSansVF.ttf> <KirkMono-Regular.ttf> [url|file] [top] [height]
//!
//! with `WEBPAINT_UI=1` it draws the browser page itself — the address,
//! its buttons and the page under them — as the recovery would show it.

use anyhow::{anyhow, Context, Result};
use skyward_info::{Battery, Boot, Charge, Cpu, DeviceInfo, Storage};
use skyward_ui::app::{App, Screen};
use skyward_ui::pages::{self, Band, Ctx};
use skyward_ui::web;
use skyward_ui::{Canvas, Fonts, Lang};
use skyward_vab::{Slot, SnapshotState};
use std::io::BufWriter;
use std::net::Ipv4Addr;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Instant;

const W: u32 = 1280;
const H: u32 = 2772;
const PPD: f32 = 512.0 / 160.0;

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let out = PathBuf::from(args.get(1).map(String::as_str).unwrap_or("out"));
    let font = PathBuf::from(args.get(2).expect("the MiSansVF.ttf path"));
    let mono = PathBuf::from(args.get(3).expect("the KirkMono-Regular.ttf path"));
    let target = args.get(4).cloned().unwrap_or_else(|| "https://cn.bing.com/search?q=skyward".into());
    let top: f32 = args.get(5).and_then(|s| s.parse().ok()).unwrap_or(0.0);
    let height: u32 = args.get(6).and_then(|s| s.parse().ok()).unwrap_or(2600);
    let ui = std::env::var("WEBPAINT_UI").is_ok_and(|v| v == "1");
    std::fs::create_dir_all(&out).with_context(|| format!("make {}", out.display()))?;
    let fonts = Fonts::load(&font, 0, &mono)?;

    // A URL fetched the way the browser's downloads are, for timing them.
    if let Ok(url) = std::env::var("WEBPAINT_FETCH") {
        let dns = std::env::var("WEBPAINT_DNS").ok().and_then(|s| s.parse::<Ipv4Addr>().ok()).unwrap_or(Ipv4Addr::new(192, 168, 1, 1));
        let servers = Arc::new(Mutex::new(vec![dns, Ipv4Addr::new(223, 5, 5, 5), Ipv4Addr::new(114, 114, 114, 114)]));
        let agent = skyward_net::http::agent(servers);
        let path = out.join(skyward_net::download::name_of(&url));
        let stop = AtomicBool::new(false);
        let paused = AtomicBool::new(false);
        let started = Instant::now();
        let mut printed = Instant::now();
        let mut last = 0u64;
        let mut tell = |progress: skyward_net::download::Progress| {
            if let skyward_net::download::Progress::Downloading { done, total } = progress {
                if printed.elapsed().as_millis() >= 500 || done == total {
                    let secs = started.elapsed().as_secs_f64().max(0.001);
                    println!("{} / {} bytes · {:.2} MB/s", done, total, done as f64 / secs / 1e6);
                    last = done;
                    printed = Instant::now();
                }
            }
        };
        let slow = std::env::var("WEBPAINT_SLOW").is_ok_and(|v| v == "1");
        let ended = if slow {
            skyward_net::download::save(&agent, &url, &path, &stop, &paused, &mut tell)
        } else {
            skyward_net::download::save_fast(&agent, &url, &path, &stop, &paused, &mut tell)
        };
        let secs = started.elapsed().as_secs_f64();
        match ended {
            Ok(()) => println!("done {} bytes in {:.2}s · {:.2} MB/s -> {}", last, secs, last as f64 / secs / 1e6, path.display()),
            Err(e) => println!("failed after {:.2}s: {e:#}", secs),
        }
        return Ok(());
    }

    let started = Instant::now();
    let loaded = if target.starts_with("http://") || target.starts_with("https://") {
        let dns = std::env::var("WEBPAINT_DNS").ok().and_then(|s| s.parse::<Ipv4Addr>().ok()).unwrap_or(Ipv4Addr::new(192, 168, 1, 1));
        let servers = Arc::new(Mutex::new(vec![dns, Ipv4Addr::new(223, 5, 5, 5), Ipv4Addr::new(114, 114, 114, 114)]));
        let agent = skyward_net::http::agent(servers);
        web::fetch(&agent, &target).map_err(|e| anyhow!("{e}"))?
    } else {
        let html = std::fs::read_to_string(&target).with_context(|| format!("read {target}"))?;
        let doc = web::html::parse(&html);
        let title = doc.elements("title").first().map(|&t| doc.text_of(t)).unwrap_or_default();
        web::Loaded { url: format!("file://{target}"), title, doc, images: Default::default() }
    };
    let fetched = started.elapsed();

    let started = Instant::now();
    let page = Arc::new(web::Page::lay_out(loaded, &fonts, W as f32));
    let laid = started.elapsed();
    println!("fetch {fetched:?} layout {laid:?} page {}x{} items {} links {}", page.width, page.height, page.items.len(), page.links.len());
    println!("title: {}", page.title);
    println!("url: {}", page.url);

    let started = Instant::now();
    let first = (top.max(0.0) as u32).min(page.height.max(1.0) as u32 - 1);
    let last = (first + height).min(page.height.max(1.0) as u32);
    let canvas = if ui {
        let mut app = App::new(Screen::Browser, W, H, PPD);
        app.state.lang = Lang::Hans;
        app.state.dark = true;
        app.state.download_url = page.url.clone();
        app.state.browser_title = page.title.clone();
        app.state.browser_page = Some(page.clone());
        let t = app.theme();
        let info = onyx();
        let band = Band { rows: (first, last), cols: (0, W) };
        let cx = Ctx { t: &t, f: &fonts, info: &info, state: &app.state, term: None, band: Some(band) };
        let frame = pages::render(Screen::Browser, &cx);
        let mut c = Canvas::new(W, last - first);
        c.clear(frame.bg);
        c.put_rows(&frame.canvas, first as i32, last as i32, 0);
        if first == 0 {
            skyward_ui::widgets::status_bar(&mut c, &t, &fonts, &app.bar("23:46", &info), t.pal.status);
        }
        c
    } else {
        let mut band = Canvas::band(W, page.height.max(1.0) as u32, first..last, 0..W, page.bg);
        page.paint(&mut band, &fonts);
        let mut whole = Canvas::new(W, last - first);
        whole.put_rows(&band, first as i32, last as i32, 0);
        whole
    };
    let path = out.join("page.png");
    let file = std::fs::File::create(&path).with_context(|| format!("make {}", path.display()))?;
    canvas.write_png(BufWriter::new(file))?;
    println!("painted {first}..{last} in {:?} -> {}", started.elapsed(), path.display());

    // A text sketch of what was laid out, for what a picture cannot show.
    let mut text = String::new();
    for item in &page.items {
        match item {
            web::Item::Text { x, baseline, text: t, px, .. } => text.push_str(&format!("T {:7.1} {:7.1} {:5.1} {}\n", x, baseline, px, t)),
            web::Item::Image { x, y, w, h, pic } => text.push_str(&format!("I {:7.1} {:7.1} {:6.1}x{:.1} #{pic}\n", x, y, w, h)),
            web::Item::Rule { x0, y0, .. } => text.push_str(&format!("R {:7.1} {:7.1}\n", x0, y0)),
            _ => {}
        }
    }
    for link in &page.links {
        text.push_str(&format!("L {:7.1} {:7.1} {:6.1}x{:.1} {}\n", link.rect.x, link.rect.y, link.rect.w, link.rect.h, link.href));
    }
    std::fs::write(out.join("page.txt"), text)?;
    Ok(())
}

fn onyx() -> DeviceInfo {
    DeviceInfo {
        model: "Redmi Turbo 4 Pro".into(),
        codename: "onyx".into(),
        soc: None,
        cpu: Cpu { cores: 8, max_khz: Some(3_200_000) },
        ram_kib: 12 * 1024 * 1024,
        panel: Some((W, H)),
        screen: Some(6.83),
        os_version: Some("OS4.0.2.0.XOLCNXM".into()),
        android: Some("17".into()),
        locale: Some("zh-CN".into()),
        security_patch: None,
        kernel: "6.6.30-android15".into(),
        storage: Storage { total: 244_000_000_000, free: Some(30_400_000_000) },
        battery: Some(Battery {
            level: 51,
            charge: Charge::NotCharging,
            temp: Some(375),
            health: Some("Good".into()),
            cycles: Some(120),
            design: Some(6_000_000),
            full: Some(5_800_000),
            voltage: Some(4_300_000),
            quick: false,
            plugged: false,
        }),
        slot: Some(Slot::B),
        snapshot: SnapshotState::None,
        boot: Boot { unlocked: Some(true), verified: Some("orange".into()) },
    }
}
