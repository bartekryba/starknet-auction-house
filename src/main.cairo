%lang starknet
from starkware.cairo.common.math import assert_nn, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_add
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_number,
    get_contract_address,
)

from openzeppelin.token.erc20.IERC20 import IERC20

from src.vault import Vault

struct Bid:
    member amount : Uint256
    member address : felt
end

struct AuctionData:
    member seller : felt
    member asset_id : Uint256
    member min_bid_increment : Uint256
    member erc20_address : felt
    member erc721_address : felt
end

@storage_var
func auctions(auction_id : felt) -> (auction : AuctionData):
end

@storage_var
func auction_highest_bid(auction_id : felt) -> (highest_bid : Bid):
end

# Last block when sale is active
@storage_var
func auction_last_block(auction_id : felt) -> (end_block : felt):
end

@view
func get_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (auction : AuctionData):
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
func get_auction_last_block{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (end_block : felt):
    let (end_block) = auction_last_block.read(auction_id)

    return (end_block)
end

@view
func is_active_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (active : felt):
    alloc_locals

    let (end_block) = auction_last_block.read(auction_id)
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
    auction_id: felt,
    asset_id : Uint256,
    min_bid_increment : Uint256,
    erc20_address : felt,
    erc721_address : felt,
    lifetime : felt,
) -> (auction_id : felt):
    alloc_locals

    let (seller) = get_caller_address()

    # TODO: Make sure auction doesn't exist yet

    let auction = AuctionData(
        seller=seller,
        asset_id=asset_id,
        min_bid_increment=min_bid_increment,
        erc20_address=erc20_address,
        erc721_address=erc721_address,
    )
    auctions.write(auction_id, auction)

    let (current_block) = get_block_number()
    let end_block = current_block + lifetime
    auction_last_block.write(auction_id, end_block)

    Vault.deposit_asset(erc721_address, asset_id, seller)

    return (auction_id)
end

func secure_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(bid : Bid, erc20_address):
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

func return_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(bid : Bid, erc20_address):
    let (result) = IERC20.transfer(
        contract_address=erc20_address, recipient=bid.address, amount=bid.amount
    )

    assert result = 1
    return ()
end

func verify_outbid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(auction_id : felt, old_bid: Bid, new_bid: Bid):
    alloc_locals # explain why it is needed
    let (auction) = get_auction(auction_id)
    let (min_bid, carry) = uint256_add(old_bid.amount, auction.min_bid_increment)

    # Should never happen in normal case
    with_attr error_message("Overflow in min_bid"):
        assert carry = 0
    end

    let (higher_than_minimum) = uint256_le(min_bid, new_bid.amount)

    with_attr error_message("New bid too low"):
        assert higher_than_minimum = 1
    end

    return ()
end

func prolong_auction_if_needed{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(auction_id):
    alloc_locals

    let (current_block) = get_block_number()
    let (end_block) = get_auction_last_block(auction_id)

    let diff = end_block - current_block

    let (should_prolong) = is_le(diff, 10)

    if should_prolong == 1:
        let append = 10 - diff
        let new_end_block = end_block + append

        auction_last_block.write(auction_id, new_end_block)

        return ()
    end

    return ()
end

@external
func place_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt, amount : Uint256
):
    alloc_locals

    let (caller_address) = get_caller_address()
    let (old_bid) = get_auction_highest_bid(auction_id)

    let new_bid = Bid(amount=amount, address=caller_address)

    let (auction) = auctions.read(auction_id)
    verify_outbid(auction_id, old_bid, new_bid)

    auction_highest_bid.write(auction_id, new_bid)

    secure_bid(new_bid, auction.erc20_address)
    return_bid(old_bid, auction.erc20_address)

    prolong_auction_if_needed(auction_id)

    return ()
end

@external
func close_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
):
    alloc_locals

    let (current_block) = get_block_number()
    let (end_block) = get_auction_last_block(auction_id)

    assert_le(end_block + 1, current_block)

    let (auction) = get_auction(auction_id)

    let (winning_bid) = get_auction_highest_bid(auction_id)

    IERC20.transfer(
        contract_address=auction.erc20_address, recipient=auction.seller, amount=winning_bid.amount
    )

    #AssetVault.change_owner(auction.seller, winning_bid.address, auction.asset_id)

    return ()
end
