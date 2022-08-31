%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_number,
    get_contract_address,
)
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc721.IERC721 import IERC721

from src.main import create_auction, AuctionData, auctions, auction_last_block

from tests.helpers.erc721 import erc721_helpers
from tests.helpers.data import data_helpers
from tests.helpers.erc20 import erc20_helpers
from tests.helpers.constants import SELLER, AUCTION_ID

@external
func test_auction_created{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> ():
    alloc_locals
    let (auction_contract_address) = get_contract_address()
    let (current_block_number) = get_block_number()
    let auction_lifetime = 100 # in blocks
    let token_id = Uint256(0,1)
    let (erc20_address) = erc20_helpers.get_address()
    let (erc721_address) = erc721_helpers.get_address()
    let expected_auction = AuctionData(
        seller=SELLER,
        asset_id=token_id,
        min_bid_increment=Uint256(100, 0),
        erc20_address=erc20_address,
        erc721_address=erc721_address,
    )
    erc721_helpers.mint(SELLER, token_id)

    %{ start_prank(ids.SELLER, ids.erc721_address) %}
    IERC721.approve(
        contract_address=erc721_address,
        approved=auction_contract_address,
        tokenId=token_id,
    )
    %{ start_prank(ids.SELLER) %}
    create_auction(
        auction_id=AUCTION_ID,
        asset_id = expected_auction.asset_id,
        min_bid_increment = expected_auction.min_bid_increment,
        erc20_address = expected_auction.erc20_address,
        erc721_address = expected_auction.erc721_address,
        lifetime = auction_lifetime,
    )

    let (saved_auction) = auctions.read(AUCTION_ID)
    data_helpers.assert_auctions_equal(expected_auction, saved_auction)

    erc721_helpers.assert_has_token(auction_contract_address, token_id)

    let (end_block) = auction_last_block.read(AUCTION_ID)
    assert auction_lifetime + current_block_number = end_block

    return ()
end

@external
func __setup__():
    erc20_helpers.deploy_contract()
    erc721_helpers.deploy_contract()
    return ()
end
