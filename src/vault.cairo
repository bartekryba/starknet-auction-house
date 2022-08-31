%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address
from openzeppelin.token.erc721.IERC721 import IERC721

namespace Vault:
    func deposit_asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        erc721_address: felt, asset_id : Uint256, source: felt,
    ):
        let (current_address) = get_contract_address()

        IERC721.transferFrom(
            contract_address=erc721_address,
            from_=source,
            to=current_address,
            tokenId=asset_id,
        )

        return ()
    end

    # todo
    #funcc withdraw_asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    #    erc721_address: felt, asset_id : felt, target: felt
    #):
    #    let (current_address) = get_contract_address()
    #    let (caller_address) = get_caller_address()
    #    let (erc721_address) = get_erc721_address()
    #
    #    return ()
    #end
end
