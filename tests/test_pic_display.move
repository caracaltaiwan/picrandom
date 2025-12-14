#[test_only]
module picrandom::test_pic_display;

use iota::display;
use iota::package;
use iota::test_scenario as ts;
use picrandom::pic_display::{Self, Hero};
use std::string;

const ADMIN: address = @0xAD;

#[test]
fun test_mint_and_display() {
    let mut scenario = ts::begin(ADMIN);

    // --- 1. 初始化 ---
    {
        let ctx = ts::ctx(&mut scenario);
        pic_display::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, ADMIN);

    // --- 2. 驗證 Display 設定 (修正這裡) ---
    {
        // 修正錯誤：將 has_taken_from_sender 改為 has_most_recent_for_sender

        // 檢查 ADMIN 是否收到了 Publisher
        assert!(ts::has_most_recent_for_sender<package::Publisher>(&scenario), 0);

        // 檢查 ADMIN 是否收到了 Display<Hero>
        assert!(ts::has_most_recent_for_sender<display::Display<Hero>>(&scenario), 1);
    };

    // --- 3. 測試 Mint ---
    {
        let ctx = ts::ctx(&mut scenario);
        let name = string::utf8(b"Random Hero");

        pic_display::mint(name, ctx);
    };

    ts::next_tx(&mut scenario, ADMIN);

    // --- 4. 驗證 Hero NFT 數據 ---
    {
        let hero = ts::take_from_sender<Hero>(&scenario);
        let url = pic_display::image_url(&hero);

        // 使用 debug print 印出生成的 URL 看看 (執行測試時加上 --nocapture 參數)
        std::debug::print(&url);

        ts::return_to_sender(&scenario, hero);
    };

    ts::end(scenario);
}
