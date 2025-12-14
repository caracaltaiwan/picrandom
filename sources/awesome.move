module picrandom::awesome;

use iota::coin::{Self, TreasuryCap};
use iota::transfer;
use iota::tx_context::{Self, TxContext};

// 1. Struct 名稱必須是大寫的 AWESOME (與模組對應)
public struct AWESOME has drop {}

fun init(witness: AWESOME, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        9,
        b"AWE",
        b"Awesome Token",
        b"The currency of Awesome Ecosystem",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, iota::tx_context::sender(ctx));
}

public fun mint_for_testing(
    treasury: &mut TreasuryCap<AWESOME>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    coin::mint_and_transfer(treasury, amount, recipient, ctx);
}
