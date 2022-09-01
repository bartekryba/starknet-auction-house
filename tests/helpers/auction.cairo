%lang starknet

from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc20.IERC20 import IERC20

from src.main import (
    place_bid,
)

from tests.helpers.erc20 import erc20_helpers

namespace auction_helpers:
    # Tops up user account and places a bid, ensuring right balances at the end
    func topped_bid{
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr : HashBuiltin*
    }(
        auction_id: felt,
        user_address: felt,
        amount: felt
    ):
        alloc_locals
        let (auction_contract_address) = get_contract_address()

        erc20_helpers.top_up_address(user_address, amount)
        erc20_helpers.assert_address_balance(user_address, amount)
        erc20_helpers.approve_for_bid(user_address, amount)

        %{ end_prank = start_prank(ids.user_address) %}
        place_bid(auction_id, Uint256(amount, 0))
        %{ end_prank() %}

        erc20_helpers.assert_address_balance(auction_contract_address, amount)
        erc20_helpers.assert_address_balance(user_address, 0)

        return ()
    end
end