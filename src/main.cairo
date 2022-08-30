%lang starknet
from starkware.cairo.common.math import assert_nn, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_number,
    get_contract_address,
)

from src.protocols.erc20 import IERC20
from src.token import get_erc20_address
from src.asset_vault.library import AssetVault

struct Bid:
    member amount : felt
    member address : felt
end

struct Auction:
    member id : felt
    member issuer : felt
    member asset : felt
    member min_bid_increment : felt
end

@storage_var
func auctions(auction_id : felt) -> (auction : Auction):
end

@storage_var
func auction_highest_bid(auction_id : felt) -> (highest_bid : Bid):
end

@storage_var
func auction_end_block(auction_id : felt) -> (end_block : felt):
end

@view
func get_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (auction : Auction):
    let (auction) = auctions.read(auction_id)

    return (auction)
end

@view
func get_auction_highest_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (highest_bid : Bid):
    let (highest_bid) = auction_highest_bid.read(auction_id)

    return (highest_bid)
end

@view
func get_auction_end_block{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (end_block : felt):
    let (end_block) = auction_end_block.read(auction_id)

    return (end_block)
end

@view
func is_active_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (active : felt):
    alloc_locals

    let (end_block) = auction_end_block.read(auction_id)
    let (current_block) = get_block_number()

    let (active) = is_le(current_block, end_block)

    return (active)
end

func assert_active_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
):
    let (active) = is_active_auction(auction_id)

    assert active = 1

    return ()
end

func assert_inactive_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
):
    let (active) = is_active_auction(auction_id)

    assert active = 0

    return ()
end

@external
func create_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset_id : felt, min_bid_increment : felt, lifetime : felt
) -> (auction_id : felt):
    alloc_locals

    let (caller_address) = get_caller_address()
    let (auction_id) = hash2{hash_ptr=pedersen_ptr}(x=caller_address, y=asset_id)

    assert_inactive_auction(auction_id)
    AssetVault.assert_has_available_asset(caller_address, asset_id)

    let auction = Auction(
        id=auction_id, issuer=caller_address, asset=asset_id, min_bid_increment=min_bid_increment
    )
    auctions.write(auction_id, auction)

    let (current_block) = get_block_number()
    let end_block = current_block + lifetime
    auction_end_block.write(auction_id, end_block)

    auction_highest_bid.write(auction_id, Bid(0, 0))

    AssetVault.lock_asset(caller_address, asset_id)

    return (auction_id)
end

func secure_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(bid : Bid):
    let (erc20_address) = get_erc20_address()
    let (current_address) = get_contract_address()

    let (result) = IERC20.transferFrom(
        contract_address=erc20_address,
        sender=bid.address,
        recipient=current_address,
        amount=bid.amount,
    )

    assert result = 1
    return ()
end

func return_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(bid : Bid):
    let (erc20_address) = get_erc20_address()

    let (result) = IERC20.transfer(
        contract_address=erc20_address, recipient=bid.address, amount=bid.amount
    )

    assert result = 1
    return ()
end

func verify_outbid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(auction_id : felt, old_bid: Bid, new_bid: Bid):
    let (auction) = get_auction(auction_id)
    let min_bid = old_bid.amount + auction.min_bid_increment

    assert_le(min_bid, new_bid.amount)

    return ()
end

func prolong_auction_if_needed{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(auction_id):
    alloc_locals

    let (current_block) = get_block_number()
    let (end_block) = get_auction_end_block(auction_id)

    let diff = end_block - current_block

    let (should_prolong) = is_le(diff, 10)

    if should_prolong == 1:
        let append = 10 - diff
        let new_end_block = end_block + append

        auction_end_block.write(auction_id, new_end_block)

        return ()
    end

    return ()
end

@external
func place_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt, price : felt
):
    alloc_locals

    let (caller_address) = get_caller_address()
    let (old_bid) = get_auction_highest_bid(auction_id)

    let new_bid = Bid(amount=price, address=caller_address)

    verify_outbid(auction_id, old_bid, new_bid)

    auction_highest_bid.write(auction_id, new_bid)

    secure_bid(new_bid)
    return_bid(old_bid)

    prolong_auction_if_needed(auction_id)

    return ()
end

@external
func close_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
):
    alloc_locals

    let (current_block) = get_block_number()
    let (end_block) = get_auction_end_block(auction_id)

    assert_le(end_block + 1, current_block)

    let (auction) = get_auction(auction_id)
    let (erc20_address) = get_erc20_address()

    let (winning_bid) = get_auction_highest_bid(auction_id)

    IERC20.transfer(
        contract_address=erc20_address, recipient=auction.issuer, amount=winning_bid.amount
    )

    AssetVault.change_owner(auction.issuer, winning_bid.address, auction.asset)

    return ()
end
