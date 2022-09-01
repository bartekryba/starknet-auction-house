%lang starknet
from starkware.cairo.common.math import assert_nn, assert_le, assert_lt
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

from src.data import (
    AuctionData,
    Bid,
    assert_bid_initialized,
    assert_auction_initialized,
    assert_last_block_initialized,
    is_bid_initialized,
)
from src.constants import AUCTION_PROLONGATION_ON_BID
from src.vault import vault

@storage_var
func auctions(auction_id : felt) -> (auction : AuctionData):
end

@storage_var
func finalized_auctions(auction_id : felt) -> (is_closed: felt):
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

    assert_auction_initialized(auction)

    return (auction)
end

@view
func get_auction_highest_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (highest_bid : Bid):
    alloc_locals
    let (highest_bid) = auction_highest_bid.read(auction_id)

    assert_bid_initialized(highest_bid)

    return (highest_bid)
end

@view
func get_auction_last_block{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (end_block : felt):
    let (end_block) = auction_last_block.read(auction_id)

    assert_last_block_initialized(end_block)

    return (end_block)
end

@view
func is_auction_active{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
) -> (active : felt):
    alloc_locals

    let (last_block) = auction_last_block.read(auction_id)
    assert_last_block_initialized(last_block)

    let (current_block) = get_block_number()

    let (active) = is_le(current_block, last_block)

    return (active)
end

func assert_active_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
):
    let (active) = is_auction_active(auction_id)

    with_attr error_message("Auction is not active"):
        assert active = 1
    end

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

    vault.deposit_asset(erc721_address, asset_id, seller)

    return (auction_id)
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

func prolong_auction_on_end{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(auction_id):
    alloc_locals

    let (current_block) = get_block_number()
    let (end_block) = get_auction_last_block(auction_id)

    let diff = end_block - current_block

    let (should_prolong) = is_le(diff, AUCTION_PROLONGATION_ON_BID)

    if should_prolong == 1:
        let new_last_block = end_block + AUCTION_PROLONGATION_ON_BID

        auction_last_block.write(auction_id, new_last_block)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return ()
end

@external
func place_bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt, amount : Uint256
):
    alloc_locals

    let (caller_address) = get_caller_address()
    let (old_bid) = auction_highest_bid.read(auction_id)

    let new_bid = Bid(amount=amount, address=caller_address)

    let (auction) = auctions.read(auction_id)
    verify_outbid(auction_id, old_bid, new_bid)

    auction_highest_bid.write(auction_id, new_bid)

    prolong_auction_on_end(auction_id)

    vault.deposit_bid(auction.erc20_address, new_bid)
    let (previous_bid_exists) = is_bid_initialized(old_bid)

    if previous_bid_exists == 1:
        vault.transfer_bid(auction.erc20_address, old_bid, old_bid.address)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return ()
end

@external
func finalize_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    auction_id : felt
):
    alloc_locals

    let (current_block) = get_block_number()
    let (end_block) = get_auction_last_block(auction_id)

    with_attr error_message("Auction is still active"):
        assert_lt(end_block, current_block)
    end

    let (is_finalized) = finalized_auctions.read(auction_id)
    with_attr error_message("Auction is already finalized"):
        assert is_finalized = 0
    end

    # It is important to do it BEFORE transferring assets, otherwise malicious ERC721 might
    # call finalize_auction multiple times during transfer.
    finalized_auctions.write(auction_id, 1)

    let (auction) = get_auction(auction_id)

    let (winning_bid) = auction_highest_bid.read(auction_id)

    let (has_bid) = is_bid_initialized(winning_bid)

    if has_bid == 1:
        # Seller gets the money
        vault.transfer_bid(auction.erc20_address, winning_bid, auction.seller)
        # Buyer gets the asset
        vault.transfer_asset(auction.erc721_address, auction.asset_id, winning_bid.address)
    else:
        # Seller gets the asset back
        vault.transfer_asset(auction.erc721_address, auction.asset_id, auction.seller)
    end

    return ()
end