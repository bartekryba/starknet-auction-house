%lang starknet

from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc721.IERC721 import IERC721

@contract_interface
namespace Mintable:
    func mint(to: felt, tokenId: Uint256):
    end
end

const INITIAL_OWNER = 'initial_owner'

namespace erc721_helpers:

    func assert_has_token{syscall_ptr: felt*, range_check_ptr}(address: felt, token_id: Uint256):
        alloc_locals
        tempvar erc721_address
        %{ ids.erc721_address = context.erc721_address %}
        let (owner) = IERC721.ownerOf(
            contract_address=erc721_address,
            tokenId=token_id,
        )
        local id = token_id.low
        with_attr error_message("{address} doesn't own token {id}"):
            assert owner = address
        end
        return ()
    end

    func mint{syscall_ptr: felt*, range_check_ptr}(address: felt, token_id: Uint256):
        let (contract_address) = get_address()
        %{ stop_prank = start_prank(ids.INITIAL_OWNER, ids.contract_address) %}

        Mintable.mint(
            contract_address=contract_address,
            to=address,
            tokenId=token_id,
        )

        %{ stop_prank() %}
        return ()
    end

    # Deploys ERC721 contract using deploy_contract cheatcode.
    # This takes a lot of time and should be done just once in __setup__ hook.
    # Deployed contract's address is stored in context available through hints.
    func deploy_contract():
        %{
            context.erc721_address = deploy_contract(
                "./lib/cairo_contracts/src/openzeppelin/token/erc721/presets/ERC721MintableBurnable.cairo",
                [0, 0, ids.INITIAL_OWNER],
            ).contract_address
        %}
        return ()
    end

    # Returns address of contract deployed with deploy_contract
    func get_address() -> (address: felt):
        tempvar address
        %{ ids.address = context.erc721_address %}
        return (address)
    end
end