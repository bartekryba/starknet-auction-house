%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import assert_not_zero

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

func assert_auction_initialized(auction: AuctionData):
    with_attr error_message("Auction was not initalized"):
        assert_not_zero(auction.seller)
    end
    return ()
end

func assert_bid_initialized(bid: Bid):
    let (initialized) = is_bid_initialized(bid)
    with_attr error_message("Bid was not initialized"):
        assert initialized = 0
    end
    return ()
end

func is_bid_initialized(bid: Bid) -> (result: felt):
    # Initialized bid can't have address == 0
    if bid.address == 0:
        return (0)
    else:
        return (1)
    end
end

func assert_last_block_initialized(end_block: felt):
    with_attr error_message("Last block was not initialized"):
        assert_not_zero(end_block)
    end
    return ()
end