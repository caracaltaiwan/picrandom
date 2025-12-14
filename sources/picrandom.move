module picrandom::pic_display;

use iota::display;
use iota::object::{Self, UID};
use iota::package;
use iota::transfer;
use iota::tx_context::{Self, TxContext};
use std::string::{Self, String};
use std::vector;

public struct PIC_DISPLAY has drop {}

public struct Hero has key, store {
    id: UID,
    name: String,
    image_url: String,
    level: u8,
}

fun init(otw: PIC_DISPLAY, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"image_url"),
        string::utf8(b"description"),
    ];

    let values = vector[
        string::utf8(b"{name}"),
        string::utf8(b"{image_url}"),
        string::utf8(b"A Hero with random appearance!"),
    ];

    let mut display = display::new_with_fields<Hero>(
        &publisher,
        keys,
        values,
        ctx,
    );

    display::update_version(&mut display);
    transfer::public_transfer(publisher, iota::tx_context::sender(ctx));
    transfer::public_transfer(display, iota::tx_context::sender(ctx));
}

// ========================================================
// 修改後的 Mint 函數：自動生成隨機圖片
// ========================================================
public fun mint(name: String, ctx: &mut TxContext) {
    // 1. 創建新的 UID
    let id = object::new(ctx);

    // 2. 利用 UID 產生偽隨機數
    // 將 UID 轉換為 bytes，取最後一個 byte 作為隨機源
    let id_bytes = object::uid_to_bytes(&id);
    let len = vector::length(&id_bytes);
    // 取最後一個字節 (0-255)
    let random_byte = *vector::borrow(&id_bytes, len - 1);

    // 將範圍擴大一點，例如乘以 4 (0-1020)，大致符合 Picsum ID 範圍
    let random_pic_id = (random_byte as u64) * 4;

    // 3. 組合 URL: "https://picsum.photos/id/" + random_pic_id + "/200/300"
    let mut url_bytes = b"https://picsum.photos/id/";

    // 將數字轉為 bytes 並接在後面
    vector::append(&mut url_bytes, u64_to_bytes(random_pic_id));

    // 接上結尾
    vector::append(&mut url_bytes, b"/200/300");

    let image_url = string::utf8(url_bytes);

    let hero = Hero {
        id,
        name,
        image_url, // 使用自動生成的 URL
        level: 1,
    };

    transfer::public_transfer(hero, iota::tx_context::sender(ctx));
}

// ========================================================
// 輔助函數：將 u64 數字轉換為 vector<u8> (ASCII Bytes)
// ========================================================
fun u64_to_bytes(mut num: u64): vector<u8> {
    if (num == 0) {
        return b"0"
    };

    let mut bytes = vector::empty<u8>();
    while (num > 0) {
        let remainder = num % 10;
        // ASCII '0' is 48. So 0->48, 1->49...
        vector::push_back(&mut bytes, (remainder as u8) + 48);
        num = num / 10;
    };

    vector::reverse(&mut bytes);
    bytes
}

// --- 測試用輔助函數 (保留以便測試) ---

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(PIC_DISPLAY {}, ctx);
}

#[test_only]
public fun image_url(hero: &Hero): String {
    hero.image_url
}
