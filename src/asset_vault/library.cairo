%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address
from src.protocols.erc721 import IERC721

@storage_var
func erc721_address() -> (address : felt):
end

@storage_var
func asset_vault(address : felt, asset_id : felt) -> (status : felt):
end

namespace AssetVault:
    const NO_ASSET = 0
    const AVAILABLE_ASSET = 1
    const LOCKED_ASSET = 2

    func get_erc721_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (address : felt):
        let (address) = erc721_address.read()

        return (address)
    end

    func get_asset_status{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        asset_id : felt
    ) -> (asset_status : felt):
        let (caller_address) = get_caller_address()
        let (status) = asset_vault.read(caller_address, asset_id)

        return (status)
    end

    func deposit_asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        asset_id : felt
    ):
        let (current_address) = get_contract_address()
        let (caller_address) = get_caller_address()
        let (erc721_address) = get_erc721_address()

        IERC721.transferFrom(
            contract_address=erc721_address,
            from_=caller_address,
            to=current_address,
            tokenId=asset_id,
        )

        asset_vault.write(caller_address, asset_id, AVAILABLE_ASSET)

        return ()
    end

    func withdraw_asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        asset_id : felt
    ):
        let (current_address) = get_contract_address()
        let (caller_address) = get_caller_address()
        let (erc721_address) = get_erc721_address()

        assert_has_available_asset(caller_address, asset_id)

        return ()
    end

    func change_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        old_owner : felt, new_owner : felt, asset_id : felt
    ):
        asset_vault.write(old_owner, asset_id, NO_ASSET)
        asset_vault.write(new_owner, asset_id, AVAILABLE_ASSET)

        return ()
    end

    func assert_has_available_asset{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(address : felt, asset_id : felt):
        let (asset_status) = asset_vault.read(address, asset_id)
        assert asset_status = AVAILABLE_ASSET

        return ()
    end

    func lock_asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt, asset_id : felt
    ):
        assert_has_available_asset(address, asset_id)

        asset_vault.write(address, asset_id, LOCKED_ASSET)

        return ()
    end
end
