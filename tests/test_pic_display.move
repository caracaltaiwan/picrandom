#[test_only]
module picrandom::test_pic_display;

use iota::coin;
use iota::test_scenario as ts;
use picrandom::awesome::{Self, AWESOME};
use picrandom::pic_display::{Self, Awesome_NFT, Vault};
use std::string;

const ADMIN: address = @0xAD;
const USER: address = @0xB0B;

#[test]
fun test_vault_mint_flow() {
    // 1. 初始化環境
    let mut scenario = ts::begin(ADMIN);

    // --- Step 1: 初始化合約 (建立 Vault) ---
    {
        let ctx = ts::ctx(&mut scenario);
        pic_display::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, ADMIN);

    // --- Step 2: 管理員存錢進 Vault ---
    {
        // [關鍵修正]：因為 mint_for_testing 需要 ctx，但 take_shared 不能在 ctx 活著時用
        // 所以我們用一個小區塊 {} 把 ctx 的生命週期限制在裡面，印完錢就釋放 ctx
        let funds = {
            let ctx = ts::ctx(&mut scenario);
            coin::mint_for_testing<AWESOME>(1000, ctx)
        };
        // 出了上面的大括號，ctx 就消失了，scenario 自由了

        // 2.2 現在可以安全地取出 Vault
        let mut vault = ts::take_shared<Vault>(&scenario);

        // 2.3 存錢 (deposit 不需要 ctx)
        pic_display::deposit_to_vault(&mut vault, funds);

        // 2.4 歸還 Vault
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER); // 切換到使用者 USER

    // --- Step 3: 使用者從 Vault 鑄造 NFT ---
    {
        let name = string::utf8(b"Lucky User NFT");

        // [關鍵修正]：順序很重要！
        // 3.1 先取出 Vault (這時候還沒借用 ctx)
        let mut vault = ts::take_shared<Vault>(&scenario);

        // 3.2 再取得 ctx (現在 scenario 是自由的，可以被借用)
        let ctx = ts::ctx(&mut scenario);

        // 3.3 呼叫 Mint
        pic_display::mint(&mut vault, name, ctx);

        // 3.4 歸還 Vault
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER);

    // --- Step 4: 驗證結果 ---
    {
        // 4.1 檢查用戶是否收到 NFT
        let nft = ts::take_from_sender<Awesome_NFT>(&scenario);

        // 4.2 檢查 NFT 裡面是否有 50 AWESOME
        let val = pic_display::balance_value(&nft);

        // 印出來確認
        std::debug::print(&std::string::utf8(b"NFT Balance:"));
        std::debug::print(&val);

        assert!(val == 50, 0);

        // 歸還物件
        ts::return_to_sender(&scenario, nft);
    };

    ts::end(scenario);
}
