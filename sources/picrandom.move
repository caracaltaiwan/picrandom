module picrandom::pic_display;

use iota::balance::{Self, Balance};
use iota::coin::{Self, Coin};
use iota::display;
use iota::object::{Self, UID};
use iota::package;
use iota::transfer;
use iota::tx_context::{Self, TxContext};
use picrandom::awesome::AWESOME;
use std::string::{Self, String};
use std::vector;

// 錯誤碼
const E_SOLD_OUT: u64 = 0;
const E_INSUFFICIENT_FUNDS: u64 = 1;

public struct PIC_DISPLAY has drop {}

/// 這就是我們的金庫 (Shared Object)
/// 存放了所有未使用的 ID 和 資金池
public struct Vault has key {
    id: UID,
    balance: Balance<AWESOME>, // 存放預先 Mint 好的代幣
    available_ids: vector<u64>, // 存放尚未被抽走的圖片 ID
}

public struct Awesome_NFT has key, store {
    id: UID,
    name: String,
    image_url: String,
    level: u8,
    balance: Balance<AWESOME>, // NFT 內部持有的代幣
}

fun init(otw: PIC_DISPLAY, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);

    // --- 1. 設定 Display (跟之前一樣) ---
    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"image_url"),
        string::utf8(b"description"),
        string::utf8(b"awesome_balance"),
    ];

    let values = vector[
        string::utf8(b"{name}"),
        string::utf8(b"{image_url}"),
        string::utf8(b"Limited Edition NFT with Vault Assets!"),
        string::utf8(b"{balance}"),
    ];

    let mut display = display::new_with_fields<Awesome_NFT>(
        &publisher,
        keys,
        values,
        ctx,
    );
    display::update_version(&mut display);

    transfer::public_transfer(publisher, iota::tx_context::sender(ctx));
    transfer::public_transfer(display, iota::tx_context::sender(ctx));

    // --- 2. 初始化 Vault ---

    // 建立一個包含 0 到 1084 的向量 (1085 張圖)
    let mut ids = vector::empty<u64>();
    let mut i: u64 = 0;
    while (i < 1085) {
        vector::push_back(&mut ids, i);
        i = i + 1;
    };

    // 建立 Vault 並共享 (Share) 出去
    let vault = Vault {
        id: object::new(ctx),
        balance: balance::zero(), // 一開始是空的，稍後由管理員存入
        available_ids: ids,
    };

    transfer::share_object(vault);
}

/// 管理員函數：將預先 Mint 好的代幣存入 Vault
public fun deposit_to_vault(vault: &mut Vault, payment: Coin<AWESOME>) {
    let bal = coin::into_balance(payment);
    balance::join(&mut vault.balance, bal);
}

/// 使用者函數：鑄造 NFT
/// 不需要傳入 Coin，因為錢是從 Vault 出
public fun mint(
    vault: &mut Vault, // 需要引用共享的 Vault
    name: String,
    ctx: &mut TxContext,
) {
    // 1. 檢查是否還有剩餘的圖片 ID
    let len = vector::length(&vault.available_ids);
    assert!(len > 0, E_SOLD_OUT);

    // 2. 檢查 Vault 是否有足夠的錢支付 50 AWESOME
    assert!(balance::value(&vault.balance) >= 50, E_INSUFFICIENT_FUNDS);

    // 3. 生成隨機索引 (0 ~ len-1)
    // 利用新的 UID hash 來做簡單的偽隨機
    let id = object::new(ctx);
    let id_bytes = object::uid_to_bytes(&id);
    // 取最後一個 byte 做運算 (為了更隨機，可以多取幾個 byte 組合，這裡簡化處理)
    let random_seed = *vector::borrow(&id_bytes, vector::length(&id_bytes) - 1);
    let index = (random_seed as u64) % len;

    // 4. [關鍵] 取出 ID 並從清單中移除 (Swap Remove 效率最高)
    // 這保證了這個 ID 永遠不會再被選到
    let selected_pic_id = vector::swap_remove(&mut vault.available_ids, index);

    // 5. 生成圖片 URL
    let mut url_bytes = b"https://picsum.photos/id/";
    vector::append(&mut url_bytes, u64_to_bytes(selected_pic_id));
    vector::append(&mut url_bytes, b"/200/300");
    let image_url = string::utf8(url_bytes);

    // 6. 從 Vault 切分 50 代幣
    let nft_balance = balance::split(&mut vault.balance, 50);

    // 7. 鑄造 NFT
    let nft = Awesome_NFT {
        id, // 使用剛才生成的那把 key
        name,
        image_url,
        level: 1,
        balance: nft_balance, // 放入 50 代幣
    };

    transfer::public_transfer(nft, iota::tx_context::sender(ctx));
}

// --- Burn 與 Helper 函數 (保持不變) ---
public fun burn(nft: Awesome_NFT, ctx: &mut TxContext) {
    let Awesome_NFT { id, balance, .. } = nft;
    object::delete(id);
    let coin_obj = coin::from_balance(balance, ctx);
    transfer::public_transfer(coin_obj, iota::tx_context::sender(ctx));
}

fun u64_to_bytes(mut num: u64): vector<u8> {
    if (num == 0) { return b"0" };
    let mut bytes = vector::empty<u8>();
    while (num > 0) {
        let remainder = num % 10;
        vector::push_back(&mut bytes, (remainder as u8) + 48);
        num = num / 10;
    };
    vector::reverse(&mut bytes);
    bytes
}

// --- 測試用輔助函數 ---
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(PIC_DISPLAY {}, ctx);
}

#[test_only]
public fun deposit_for_testing(vault: &mut Vault, coin: Coin<AWESOME>) {
    deposit_to_vault(vault, coin);
}

#[test_only]
public fun balance_value(nft: &Awesome_NFT): u64 {
    balance::value(&nft.balance)
}
